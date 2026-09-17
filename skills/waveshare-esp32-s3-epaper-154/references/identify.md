# Identify the unit before you configure it

Waveshare sells more than one 1.54" ePaper board under closely related names,
and at least two of them carry the same ESP32-S3-PICO-1 silicon with the same
eFuse values. **Two units that report identically over `esptool` can still need
different build settings.** Read the board, not the listing, and not this file's
assumptions.

Run the checks below before choosing a PlatformIO configuration. They take a
couple of minutes and they are the difference between a board that boots and one
that loops.

## 1. Host-side fingerprint

```bash
./scripts/identify.sh /dev/ttyACM0
```

That prints the chip type, flash and PSRAM capacity, and the PSRAM eFuses. Keep
the output: it is the first half of the fingerprint.

**What it cannot tell you.** `PSRAM_VENDOR` and `FLASH_TYPE` do not determine
whether PSRAM runs in quad or octal mode. `FLASH_TYPE = 4 data lines` describes
the *flash*, not the PSRAM, and both modes have been observed on units reading
`PSRAM_VENDOR = AP_3v3`. Treat these fuses as capacity and vendor information
only. See `variants.md` for the measurements behind that.

## 2. On-device I2C scan

This is the check that actually separates the variants, and it needs firmware.
Scan the shared bus on GPIO47/48:

```cpp
Wire.begin(47, 48, 100000);
for (uint8_t a = 1; a < 127; a++) {
  Wire.beginTransmission(a);
  if (Wire.endTransmission() == 0) Serial.printf(" 0x%02X", a);
}
```

| Address | Device | Meaning |
|---|---|---|
| `0x18` | ES8311 codec | Audio present |
| `0x38` | FT6336 touch controller | **Touch variant** — see `touch.md` |
| `0x51` | PCF85063 RTC | Clock present |
| `0x70` | SHTC3 | Temperature and humidity present |

A touch controller answering at `0x38` needs a reset pulse on GPIO7 first, so
drive that pin low for 20 ms and high for 150 ms before scanning, or it may stay
silent on a board that does have it.

## 3. Resolve PSRAM empirically

PSRAM mode is cheap to determine by experiment and expensive to reason about.
Build once each way and let the board answer:

```ini
board_build.arduino.memory_type = qio_opi    ; octal PSRAM
board_build.arduino.memory_type = qio_qspi   ; quad PSRAM
```

Note this is `board_build.arduino.memory_type`. PlatformIO ignores
`board_build.psram_type` for Arduino builds, so setting that key produces no
change and no warning, which reads as "the setting had no effect".

Confirm the result in firmware rather than from the boot log:

```cpp
Serial.printf("psram=%u KB found=%d\n", ESP.getPsramSize() / 1024, psramFound());
void *p = heap_caps_malloc(256 * 1024, MALLOC_CAP_SPIRAM);
Serial.printf("256KB SPIRAM alloc -> %s\n", p ? "ok" : "FAILED");
```

**The wrong mode is loud, not subtle.** Arduino's `psramInit()` does not degrade
gracefully when the mode is wrong: it faults and the board boot-loops.

```
E (113) quad_psram: PSRAM chip is not connected, or wrong PSRAM line mode
Guru Meditation Error: Core 0 panic'ed (LoadProhibited)
Backtrace: ... psramInit at esp32-hal-psram.c:73
```

A backtrace through `psramInit` means the mode is wrong, not that the chip is
absent or faulty. Switch modes and reflash.

## 4. Route to the right notes

| Observation | Read |
|---|---|
| `0x38` answers | `variants.md`, then `touch.md` |
| `0x38` silent | this skill as originally written |
| Boot loop through `psramInit` | section 3 above |
| Everything else | `traps.md` — those four apply to every unit seen so far |

## Record what you find

Both variants documented here were characterised from a single physical unit
each. If your fingerprint does not match either, that is worth a pull request
more than it is worth working around quietly.
