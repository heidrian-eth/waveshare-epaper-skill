# Streaming audio both ways

`audio.md` covers getting the ES8311 to make a sound at all. This covers
capturing and playing continuously at the same time, which is a different
problem: everything here is about keeping two real-time streams fed from a
board that also has to do other work.

## Give capture and playback their own tasks

The single most valuable change. Doing both from `loop()` fails in two ways at
once, and both sound like a bad connection rather than a bug:

- **Reading the codec late corrupts what you captured.** `esp_codec_dev_read`
  drains a DMA ring that keeps filling. If the loop is off doing something else
  when the ring wraps, those samples are gone and speech arrives with holes
  punched in it.
- **Feeding the codec from the same loop underruns it.** Playback drains at a
  fixed rate. Any pause — including the 20 ms the loop spends blocked in the
  capture read — is a pause the speaker cannot cover.

Two tasks pinned to core 1 at a priority above the Arduino loop, each with a
`StreamBuffer` between it and the rest of the firmware, removes both. Set the
buffer's trigger level to one full chunk so a read returns whole frames rather
than dribbling out a few bytes at a time.

## Keep the priming decision sticky

A playback task normally waits for a small buffer to build before it starts.
Re-deciding that on every pass is a trap:

```cpp
// Wrong: dips to empty constantly, and each dip stalls for the whole
// priming buffer before audio resumes.
primed = xStreamBufferBytesAvailable(q) > 0;

// Right: start once, and give up only when the stream has really stopped.
if (!primed) {
  if (xStreamBufferBytesAvailable(q) < PREBUF) { vTaskDelay(1); continue; }
  primed = true;
}
```

A stream arriving at exactly the rate it is consumed sits near empty by design,
so the wrong version stalls continuously. It is also invisible to an underrun
counter placed after the read, because the stall happens before it.

Similarly, one late read should cost one chunk of silence, not a full re-prime.
Tolerate two or three consecutive dry reads before dropping back to priming.

## Rates and channels

24 kHz works, and so does 16 kHz; the vendor `esp_codec_dev` component handles
both without touching the register table by hand.

The codec is stereo-framed but mono, with audio on channel 0 only. Reduce to
mono on the board before sending anything anywhere: channel 1 is always exactly
zero, so carrying it doubles the data for nothing. Expand back to interleaved
stereo when writing to the codec.

Useful sanity figures at 24 kHz, 16-bit: mono is 48000 B/s, stereo 96000 B/s.
Logging bytes per second at each end catches a surprising number of faults,
because anything other than real time means something is buffering, dropping or
running free.

## `esp_codec_dev_write` returns on enqueue

The same trap as `i2s_write()` in `traps.md`, and it applies to the newer API
too. A short sound written and immediately followed by a state change is cut
off. Push silence behind a tone before changing anything.

## Gain: use the analog stage, not a digital multiply

`esp_codec_dev_set_in_gain` reaches the PGA, and for **speech** the difference
between adequate and unusable is larger than the ambient-noise table in
`variants.md` suggests. Measured with a person talking at normal volume near
the board:

| `in_gain` | speech RMS |
|---|---|
| 45 | around 900 |
| 60 | several thousand |

At the lower setting speech is quiet enough that recognition degrades badly.
Raising the analog gain lifts the voice; multiplying the samples afterwards
lifts the noise with it, so prefer the PGA.

## The speaker distorts near full volume, and that has consequences

`esp_codec_dev_set_out_vol(100)` is loud, and on a speaker this size it also
clips. That matters beyond how it sounds, because anything that needs the
played signal to be a faithful copy of what you sent stops working.

Measured on this board with an acoustic echo canceller (speex) fed the exact
audio that was sent to the speaker:

| Signal | Echo removed |
|---|---|
| Synthetic echo, 200 ms delay, linear | 96% |
| Real board, speaker at volume 100 | 2% |

The failure was not alignment: cross-correlating the played signal against the
microphone put the echo **30 ms** behind the reference, well inside the
filter's reach, yet correlation was only 0.42. A linear filter can subtract a
delayed, scaled copy of a signal; it cannot subtract a distortion.

So on this board, at usable volume, server-side echo cancellation is not
available. The options are to lower the volume until the speaker stays linear,
to cancel on the board itself where the signal is seen before the speaker, or
to avoid the overlap entirely.

## The microphone and speaker are centimetres apart

With no cancellation the microphone hears the speaker clearly enough that voice
activity detection treats it as speech. The practical fix, if full duplex is
not required, is to stop sending captured audio while the speaker is active and
for a short tail afterwards — a few hundred milliseconds covers the last of the
sound leaving the DMA ring.

Deciding "is it playing?" from whether audio data is *arriving* is wrong if the
source sends continuously, silence included: that reads as permanently playing
and the microphone never reopens. Decide from the level of the audio, or from
whether anything is queued to play.

## Sending audio off the board over WebSocket

Two properties of the Arduino WebSocket client bite immediately:

- **`loop()` handles at most one frame per call.** One call per audio tick caps
  throughput below what continuous audio needs. Drain several per pass.
- **While disconnected, that same call blocks attempting to connect.** Draining
  eight of them unconditionally turns one connection attempt into eight and the
  handshake never completes. Drain only once connected.

The client also has a fixed receive buffer and answers anything larger with a
1009 close rather than reassembling it, so whatever feeds the board has to send
audio in small frames. Twenty milliseconds per frame works comfortably.
