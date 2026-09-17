# Verified GPIO map

Source: `02_Example/Arduino/07_BATT_PWR_Test/user_config.h` and
`board_cfg.txt` (entry `S3_ePaper_1_54`) in
<https://github.com/waveshareteam/ESP32-S3-ePaper-1.54>.

Do not use the pin map from the wiki: that page documents the **1.54G**
(4-colour) variant. A web search for this board also returns a map with
`BUSY=5, RST=7, DC=4, CS=10, SCK=1, MOSI=2` — that map is wrong for both
variants.

## E-paper (SSD1681, 200×200, B/W)

| Signal | GPIO | Note |
|---|---|---|
| `EPD_PWR` | 6 | **Active LOW.** LOW = panel powered |
| `EPD_BUSY` | 8 | |
| `EPD_RST` | 9 | |
| `EPD_DC` | 10 | |
| `EPD_CS` | 11 | |
| `EPD_SCK` | 12 | |
| `EPD_MOSI` | 13 | |

GxEPD2 class: `GxEPD2_154_D67`. Use `reset_duration = 20` in `display.init()`
— a shorter pulse can leave the panel unreset.

## Touch (FT6336) — touch variant only

Present on `ESP32-S3-Touch-ePaper-1.54`. Confirm it answers at `0x38` before
using these; see `identify.md`. Full notes in `touch.md`.

| Signal | GPIO | Note |
|---|---|---|
| `TP_RST` | 7 | Reset, active low. Needs a 150 ms settle |
| `TP_INT` | 21 | Interrupt, falls on touch |

## Audio (ES8311 codec, I²C address 0x18)

| Signal | GPIO | Note |
|---|---|---|
| `MCLK` | 14 | Required. The codec has no internal oscillator here |
| `BCLK` | 15 | |
| `WS` / `LRCK` | 38 | |
| `DIN` | 16 | Codec → ESP32 (microphone) |
| `DOUT` | 45 | ESP32 → codec (speaker) |
| `AUDIO_PWR` | 42 | **Active LOW**, powers the audio rail |
| `PA` | 46 | Amplifier enable, **active HIGH** |

Both `AUDIO_PWR` and `PA` are needed: 42 powers the section, 46 enables the
amplifier. `pa_gain` is 6 dB, `use_mclk` is 1.

## I²C bus (shared)

| Device | Address |
|---|---|
| ES8311 codec | 0x18 |
| PCF85063 RTC | 0x51 |
| SHTC3 temp/humidity | 0x70 |
| FT6336 touch | 0x38 (touch variant only) |

SDA = GPIO47, SCL = GPIO48.

## microSD (SDIO)

| Signal | GPIO |
|---|---|
| `CLK` | 39 |
| `CMD` / MOSI | 41 |
| `D0` / MISO | 40 |

## Power and buttons

| Signal | GPIO | Note |
|---|---|---|
| `BAT_ADC` | 4 | `VBAT = reading × 2` (resistor divider) |
| `VBAT_PWR` | 17 | Battery enable, **HIGH** to stay alive off USB |
| `BOOT` button | 0 | Input, active low |
| `PWR` button | 18 | **Input only.** Never drive as output |

## Silicon

Confirmed with `esptool.py flash_id`. Note that this output is **the same on
both units**, so it cannot be used to tell them apart — see `identify.md`:

```
Features: WiFi, BLE, Embedded Flash 8MB (GD), Embedded PSRAM 8MB (AP_3v3)
Crystal is 40MHz
Detected flash size: 8MB
```

USB is **native ESP32-S3 USB**, not a UART bridge chip. This matters: if the
running firmware does not enable USB CDC, the board never enumerates. Hold BOOT
while applying power to reach the ROM bootloader, which always enumerates.
