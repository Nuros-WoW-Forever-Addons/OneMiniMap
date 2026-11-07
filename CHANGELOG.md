# Changelog — OneMiniMap

All notable changes to **OneMiniMap** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.5.1] - 2026-11-06
### Added
- **Dedicated "OneAddon" Chat Tab**: Added automatic chat tab creation and message routing (`OneMiniMapDB.routeToOneAddonTab`, defaults to `true`).
  - At load, checks all chat windows for a tab named `"OneAddon"`. If missing, creates and docks one to the main chat frame and clears noisy game channels (General, Trade, monster spam).
  - Routes all initialization, configuration feedback, and slash command output to this clean tab so General Chat is never spammed.
  - Gracefully falls back to General Chat (`DEFAULT_CHAT_FRAME`) if the tab is closed or if the user disables routing.
- **Options UI Checkbox**: Added "Route Addon Messages to 'OneAddon' Chat Tab" setting in the `/omm` options window.
- **Slash Commands**: Added `/omm chat` (or `/omm tab`) to quickly toggle message routing between the `"OneAddon"` tab and General Chat.

## [0.5.0] - 2026-11-06
### Added
- **Horizontal Column Growth Option**: Added "Grow Columns to the Left (Unchecked: Grow Right)" setting (`OneMiniMapDB.growLeft`, defaults to `true`).
  - **Grow Left** (default): Primary column 1 (buttons 1–8) stays on the right edge, while column 2 (buttons 9–16) expands to the left. Ideal when docked to the left of the minimap.
  - **Grow Right**: Primary column 1 (buttons 1–8) stays on the left edge, while column 2 (buttons 9–16) expands to the right.
- **Slash Commands**: Added `/omm growleft` (aliases `/omm grow`, `/omm columngrow`) to toggle horizontal column growth.

### Changed & Fixed
- **Permanent Top-Anchoring**: The 3-dot grip header (`•••`) is now fixed permanently at the top of the button collector panel. Buttons always stack from top to bottom (button 1 below the header, then button 2, etc.), and the panel always grows downward.
- **Fixed Drag Repositioning & Size Jump Bug**: Fixed an issue where releasing the drag handle or clicking to move caused the top of the panel to jump or drop due to Blizzard's internal `BOTTOMLEFT` drag coordinates. The frame now captures `GetTop()` and its horizontal anchor immediately before closing the drag preview and explicitly anchors to `TOPRIGHT` or `TOPLEFT`, ensuring the 3-dot bar stays exactly where placed and preview expansion only extends downward.
- **Cleaned Up Deprecated Settings**: Replaced `buttonGrowUp` with `growLeft` and automatically purged legacy bottom-anchored coordinates so the collector defaults flush to the top edge of the minimap.

## [0.4.0] - 2026-11-06
### Added
- **Button Collector Growth Direction**: Added option to configure the Button Collector to grow Down vs Up (`OneMiniMapDB.buttonGrowUp`).
  - **Grow Downward** (default): Header grip is at the top, buttons stack downward, and the frame anchors from the top edge.
  - **Grow Upward**: Header grip is at the bottom, buttons stack upward, and the frame anchors from the bottom edge.
- **Options UI Checkbox**: Added "Grow Buttons Upward (Unchecked: Grow Downward)" setting in the `/omm` configuration window.
- **Slash Command**: Added `/omm grow` (aliases `/omm growth`, `/omm growdir`) to quickly toggle between Downward and Upward growth.
- **Dynamic Anchor Conversion**: Smooth coordinate translation when toggling growth directions so the bar remains anchored stably without jumping.

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
