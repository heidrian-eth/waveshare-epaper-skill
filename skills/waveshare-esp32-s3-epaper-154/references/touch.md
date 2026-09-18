# Touch: FT6336

Only on the touch variant. Confirm the controller answers at `0x38` before
writing any of this, using `identify.md` section 2.

Source: `02_Example/Arduino/12_FT6336_Test/` in
`waveshareteam/ESP32-S3-ePaper-1.54`.

## Pins

| Signal | GPIO | Note |
|---|---|---|
| `TP_RST` | 7 | Reset, active low |
| `TP_INT` | 21 | Interrupt, falling edge on touch |
| SDA | 47 | Shared I2C bus |
| SCL | 48 | Shared I2C bus |

I2C address `0x38`, on the same bus as the codec, RTC and SHTC3.

## The controller needs a reset before it answers

Out of power-on it can sit silent on the bus, so an I2C scan finds nothing at
`0x38` and the panel looks like a non-touch unit. Pulse reset first:

```cpp
pinMode(TP_RST, OUTPUT);
digitalWrite(TP_RST, LOW);  delay(20);
digitalWrite(TP_RST, HIGH); delay(150);   // needs the full settle
```

150 ms is not generous. A shorter settle gives intermittent detection, which
reads as flaky wiring.

## Reading a point

Register `0x02` holds the number of active touches, then two big-endian
12-bit coordinates. The top nibble of each high byte is flags, not data.

```cpp
bool touchRead(uint16_t &x, uint16_t &y) {
  Wire.beginTransmission(0x38);
  Wire.write(0x02);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(0x38, 5) != 5) return false;
  uint8_t n  = Wire.read() & 0x0F;
  uint8_t xh = Wire.read(), xl = Wire.read();
  uint8_t yh = Wire.read(), yl = Wire.read();
  if (n == 0 || n > 2) return false;         // 0x0F means "no touch"
  x = ((xh & 0x0F) << 8) | xl;
  y = ((yh & 0x0F) << 8) | yl;
  return true;
}
```

Masking the high nibble matters: without it an idle controller reports
coordinates in the thousands on a 200x200 panel.

## Prefer the interrupt to polling

Polling over I2C competes with the SHTC3 and the RTC on the same bus, and it
burns power on a board meant to sleep. GPIO21 falls on touch:

```cpp
gpio_config_t io = {};
io.intr_type = GPIO_INTR_NEGEDGE;
io.pin_bit_mask = 1ULL << TP_INT;
io.mode = GPIO_MODE_INPUT;
io.pull_up_en = GPIO_PULLUP_ENABLE;
gpio_config(&io);
```

The vendor example queues the pin number from the ISR and reads coordinates from
a task, which is the right shape: the I2C read must not happen in interrupt
context.

## Debounce must outlast the redraw, not the finger

If a touch triggers a partial refresh, the handler is busy for the length of
that refresh — measured at 437 ms on this panel. A debounce window shorter than
that lets an interrupt raised *during* the redraw through as a fresh touch, and
a state machine that toggles on touch immediately toggles back.

The symptom is specific and misleading: the action fires and undoes itself at
once, looking like a state-machine bug rather than a timing one. It also only
appears once a touch starts driving a redraw, so it arrives long after the
touch handling itself was working.

Set the debounce above the refresh cost, and clear the pending-touch flag after
the slow work rather than before it, so anything raised meanwhile is discarded.

## Touch and e-paper are a poor match for drag

A partial refresh takes around 0.3 s, so anything tracking a finger will lag
badly no matter how fast the controller reports. Design for taps on targets
large enough to hit without feedback, and redraw only the region that changed.
`display.md` covers the refresh budget.
