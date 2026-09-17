# Two units, side by side

Everything in this skill was measured on real hardware. So was everything here.
Where the two disagree, both readings stood up on their own board, so the
difference is in the boards or their toolchains, not in the care taken.

Use `identify.md` to work out which one you are holding before applying either.

## What each unit was

| | Unit A | Unit B |
|---|---|---|
| Listing name | `ESP32-S3-ePaper-1.54` | `ESP32-S3-Touch-ePaper-1.54` |
| Waveshare SKU | 32298 | 34211 |
| Touch controller | not documented | FT6336 at `0x38` |
| Source | the rest of this skill | this file, `touch.md` |

Waveshare's own repository, `waveshareteam/ESP32-S3-ePaper-1.54`, covers both:
it ships an `11_RTC_Sleep_Test` and a `12_FT6336_Test`, and separate `V1` and
`V2` trees under `02_Example/ESP-IDF/`. Its pin definitions agree with
`pinout.md` on every signal both units share.

## Silicon: identical, including the eFuses

Unit B reports exactly what this skill records for Unit A:

```
Chip type:    ESP32-S3-PICO-1 (LGA56) (revision v0.2)
Features:     WiFi, BT 5 (LE), Dual Core + LP Core, 240MHz,
              Embedded Flash 8MB (GD), Embedded PSRAM 8MB (AP_3v3)
Crystal:      40MHz

PSRAM_CAP    = 8M
PSRAM_VENDOR = AP_3v3
FLASH_CAP    = 8M
FLASH_VENDOR = GD
FLASH_TYPE   = 4 data lines
```

**So the fingerprint that `esptool` and `espefuse` give you cannot separate these
two boards.** That is the single most useful thing on this page: reach for the
I2C scan instead.

## PSRAM: octal works on Unit B

`peripherals.md` records PSRAM as unresolved on Unit A, having ruled out six
hypotheses, and reasons from `PSRAM_VENDOR = AP_3v3` that the part must be quad
because the S3's octal parts run at 1.8 V.

On Unit B, octal mode works:

```ini
board_build.arduino.memory_type = qio_opi
```

```
flash=8192KB heap=362KB psram=8192KB (found=1)
clip buffer 250 KB in PSRAM -> ok
```

Two observations that may help on Unit A as well, offered as leads rather than
conclusions:

**`FLASH_TYPE` is about the flash.** `4 data lines` describes the flash
interface, which is quad on both units. `qio_opi` means exactly that: quad
flash, octal PSRAM. The two settings are independent, so a quad `FLASH_TYPE`
does not argue against octal PSRAM.

**`board_build.psram_type` is not a PlatformIO key for Arduino builds.** It is
silently ignored, so `psram_type = opi` produces an identical binary to no
setting at all. That matches the "no effect" recorded for that experiment and
means octal mode was never actually exercised by it. The key that does take
effect is `board_build.arduino.memory_type`.

**The vendor agrees for V2.** `02_Example/ESP-IDF/V2/08_Audio_Test/sdkconfig`
sets `CONFIG_SPIRAM_MODE_OCT=y`, while the V1 tree sets
`CONFIG_SPIRAM_MODE_QUAD=y`. Both set `CONFIG_SPIRAM_TYPE_AUTO=y` and
`CONFIG_SPIRAM_SPEED_80M=y`. The `R8` in `ESP32-S3-PICO-1-N8R8` is 8 MB of
octal PSRAM; `R2`, the V1 part, is 2 MB of quad.

None of this proves Unit A is octal. It does mean the experiment is worth one
more flash, and `identify.md` section 3 has the procedure. If it boot-loops
through `psramInit`, the mode is wrong and nothing is harmed.

## Toolchain used for Unit B

Arduino core 2.x is not the only option, and the newer core changes what is
available. Unit B was brought up on:

```ini
platform = https://github.com/pioarduino/platform-espressif32/releases/download/55.03.311/platform-espressif32.zip
board = esp32-s3-devkitc-1
framework = arduino
board_upload.flash_size = 8MB
board_build.partitions = default_8MB.csv
board_build.flash_mode = qio
board_build.arduino.memory_type = qio_opi
build_flags =
    -DARDUINO_USB_MODE=1
    -DARDUINO_USB_CDC_ON_BOOT=1
    -DBOARD_HAS_PSRAM
```

That resolves to Arduino core 3.3.11 on ESP-IDF 5.5.5. Two consequences worth
knowing:

**`driver/i2s_std.h` is available**, so the constraint in `audio.md` about being
limited to the legacy `driver/i2s.h` applies to Arduino 2.x, not to this
platform. Check which core you are on before writing against either API.

**`esp_codec_dev` compiles as-is.** Copying `02_Example/Arduino/08_Audio_Test/src/`
`esp_codec_dev/` and `codec_board/` into a PlatformIO `lib/` directory builds
without modification, which removes the need to port the ES8311 register
sequence by hand. `audio.md` is right that writing that sequence from memory is
a bad idea; on this core you do not have to.

## Audio findings from Unit B

These are additions to `audio.md` rather than corrections to it.

**The codec insists on owning I2C.** `codec_board`'s `check_i2c_inited()` calls
`i2c_new_master_bus()` unconditionally and has no path that adopts an existing
bus. Arduino's `Wire.begin()` on core 3.x creates that bus first, so a firmware
that calls `Wire.begin()` before `init_codec()` fails codec init. Keep the audio
path free of `Wire`, or bring the codec up first.

An `E (3217) i2c.master: this port has not been initialized` line during codec
init is harmless. It comes from `get_i2c_bus_handle()` probing before the bus
exists, and `init_codec()` still returns 0.

**The ES8311 is mono and the audio is on channel 0.** Reading 16-bit stereo
frames gives a live left channel and a right channel that is always exactly
zero. Averaging both halves your measured level and makes a working microphone
look broken.

**`esp_codec_dev_set_in_gain` does reach the PGA.** Measured RMS of the same
ambient noise, sweeping gain on one flash:

| `in_gain` | ch0 RMS | ch1 RMS | peak |
|---|---|---|---|
| 0 | 1 | 0 | 7 |
| 15 | 3 | 0 | 19 |
| 30 | 38 | 0 | 198 |
| 45 | 161 | 0 | 1229 |
| 60 | 175 | 0 | 869 |

45 is a reasonable default. The sweep-on-one-flash approach is the one
`audio.md` recommends for debugging silence, and it works just as well for
calibration.

**Measure the noise floor only after flushing the capture ring.** A level taken
straight after playback reads the tail of the playback, not the room. Discarding
roughly 300 ms of captured frames first turned a misleading ambient RMS of 383
into a correct 28.
