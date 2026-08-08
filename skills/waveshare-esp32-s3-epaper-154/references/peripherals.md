# Other peripherals

For the panel itself see `display.md`.

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

## PSRAM — unresolved, but well characterised

On a V2 board, every boot logs:

```
E (197) psram: PSRAM ID read error: 0x00ffffff, PSRAM chip not found or not
supported, or wrong PSRAM line mode
```

`0x00ffffff` is all-ones: nothing answers on the bus. At runtime,
`psramFound()` returns false and `ESP.getPsramSize()` is 0.

**The PSRAM is definitely present.** From `espefuse.py summary`:

```
PSRAM_CAP    = 8M
PSRAM_VENDOR = AP_3v3        (AP Memory, 3.3 V — so quad, not octal:
                              the S3's octal parts run at 1.8 V)
FLASH_TYPE   = 4 data lines
```

Ruled out, so you do not have to repeat any of it:

| Hypothesis | Result |
|---|---|
| Faulty unit | No — two boards fail identically |
| `board_build.psram_type = opi` | No effect |
| `board_build.psram_type = qio` | No effect |
| `board_build.arduino.memory_type = qio_qspi` | No effect |
| GPIO45 strapping (it selects VDD_SPI voltage **and** is the I²S data-out pin, so it looked like a strong lead) | No — fails identically on a cold power-on, before any firmware touches it |
| eFuses forcing VDD_SPI or remapping SPI pads | All at defaults |

The remaining hypothesis is that Arduino-ESP32 2.x's precompiled libraries do
not support this package's PSRAM configuration. Confirming it means building a
minimal ESP-IDF example, where quad mode and voltage can be set explicitly
rather than picking between two prebuilt variants.

**Whether it is worth chasing depends on what you need PSRAM for.** The usual
motivation is buffering audio: without it, recording is limited to a few
seconds of internal RAM. If your board has a microSD slot — this one does —
streaming audio to and from a file removes the need entirely, at far less cost
than migrating a working Arduino project to ESP-IDF.

If you do resolve it, a pull request would help the next person.
