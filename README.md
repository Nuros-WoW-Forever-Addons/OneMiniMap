# OneMiniMap

**OneMiniMap** is a lightweight, clean square MiniMap replacement for World of Warcraft featuring the signature OneSuite metal frame aesthetics, high-visibility top coordinates, and smooth mouse-wheel zooming.

Designed for players who want a minimal, square map replacement reminiscent of CleanMiniMap and Chinchilla without complex bloat, unnecessary configuration panels, or heavy dependencies.

---

## ✨ Features

- **Square MiniMap Geometry**: Seamlessly converts the native circular minimap into a sleek square using `WHITE8X8` mask rendering, with automatic `GetMinimapShape()` override for full third-party addon blip compatibility (Questie, Gatherer, TomTom, Cartographer).
- **Signature OneSuite Metal Styling**: Border and backdrop styled with Blizzard's silver metal dialog borders (`UI-DialogBox-Border`), marble/slate textures, and a dark top header bar.
- **Top Coordinates & Zone Header**:
  - Live player map coordinates displayed at the top right of the header bar (`XX.X, YY.X`).
  - Zone / subzone name displayed on the top left of the header bar, dynamically colored by PvP status (Sanctuary, Contested, Friendly, Hostile, Arena).
  - Left-click header to quickly open the World Map.
  - Hover tooltip displaying detailed subzone and PvP area info.
- **Mouse Wheel Zooming**: Scroll up to zoom in, scroll down to zoom out on the map.
- **Clutter-Free**: Suppresses standard Blizzard circular chrome (`MinimapBorder`, `MinimapZoomIn`, `MinimapZoomOut`, `MinimapToggleButton`, `MinimapZoneTextButton`).
- **Clean Button Docking**: Positions essential tracking, mail, calendar/time, and queue icons cleanly along the corners of the square frame.
- **Draggable with Position Memory**:
  - Drag the top header bar when unlocked to position the frame anywhere on screen.
  - Hold `Alt` and drag directly on the minimap to move.
  - Remembers frame position across reloads and sessions via `OneMiniMapDB`.

---

## 💻 Compatibility

- **Vanilla WoW 1.12.1**
- **Turtle WoW 1.16+ (Interface 16001)**
- **Wrath of the Lich King 3.3.5a**
- **Modern WoW (Retail / Classic)**

---

## ⌨️ Slash Commands

Use `/omm` or `/oneminimap`:

- `/omm lock` — Lock the minimap frame position.
- `/omm unlock` — Unlock the minimap frame (allows dragging).
- `/omm coords` — Toggle the top coordinates display on or off.
- `/omm scale <0.5 - 2.0>` — Adjust the overall minimap scale.
- `/omm reset` — Reset the minimap position back to the default top-right corner.
