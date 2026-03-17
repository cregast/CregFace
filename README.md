# CregFace

A custom analog watchface for the **Garmin Vivoactive 5**, written in [Monkey C](https://developer.garmin.com/connect-iq/monkey-c/) using the Connect IQ SDK. Designed for clarity and low power consumption on AMOLED displays.

---

## Features

### Active Face
A traditional analog watchface with a static dial rendered from a pre-composited bitmap buffer. The dial includes major and minor tick marks with labeled hour numerals.

**Hands**
- Light gray hour and minute hands
- Red seconds hand with a short counterbalance tail

**Four complications at the cardinal positions:**

| Position | Complication |
|----------|-------------|
| 12 o'clock | Digital time (large, 12-hour format) |
| 3 o'clock | Day and short date — e.g. `Wed 4` — black text on white background, emulating a date cutout window |
| 6 o'clock | Daily step count; red notification dot appears above when unread notifications are pending |
| 9 o'clock | Battery percentage; turns red when below 15% |

### Low-Power (Sleep) Face
When the watch enters idle/always-on mode, the face switches to a minimal layout: large centered digital time with a smaller date line below it (e.g. `Wed, Mar 4`). No analog hands or complications are drawn.

---

## Power Optimization

- **Buffered dial bitmap** — the static dial (tick marks, hour labels) is rendered once into an off-screen `BufferedBitmap` at layout time and blitted each frame, avoiding repeated vector drawing.
- **Pre-computed trig tables** — sine/cosine values for all 60 positions and hand endpoint coordinates for seconds (60 entries), minutes (60 entries), and hours (720 entries, one per minute of the 12-hour cycle) are computed once in `onLayout()` and looked up at draw time.
- **Partial updates** — `onPartialUpdate()` redraws only the seconds hand each second using a clip-and-repaint approach (erase previous position from table, draw new position). Full `onUpdate()` runs only once per minute or on sleep/wake transitions.
- **Date caching** — the formatted date strings are only recomputed when the calendar day changes, not on every draw cycle.
- **Sleep face suppression** — `onPartialUpdate()` returns immediately when the watch is in low-power mode; no drawing occurs.

---

## Requirements

- **Device:** Garmin Vivoactive 5
- **SDK:** Garmin Connect IQ SDK (Monkey C)
- **Connect IQ API Level:** 4.x+ (uses `Graphics.createBufferedBitmap`, `Graphics.BitmapReference`)

---

## Building & Installing

1. Install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and configure your IDE (VS Code with the Monkey C extension recommended).
2. Clone this repo and open the project folder.
3. Build for the Vivoactive 5 target using the SDK simulator or sideload via Garmin Express / the Connect IQ app.

---

## License

Personal project — no license applied. Not affiliated with or endorsed by Garmin.
