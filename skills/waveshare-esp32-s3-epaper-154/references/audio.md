# Audio: ES8311 bring-up

The board has an ES8311 mono codec driving an onboard speaker, plus a
microphone. Getting sound out needs three things right: the power rails, the
codec register sequence, and the amplifier timing.

## Power rails

Two separate pins, and they have opposite polarities:

```cpp
pinMode(AUDIO_PWR, OUTPUT);      // GPIO42
digitalWrite(AUDIO_PWR, LOW);    // active LOW — powers the audio section

pinMode(AUDIO_PA, OUTPUT);       // GPIO46
digitalWrite(AUDIO_PA, LOW);     // active HIGH — amplifier starts off
```

Leave the amplifier off when idle; a permanently enabled amplifier hisses.

## Do not write the register sequence from memory

The ES8311 has a clock coefficient table: roughly twenty interdependent
registers derived from the MCLK-to-sample-rate ratio. Getting one wrong leaves
the codec **silent with no error** — every I²C write still succeeds.

Port the sequence from the vendor driver instead:
`esp_codec_dev/device/es8311/es8311.c` in the Espressif codec component
(vendored in the board's own repository under
`02_Example/Arduino/08_Audio_Test/src/esp_codec_dev/`).

For 16 kHz with MCLK = 256 × fs = 4.096 MHz, the table row is:

```
pre_div 0x01, pre_multi 0x01, adc_div 0x01, dac_div 0x01,
fs_mode 0x00, lrck_h 0x00, lrck_l 0xff, bclk_div 0x04,
adc_osr 0x10, dac_osr 0x20
```

## MCLK is mandatory

`use_mclk: 1` in the board config. The codec does not synthesise its own clock
here, so the ESP32 must drive MCLK on GPIO14. In the legacy I²S driver:

```cpp
cfg.fixed_mclk    = 16000 * 256;
cfg.mclk_multiple = I2S_MCLK_MULTIPLE_256;
```

Bring MCLK up **before** configuring the codec over I²C.

## Which I²S API

PlatformIO's `espressif32` platform ships Arduino-ESP32 2.x, which has only the
legacy `driver/i2s.h`. The newer `driver/i2s_std.h` belongs to ESP-IDF 5 and
will fail to compile. Check before writing against either API.

On the pioarduino platform, which ships Arduino core 3.x on ESP-IDF 5.5,
`driver/i2s_std.h` is available and the vendor's `esp_codec_dev` component
compiles unmodified — so the register sequence below need not be ported by hand.
See `variants.md` for the exact platform string.

## Verify the codec before blaming the I²S

Read the registers back. If reads return sensible values matching what you
wrote, the codec is configured correctly and the problem is elsewhere:

```
regs: 00=80 01=3F 02=00 03=10 04=20 05=00 06=03 07=00 08=FF
      09=0C 0A=4C 0D=01 0E=02 12=00 13=10 14=1A 17=BF 32=BF
```

Key values: `12=00` DAC powered, `09=0C` I²S 16-bit with DAC enabled,
`32=BF` volume near 0 dB. If all reads come back `00` or `FF`, I²C reads are
failing and any read-modify-write in your init corrupted the configuration.

## The amplifier timing trap

See trap 4 in `traps.md`. In short: `i2s_write()` returns on enqueue, so short
sounds are cut off entirely if you drop the amplifier right after writing.
Drain the DMA ring with silence before switching off, and wrap the amplifier
around a whole sequence rather than each note.

## Tone quality

Apply a short attack and release envelope — around 5 ms each — to every tone.
Without it, the abrupt edge produces an audible pop through the speaker.

## Debugging silence efficiently

If nothing plays, do not change one variable at a time across many flashes.
Flash once with a sweep that tries each candidate configuration in turn and
plays *n* beeps for candidate *n*, so counting the beeps identifies which
configurations work. Keep the amplifier on for the whole sweep to remove it as
a variable.
