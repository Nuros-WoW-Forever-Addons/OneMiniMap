# OneMiniMap

**OneMiniMap** is a modular, lightweight Square MiniMap replacement for World of Warcraft featuring signature OneSuite metal frame aesthetics, a separate frameless translucent title bar, an independently draggable clock, and independently draggable coordinates.

Part of the **OneSuite** family of addons.

---

## 🚀 Features

- 🗺️ **Square MiniMap Geometry**: Converts the native circular minimap into a sleek square using `WHITE8X8` mask rendering, with automatic `GetMinimapShape()` override for third-party addon blip compatibility (Questie, Gatherer, TomTom, Cartographer).
- 🧼 **Zero Chrome Remnants**: Neutralizes all native circular textures, triangle frames, native zoom buttons, and cluster elements across all client versions.
- 🛡️ **Signature OneSuite Metal Styling**: Framed with authentic silver metal dialog borders (`UI-DialogBox-Border`) and dark slate/marble textures.
- 🏷️ **Separate Frameless Translucent Title Bar**:
  - Displays the Zone / Subzone name with dynamic PvP area coloring (Sanctuary, Contested, Friendly, Hostile, Arena).
  - Frameless with a clean translucent dark background.
  - Positioned directly above the minimap (independently draggable if desired).
  - Left-click to open World Map; hover for detailed zone tooltip.
- 🕒 **Separate Draggable Clock Frame**:
  - Freely draggable with persistent position memory (`OneMiniMapDB.clockPosition`).
  - Click to toggle between 12-hour and 24-hour formats.
  - Slash command `/omm time` toggles between Local Time and Server Time.
- 📍 **Separate Draggable Coordinates Frame**:
  - Freely draggable with persistent position memory (`OneMiniMapDB.coordPosition`).
  - Displays live player coordinates (`XX.X, YY.X`) formatted in crisp gold text.
  - Throttled update rate (0.15s) with cross-client support (Vanilla 1.12, Turtle WoW 1.16, WotLK 3.3.5, and Modern WoW).
- 🔍 **Mouse Wheel Zooming**: Scroll up to zoom in, scroll down to zoom out directly over the minimap.
- 🗃️ **Integrated Button Collector**: Neatly docks tracking, mail, calendar/time, and queue icons along corners or into an organized collapsible tray without cluttering the screen.
- 🔒 **Full Drag & Lock Controls**: Drag frames when unlocked (or `Alt` + drag the minimap). Lock/unlock all frames with `/omm lock` and `/omm unlock`.

---

## 🛠️ Installation

Copy the `OneMiniMap` directory into your World of Warcraft `Interface/AddOns/` directory:

```text
World of Warcraft/Interface/AddOns/OneMiniMap/
├── OneMiniMap.toc
├── Core.lua
├── ButtonCollector.lua
├── OptionsUI.lua
├── CHANGELOG.md
├── CONTEXT.md
└── README.md
```

Then start or reload World of Warcraft (`/reload`).

---

## 💻 Slash Commands

| Command | Description |
|---|---|
| `/omm` or `/oneminimap` | Open / toggle options configuration panel |
| `/omm lock` | Lock all frame positions |
| `/omm unlock` | Unlock all frames for dragging |
| `/omm title` | Toggle the title bar frame on or off |
| `/omm clock` | Toggle the clock frame on or off |
| `/omm time` | Toggle between Local Time and Server Time |
| `/omm coords` | Toggle the coordinates frame on or off |
| `/omm buttons` | Toggle the button collector tray on or off |
| `/omm scale <0.5 - 2.0>` | Adjust overall minimap scale |
| `/omm dump` | Print diagnostic frame inspector details |
| `/omm reset` | Reset all frames and positions to default layout |

---

For detailed version history and release notes, see [CHANGELOG.md](CHANGELOG.md).
