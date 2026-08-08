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

## PSRAM — unresolved

On a V2 board, `esptool.py flash_id` reports `Embedded PSRAM 8MB (AP_3v3)`, yet
Arduino-ESP32 2.x logs at every boot:

```
E (197) psram: PSRAM ID read error: 0x00ffffff, PSRAM chip not found or not
supported, or wrong PSRAM line mode
```

Both `psram_type = opi` (matching the vendor's own `CONFIG_SPIRAM_MODE_OCT=y`)
and `psram_type = qio` produce the same error. The `AP_3v3` marking suggests
quad rather than octal — the S3's octal parts run at 1.8 V — but changing the
mode alone does not fix it.

Documented as **open**, not solved. Harmless if you do not need the extra RAM.
It does bite if you do: without PSRAM, audio recording is limited to a few
seconds of internal RAM instead of minutes. If you resolve it, a pull request
would help the next person.
