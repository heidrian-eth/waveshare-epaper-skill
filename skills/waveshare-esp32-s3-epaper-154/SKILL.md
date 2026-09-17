---
name: waveshare-esp32-s3-epaper-154
description: Build firmware for the Waveshare ESP32-S3-ePaper-1.54 and ESP32-S3-Touch-ePaper-1.54 boards (200x200 B/W e-paper, ES8311 audio, SHTC3 sensor, PCF85063 RTC, microSD, battery, FT6336 touch on the touch variant). Use when working with either board or any ESP32-S3 e-paper board that shows a blank/frozen screen, boot-loops on flash size or PSRAM init, stays silent through an ES8311 codec, or dies when USB is unplugged. Covers the verified pin map, four hardware traps absent from the vendor documentation, and how to tell the variants apart.
license: MIT
---

# Waveshare ESP32-S3-ePaper-1.54

A 1.54" 200×200 black-and-white e-paper board with an ESP32-S3, speaker, mic,
microSD, RTC, temperature/humidity sensor and lithium battery management.

**Read `references/traps.md` before writing any code for this board.** Four
hardware behaviours contradict what the documentation implies, and each one
produces a symptom that points at the wrong subsystem. Together they cost
several hours of debugging that this skill exists to save.

## First, identify your unit

Two boards ship under closely related names, and they report **identically** to
`esptool` and `espefuse` — same chip, same 8 MB flash, same `PSRAM_VENDOR`.
The check that separates them is an I2C scan: a device answering at `0x38` is
an FT6336 touch controller.

Run `scripts/identify.sh`, then follow `references/identify.md`. It routes you
to the right notes and keeps you from applying a setting that was verified on
the other board.

Everything below applies to both units unless a page says otherwise.
`references/variants.md` has the measurements where the two differ.

## The ground truth for pins

The vendor wiki documents the **1.54G** (4-colour) variant, and its pin map
differs from the black-and-white board. Web searches return a third, wrong map.

The only reliable source is `user_config.h` in the vendor's own repository:
<https://github.com/waveshareteam/ESP32-S3-ePaper-1.54>

`references/pinout.md` has the verified table. Trust that over any wiki page.

## The four traps

Full detail in `references/traps.md`. In short:

1. **Two hardware revisions exist under one name.** V1 has 4 MB flash / 2 MB
   PSRAM; V2 has 8 MB / 8 MB. Listings often claim 16 MB, which is neither.
   Configuring the wrong size gives a boot loop. Always ask the chip with
   `esptool.py flash_id` instead of trusting any datasheet or listing.

2. **`EPD_PWR` (GPIO6) is active LOW.** Driving it HIGH cuts power to the
   panel. SPI then writes into a dead bus, GxEPD2 still reports refresh times,
   and the screen keeps its previous image — so it looks like the firmware
   never ran. This is the single most misleading failure on this board.

3. **GPIO18 is the PWR button, not the battery enable.** Battery power is
   GPIO17, driven HIGH. Driving GPIO18 as an output shorts a button to ground.

4. **`i2s_write()` returns on enqueue, not on playback.** Switching off the
   speaker amplifier right after writing cuts short sounds entirely. Drain the
   DMA queue first — see `references/audio.md`.

## Always use partial refresh where you can

A full refresh takes ~1.4 s and flashes the whole panel black. A partial
refresh over just the changed region takes ~0.3 s and does not flash. On
anything interactive — a menu, a selection, a ticking clock — using full
refreshes everywhere is the difference between a device that feels broken and
one that feels good.

The catch is ghosting: partial refreshes leave residue that accumulates, so
interleave a full refresh every ~20 partials to clear the panel. Details and
patterns in `references/display.md`.

## Always use partial refresh where you can

A full refresh takes ~1.4 s and flashes the whole panel black. A partial
refresh over just the changed region takes ~0.3 s and does not flash. On
anything interactive — a menu, a selection, a ticking clock — using full
refreshes everywhere is the difference between a device that feels broken and
one that feels good.

The catch is ghosting: partial refreshes leave residue that accumulates, so
interleave a full refresh every ~20 partials to clear the panel. Patterns and
the exact trade-off are in `references/display.md`.

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
| `references/display.md` | Partial refresh, ghosting, text fitting, GxEPD2 setup |
| `references/display.md` | Partial refresh, ghosting, text fitting, GxEPD2 setup |
| `references/audio.md` | ES8311 bring-up, the DMA drain problem, tone generation |
| `references/peripherals.md` | SHTC3, PCF85063 RTC, battery ADC, buttons |
| `references/identify.md` | Which unit you have, and which settings follow from it |
| `references/variants.md` | Where two measured units differ, and what was measured |
| `references/touch.md` | FT6336 touch controller — touch variant only |
