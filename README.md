# OneMiniMap

**OneMiniMap** is a modular, lightweight Square MiniMap replacement for World of Warcraft featuring the signature OneSuite metal frame aesthetics, a separate frameless translucent title bar, an independently draggable clock, and independently draggable coordinates.

---

## ✨ Features

- **Square MiniMap Geometry**: Converts the native circular minimap into a sleek square using `WHITE8X8` mask rendering, with automatic `GetMinimapShape()` override for third-party addon blip compatibility (Questie, Gatherer, TomTom, Cartographer).
- **Zero Chrome Remnants**: Neutralizes all native circular textures, triangle frames, native zoom buttons, and cluster elements across all client versions.
- **Signature OneSuite Metal Styling**: The square minimap container is framed with silver metal dialog borders (`UI-DialogBox-Border`) and dark marble/slate textures.
- **Separate Frameless Translucent Title Bar**:
  - Displays the Zone / Subzone name with dynamic PvP area coloring (Sanctuary, Contested, Friendly, Hostile, Arena).
  - Frameless with a clean translucent dark background.
  - Positioned directly above the minimap (independently draggable if desired).
  - Left-click to open World Map; hover for detailed zone tooltip.
- **Separate Draggable Clock Frame**:
  - Freely draggable with position memory (`OneMiniMapDB.clockPosition`).
  - Click to toggle between 12-hour and 24-hour formats.
  - Frameless translucent background.
- **Separate Draggable Coordinates Frame**:
  - Freely draggable with position memory (`OneMiniMapDB.coordPosition`).
  - Displays live player coordinates (`XX.X, YY.X`) formatted in gold.
  - Throttled update rate (0.15s) with cross-client support (Vanilla 1.12, Turtle WoW 1.16, WotLK 3.3.5, and Modern WoW).
  - Frameless translucent background.
- **Mouse Wheel Zooming**: Scroll up to zoom in, scroll down to zoom out on the minimap.
- **Clean Button Docking**: Neatly docks tracking, mail, calendar/time, and queue icons along the corners of the square map frame without cluttering the screen.
- **Full Drag & Lock Controls**:
  - Drag frames when unlocked (or `Alt` + drag the minimap).
  - Lock/unlock all frames with `/omm lock` and `/omm unlock`.

---

## ⌨️ Slash Commands

Use `/omm` or `/oneminimap`:

- `/omm lock` — Lock all frame positions.
- `/omm unlock` — Unlock all frames for dragging.
- `/omm title` — Toggle the title bar frame.
- `/omm clock` — Toggle the clock frame.
- `/omm coords` — Toggle the coordinates frame.
- `/omm scale <0.5 - 2.0>` — Adjust the overall scale.
- `/omm reset` — Reset all frames to default layout.
