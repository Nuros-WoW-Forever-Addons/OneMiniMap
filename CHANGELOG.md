# Changelog — OneMiniMap

All notable changes to **OneMiniMap** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.3.9] - 2026-10-11
### Fixed
- **Blizzard Layout Compatibility**: Added safe `.Layout` and `.MarkDirty` mock implementations to `hiddenFrame`, `MinimapCluster`, and `mailBtn:GetParent()`, preventing `attempt to call a nil value` exceptions from Blizzard's `MiniMapMailFrameMixin:OnEvent` during `UPDATE_PENDING_MAIL` events.

## [0.3.8] - 2026-10-10
### Added
- **Square MiniMap Engine**: Converted circular minimap to high-performance square geometry using `WHITE8X8` mask texture rendering.
- **`GetMinimapShape` Override**: Automatic override ensuring third-party addon blips (Questie, Gatherer, TomTom, Cartographer) track along square perimeters.
- **Separate Frameless Title Bar**: Zone/subzone name display with dynamic PvP territory coloring (Sanctuary, Contested, Friendly, Hostile, Arena), World Map click trigger, and detailed zone tooltip.
- **Draggable Clock Frame**: Independently positionable clock with 12/24 hour toggle and Local vs. Server time support (`/omm time`).
- **Draggable Coordinates Frame**: Real-time player coordinate readout with throttled (0.15s) cross-client position polling.
- **Button Collector Drawer**: Integrated docking system collecting addon minimap icons into a tidy expandable tray.
- **Mouse Wheel Zooming**: Direct mouse wheel scroll zoom-in / zoom-out on the minimap frame.
- **Authentic OneSuite Metal Borders**: Wrapped in signature `UI-DialogBox-Border` silver metal bevels with dark slate backdrops.
