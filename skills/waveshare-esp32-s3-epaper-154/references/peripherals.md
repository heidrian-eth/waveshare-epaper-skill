# Other peripherals

## Display with GxEPD2

```cpp
GxEPD2_BW<GxEPD2_154_D67, GxEPD2_154_D67::HEIGHT> display(
    GxEPD2_154_D67(EPD_CS, EPD_DC, EPD_RST, EPD_BUSY));

digitalWrite(EPD_PWR, LOW);              // see trap 2 — active low
SPI.begin(EPD_SCK, -1, EPD_MOSI, EPD_CS);
display.init(115200, true, 20, false);   // reset_duration 20 ms
```

A full refresh takes roughly 1.4 s, which is too slow for interactive feedback.
Use `setPartialWindow()` for the region that changes and reserve full refreshes
for whole-screen transitions.

E-paper also degrades with excessive refreshing. Redraw on state change, not on
a timer.

## Text rendering with Adafruit GFX

Two things bite on a 200×200 panel:

**Word wrap is on by default.** A string wider than the screen is split and the
remainder lands on the next line, often on top of something else. Call
`display.setTextWrap(false)` and size the font to fit instead.

**Fonts are ASCII only.** Accented characters and `ñ` render as garbage. Either
transliterate to ASCII before drawing, or embed a font with the glyphs you
need.

When fitting text into a box, check **height as well as width**. An 18 pt font
is around 25 px tall and will touch the border of a 28 px box even though it
fits horizontally. Centre using `getTextBounds()` rather than a fixed baseline.

## SHTC3 temperature and humidity (I²C 0x70)

```cpp
// wake 0x3517, wait 2 ms
// measure 0x7866 (T first, no clock stretching), wait 15 ms
// read 6 bytes: T MSB, T LSB, CRC, RH MSB, RH LSB, CRC
// sleep 0xB098
tempC   = -45.0f + 175.0f * rawT / 65536.0f;
humidity = 100.0f * rawH / 65536.0f;
```

## Battery

```cpp
float volts = analogReadMilliVolts(BAT_ADC) * 2.0f / 1000.0f;   // GPIO4
```

The divider halves the voltage, hence the ×2. A full cell reads about 4.15 V.

Converting to a percentage linearly between 3.3 V and 4.2 V is a rough
approximation — a lithium cell's discharge curve is far from linear. It is fine
for "plenty left" versus "charge it", not for a real gauge.

**The charge LED blinks when no battery is attached.** That is normal, not a
fault.

## Buttons

`BOOT` on GPIO0 is the only button safe to use freely: `INPUT_PULLUP`, active
low.

`PWR` on GPIO18 is readable as an input and the vendor examples do read it, but
it is wired into the power circuitry. Treat it as input only and validate the
behaviour on battery before relying on it.

With a single usable button, short press plus long press covers most needs.
Fire the long press when the threshold is reached rather than on release, so
the user gets feedback while still holding.

## RTC PCF85063 (I²C 0x51)

Not covered here, but worth using: it keeps time across deep sleep and without
Wi-Fi, and can wake the board. Relying on NTP alone means the board has no idea
what time it is until it joins a network.

## PSRAM

The chip reports 8 MB PSRAM, but Arduino-ESP32 2.x commonly logs:

```
E (197) psram: PSRAM ID read error: 0x00ffffff, PSRAM chip not found or not
supported, or wrong PSRAM line mode
```

even with `psram_type = opi`, which matches the vendor's own
`CONFIG_SPIRAM_MODE_OCT=y`. Harmless if you do not need the extra RAM;
investigate before building anything that depends on it, such as audio buffers
or image handling.
