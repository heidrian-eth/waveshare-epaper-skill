---
name: waveshare-esp32-s3-epaper-154
description: Build firmware for the Waveshare ESP32-S3-ePaper-1.54 board (200x200 B/W e-paper, ES8311 audio, SHTC3 sensor, PCF85063 RTC, microSD, battery). Use when working with this board or any ESP32-S3 e-paper board that shows a blank/frozen screen, boot-loops on flash size, stays silent through an ES8311 codec, or dies when USB is unplugged. Covers the verified pin map and four hardware traps that are absent from the vendor documentation.
license: MIT
---

# Waveshare ESP32-S3-ePaper-1.54

A 1.54" 200×200 black-and-white e-paper board with an ESP32-S3, speaker, mic,
microSD, RTC, temperature/humidity sensor and lithium battery management.

**Read `references/traps.md` before writing any code for this board.** Four
hardware behaviours contradict what the documentation implies, and each one
produces a symptom that points at the wrong subsystem. Together they cost
several hours of debugging that this skill exists to save.

## The ground truth for pins

The vendor wiki documents the **1.54G** (4-colour) variant, and its pin map
differs from the black-and-white board. Web searches return a third, wrong map.

The only reliable source is `user_config.h` in the vendor's own repository:
<https://github.com/waveshareteam/ESP32-S3-ePaper-1.54>

`references/pinout.md` has the verified table. Trust that over any wiki page.

## The four traps

Full detail in `references/traps.md`. In short:

1. **Flash is 8 MB, not 16.** Configuring 16 MB gives a boot loop with
   `Detected size(8192k) smaller than the size in the binary image header`.
   Always confirm with `esptool.py flash_id` instead of trusting the datasheet.

2. **`EPD_PWR` (GPIO6) is active LOW.** Driving it HIGH cuts power to the
   panel. SPI then writes into a dead bus, GxEPD2 still reports refresh times,
   and the screen keeps its previous image — so it looks like the firmware
   never ran. This is the single most misleading failure on this board.

3. **GPIO18 is the PWR button, not the battery enable.** Battery power is
   GPIO17, driven HIGH. Driving GPIO18 as an output shorts a button to ground.

4. **`i2s_write()` returns on enqueue, not on playback.** Switching off the
   speaker amplifier right after writing cuts short sounds entirely. Drain the
   DMA queue first — see `references/audio.md`.

## Diagnosing a dead screen

E-paper holds its last image with no power at all, so a static screen tells you
nothing about whether the board is running. A powered-off board and a crashed
board look identical. Check liveness over serial or the network, never by
looking at the panel.

If the panel shows the factory demo (`ble:`, `wifi:`, `sdcard: No sd card`,
a battery percentage), your firmware is not reaching the panel. Check trap 2
first.

## Reference files

| File | Contents |
|---|---|
| `references/pinout.md` | Verified GPIO map for display, audio, I²C, SD, battery |
| `references/traps.md` | The four traps in full, with symptoms and fixes |
| `references/audio.md` | ES8311 bring-up, the DMA drain problem, tone generation |
| `references/peripherals.md` | SHTC3, PCF85063 RTC, battery ADC, buttons |
