# Driving the panel well

## Always use partial refresh where you can

This is the single biggest quality difference between a sluggish e-paper
project and a pleasant one.

| Operation | Time |
|---|---|
| Full refresh (`setFullWindow`) | ~1.4 s, whole panel flashes black |
| Partial refresh (`setPartialWindow`) | ~0.3 s, only the region changes |

A full refresh is nearly five times slower **and** flashes the entire screen to
black and back. On an interactive device — a menu, a selection, a counter,
anything a person is waiting on — that reads as broken.

**Rule of thumb:** if the change is confined to part of the screen, use
`setPartialWindow` over that region. Reserve full refreshes for genuine screen
transitions, where the flash actually communicates "this is a new screen".

```cpp
display.setPartialWindow(0, y, width, height);
display.firstPage();
do {
  display.fillScreen(GxEPD_WHITE);   // clears only the partial window
  drawTheChangedThing();
} while (display.nextPage());
```

### The catch: ghosting

Partial refreshes leave faint residue from the previous image, and it
accumulates. After enough of them the panel looks dirty and eventually becomes
hard to read. This is why partial refresh is not simply "the fast mode".

Interleave a full refresh periodically to clear it:

```cpp
static const int PARTIALS_BEFORE_CLEAN = 20;
int partialCount = 0;

bool needsClean() {
  if (++partialCount >= PARTIALS_BEFORE_CLEAN) { partialCount = 0; return true; }
  return false;
}
```

Twenty is a reasonable starting point. If ghosting is visible sooner, lower it.
Also reset the counter whenever you do a full refresh for other reasons, so the
budget tracks actual partial updates.

### Where it matters most

- **Menus and selection.** The most frequent interaction on the device.
- **A clock that ticks.** Redrawing the whole screen once a minute is 1440 full
  refreshes a day: slow, visually noisy, and the main source of panel wear.
  Redraw only the time region; do a full refresh when the *content* changes.
- **Multiple-choice options.** Redraw just the option area on each move.
- **Counters and status values.** Only the number changed.

## Measured refresh cost

GxEPD2 reports its own timing, which is worth reading once rather than
estimating:

| Refresh | Cost |
|---|---|
| Partial window | 437 ms |
| Full screen | 1815 ms |

Partial refresh time is set by the panel's waveform, not by how much changed: a
200x8 window and a full 200x200 differ by well under 100 ms. Computing a
minimal dirty rectangle to push fewer pixels therefore buys nothing.

Both numbers are long enough to matter to anything else the firmware is doing.
A redraw on the same task as real-time audio will interrupt it audibly, and a
redraw inside a touch handler outlasts a typical debounce window — see
`touch.md`.

## Refresh sparingly

E-paper degrades with refresh count, and it holds its image with zero power.
Redraw on state change, not on a timer. A screen that has not changed should
not be refreshed at all.

## A static screen proves nothing

The panel keeps its last image with no power. A board that is off, one that has
crashed, and one that is idle and simply not redrawing all look identical.

This causes real debugging losses. Never infer liveness from the panel — check
over serial, over the network, or with a heartbeat print. And if your UI has a
state where nothing redraws (a menu waiting for input), consider returning to a
self-updating screen after a timeout, so the device does not *look* dead when it
is merely waiting.

## Text rendering with Adafruit GFX

**Word wrap is on by default.** A string wider than the screen gets split and
the remainder lands on the next line, often over something else. Call
`display.setTextWrap(false)` and size the font to fit instead.

**Fonts are ASCII only.** Accented characters and `ñ` render as garbage — a
real constraint when the content is Spanish, French, or Portuguese. Either
transliterate to ASCII before drawing, or embed a font containing the glyphs
you need.

**Check height as well as width when fitting text to a box.** An 18 pt font is
around 25 px tall and will touch the border of a 28 px box even though it fits
horizontally. Pick the largest font whose wrapped text fits in *both*
dimensions, and centre with `getTextBounds()` rather than a fixed baseline.

## Initialisation

```cpp
GxEPD2_BW<GxEPD2_154_D67, GxEPD2_154_D67::HEIGHT> display(
    GxEPD2_154_D67(EPD_CS, EPD_DC, EPD_RST, EPD_BUSY));

digitalWrite(EPD_PWR, LOW);              // active low — see traps.md
SPI.begin(EPD_SCK, -1, EPD_MOSI, EPD_CS);
display.init(115200, true, 20, false);   // reset_duration 20 ms, not 2
display.setTextWrap(false);
```
