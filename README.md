# Waveshare ESP32-S3-ePaper-1.54 — Agent Skill

A skill for AI coding agents working with the **Waveshare ESP32-S3-ePaper-1.54**
board: a 1.54" 200×200 black-and-white e-paper display with an ESP32-S3,
speaker, microphone, microSD, RTC, temperature/humidity sensor and lithium
battery management.

Skills follow the [Agent Skills](https://agentskills.io/) format and this repo
is listed on [skills.sh](https://skills.sh/jonymusky/waveshare-epaper-skill).

```bash
npx skills add jonymusky/waveshare-epaper-skill
```

## Why this exists

The board is capable and cheap, but four of its behaviours contradict what the
documentation implies — and each one produces a symptom that points at the
wrong subsystem. Finding them took hours. This skill exists so nobody has to
find them twice.

The worst offender: **the panel's power pin is active low**. Drive it HIGH, as
you would any pin named `EPD_PWR`, and the display loses power. SPI keeps
writing into a dead bus, the graphics library keeps reporting refresh timings,
and the screen keeps showing whatever was on it before. Everything looks like
the firmware never ran.

## Install

```bash
npx skills add jonymusky/waveshare-epaper-skill
```

Works with Claude Code, Cursor, Codex, OpenCode and others. Or copy
`skills/waveshare-esp32-s3-epaper-154/` straight into your agent's skills
directory.

## What's covered

| File | Contents |
|---|---|
| `SKILL.md` | Entry point and summary of the traps |
| `references/pinout.md` | Verified GPIO map — display, audio, I²C, SD, battery |
| `references/traps.md` | The four traps in full, with symptoms and fixes |
| `references/display.md` | Partial refresh, ghosting, text fitting, GxEPD2 setup |
| `references/audio.md` | ES8311 bring-up and the DMA drain problem |
| `references/peripherals.md` | SHTC3, RTC, battery, buttons, GxEPD2, text rendering |

### The four traps, in one line each

1. **Two hardware revisions, neither matching the listing.** V1 is 4 MB/2 MB,
   V2 is 8 MB/8 MB; listings often say 16 MB. Wrong size = boot loop.
2. **`EPD_PWR` (GPIO6) is active LOW.** HIGH silently powers the panel off.
3. **GPIO18 is the PWR button, not the battery enable.** That's GPIO17.
4. **`i2s_write()` returns on enqueue, not playback.** Short sounds vanish.

Plus two things worth knowing before you start: a static e-paper screen proves
nothing about whether the board is running, and native USB means a healthy
board can fail to enumerate.

## Where the pin map comes from

The vendor wiki documents the **1.54G** (4-colour) variant, whose pins differ.
A web search returns a third, incorrect map. The only reliable source is
`user_config.h` in the vendor's own repository:

<https://github.com/waveshareteam/ESP32-S3-ePaper-1.54>

## Buy the board

- Waveshare, official: <https://www.waveshare.com/esp32-s3-epaper-1.54.htm?sku=32298>
- Argentina, MercadoLibre: <https://meli.la/2aUTSFb>

Two things to check before buying. Make sure it is the black-and-white
`ESP32-S3-ePaper-1.54` and **not** the 4-colour `1.54G` — the pin maps differ
and this skill documents the B/W board. And note the **two hardware
revisions**: V1 with 4 MB flash / 2 MB PSRAM, V2 with 8 MB / 8 MB.

## Contributing

Corrections and additions are welcome, especially for the RTC, the microphone,
deep sleep and battery life, and the PSRAM warning that this skill flags but
does not resolve.

## License

MIT
