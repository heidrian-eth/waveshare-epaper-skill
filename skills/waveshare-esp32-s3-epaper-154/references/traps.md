# The four traps

Each of these produces a symptom that points at the wrong subsystem. They are
listed in the order you are likely to hit them.

---

## 1. The flash size is not what the listing says

**Symptom.** Continuous boot loop right after flashing:

```
E (192) spi_flash: Detected size(8192k) smaller than the size in the
                   binary image header(16384k). Probe failed.
assert failed: do_core_init startup.c:328 (flash_ret == ESP_OK)
Rebooting...
```

**Cause.** **Two hardware revisions ship under the same product name:** V1 with
4 MB flash and 2 MB PSRAM, V2 with 8 MB and 8 MB. Retail listings frequently
claim 16 MB, which matches neither. Whatever the page says, the silicon is the
authority.

**Fix.** Set the flash size to 8 MB and use an 8 MB partition table. In
PlatformIO:

```ini
board_upload.flash_size = 8MB
board_build.partitions = default_8MB.csv
```

**Rule.** Never take flash or PSRAM size from documentation or a listing.
Ask the chip:

```
esptool.py --chip esp32s3 flash_id
```

---

## 2. `EPD_PWR` (GPIO6) is active LOW

This is the most misleading failure on the board.

**Symptom.** Firmware runs, serial log is healthy, GxEPD2 prints refresh
timings — and the screen never changes. Often it still shows the factory demo
(`ble:`, `wifi:`, `sdcard: No sd card`, a battery percentage).

**Cause.** GPIO6 gates power to the panel and is **active low**. From the
vendor's own `board_power_bsp.cpp`:

```c
void POWEER_EPD_ON()  { gpio_set_level(epd_power_pin, 0); }   // LOW  = on
void POWEER_EPD_OFF() { gpio_set_level(epd_power_pin, 1); }   // HIGH = off
```

Driving it HIGH — the intuitive choice for an "enable" pin — powers the panel
down. SPI then writes into a dead bus and nothing reports an error.

**Fix.**

```cpp
pinMode(EPD_PWR, OUTPUT);
digitalWrite(EPD_PWR, LOW);   // LOW powers the panel ON
delay(50);
```

**A misleading clue.** With the panel unpowered, GxEPD2 still prints lines like
`_Update_Full : 1391991`. Those numbers look like real refresh timings. They are
near-identical across runs because nothing is actually being measured — but
consistent timings are also what a healthy panel produces, so this signal
cannot distinguish the two cases. Do not spend time on it.

`AUDIO_PWR` (GPIO42) follows the same active-low convention.

---

## 3. GPIO18 is the PWR button, not the battery enable

**Symptom.** The board dies the moment USB is unplugged, even with a charged
battery attached. The screen keeps its last image, so it looks frozen rather
than off.

**Cause.** Battery power enable is **GPIO17** (`VBAT_PWR`), driven HIGH.
GPIO18 is the PWR **button** — an input. Configuring it as an output shorts a
pushbutton to ground when pressed.

**Fix.**

```cpp
pinMode(VBAT_PWR, OUTPUT);     // GPIO17
digitalWrite(VBAT_PWR, HIGH);  // HIGH keeps the board alive off USB
pinMode(BTN_PWR, INPUT);       // GPIO18 — input only
```

---

## 4. `i2s_write()` returns on enqueue, not on playback

**Symptom.** Long test tones play. Short sounds — clicks, UI feedback, anything
under about 150 ms — are completely silent.

**Cause.** `i2s_write()` returns once the data is queued into the DMA ring, not
once it has been clocked out. With 8 buffers of 256 samples at 16 kHz there is
roughly 128 ms of audio queued ahead. Switching off the amplifier immediately
after writing cuts the sound before it reaches the speaker.

**Fix.** Drain the queue deterministically instead of guessing a delay. Writing
a full ring of silence guarantees everything before it has been played:

```cpp
void ampOff() {
  int16_t silence[DMA_LEN] = {0};
  size_t written = 0;
  for (int i = 0; i < DMA_COUNT; i++)
    i2s_write(I2S_PORT, silence, sizeof(silence), &written, portMAX_DELAY);
  delay(20);
  digitalWrite(AUDIO_PA, LOW);
}
```

Wrap the amplifier around a whole sound sequence, not each note: toggling it
per note both truncates the audio and clicks on every transition.

---

## Bonus: a static e-paper screen proves nothing

E-paper retains its image with zero power. A board that is switched off, one
that has crashed, and one that is running but not drawing all look identical.

Never diagnose from the panel. Check liveness over serial, or over the network
with a ping, or by having the firmware print a heartbeat.

## Bonus: native USB means no serial port when firmware misbehaves

This board uses the ESP32-S3's native USB rather than a UART bridge chip. If
the running firmware does not enable USB CDC, the port never appears on the
host — with a perfectly good cable.

To reach the ROM bootloader, which always enumerates: unplug, hold **BOOT**,
plug in while still holding, release after two seconds.

If the port still does not appear, the data lines are not connected: suspect a
charge-only cable or a charge-only port on a hub before suspecting the board.
