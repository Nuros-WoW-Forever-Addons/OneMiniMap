# AI Context & Living Specification — OneMiniMap

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OneMiniMap
- **Current Version**: 0.4.0
- **Suite**: Part of the **OneSuite** family
- **GitHub Repository**:
  - Exists: TRUE
  - URL: https://github.com/Nuros-WoW-Forever-Addons/OneMiniMap
  *(For any new addon, initialize with Exists: FALSE until first commit/push)*
- **Branching Policy**: All new features must be developed on a branch != `main` (e.g. `feature/<name>`)
- **Live Sync Path**: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/OneMiniMap/`
- **Rollback Target**: Last working `main` branch commit
- **Release Package**: `.github/workflows/package.yml` generates `OneMiniMap-latest.zip` on push to `main`
- **Target WoW Runtimes**: WoW Forever Beta (v1.60.1 / Interface 16001)
- **Primary Goal**: Deliver a modern square minimap with signature OneSuite silver metal dialog aesthetics, clean independent title/clock/coordinate modules, button consolidation, and zero circular chrome remnants.

---

## 🏗️ Architecture & Component Map

### File Structure
- `OneMiniMap.toc`: Addon manifest, load order, SavedVariables declaration (`OneMiniMapDB`), optional dependencies (`OnePanelUtils`, `OneSwatter`).
- `Core.lua`: Square mask application, chrome hiding routines, title bar frame, draggable clock frame, throttled coordinates poller, zoom scroll handlers, position persistence, and slash commands (`/omm`, `/oneminimap`).
- `ButtonCollector.lua`: Scanning and reparenting engine for third-party and native minimap buttons into an organized floating drawer tray.
- `OptionsUI.lua`: Graphical configuration settings panel with position reset and display toggles.

### Global State & Database Schema (`OneMiniMapDB`)
```lua
OneMiniMapDB = {
    locked = false,                    -- Global drag lock
    showTitle = true,                  -- Show zone title frame
    showClock = true,                  -- Show independent clock frame
    useServerTime = false,             -- 24h / Local vs Server time
    showCoords = true,                 -- Show player coordinates frame
    buttonCols = 1,                    -- Number of button collector columns
    buttonGrowUp = false,              -- Button collector growth direction (false = down, true = up)
    scale = 1.0,                       -- Minimap scale (0.5 to 2.0)
    mapPosition = nil,                 -- Saved Minimap anchor table
    titlePosition = nil,               -- Saved Title bar anchor table
    clockPosition = nil,               -- Saved Clock frame anchor table
    coordPosition = nil,               -- Saved Coordinates frame anchor table
    buttonCollectorPosition = nil,     -- Saved Button tray anchor table
}
```

---

## 🔄 AI Development Cycle & Handoff Protocol

When picking up development on this addon:

1. **Orientation**: Read `CONTEXT.md` (this file) to verify current state, known issues, and active backlog items.
2. **Implementation**: Execute changes. For code refactoring or boilerplate, delegate to `qwen2.5-coder:32b` via the local `gx10_ollama` MCP server as mandated by user rules.
3. **Verification**: Verify in-game syntax and test using `/omm` commands.
4. **Handoff Update**:
   - Move completed tasks from **Upcoming Backlog** to **Recent Completed Work**.
   - If user-facing features or commands changed, update `README.md` and append a new section in `CHANGELOG.md`.
   - Document newly discovered backlog items or edge cases in **Upcoming Backlog**.

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 0.4.0
- Added Button Collector Growth Direction option (`OneMiniMapDB.buttonGrowUp`):
  - **Grow Downward**: Header grip at top, buttons stack downward, frame anchored by TOP edge.
  - **Grow Upward**: Header grip at bottom, buttons stack upward, frame anchored by BOTTOM edge.
- Added "Grow Buttons Upward (Unchecked: Grow Downward)" checkbox to `/omm` Options UI.
- Added `/omm grow` slash command to quickly toggle growth direction.
- Dynamic anchor translation ensures the Button Collector bar does not jump across screen upon toggling.
- Full 16-slot drag preview and button repositioning accurately previews upward/downward footprint.

### Spin 0.3.9
- Hardened Blizzard `Layout` and `MarkDirty` safety mocks across `hiddenFrame`, `MinimapCluster`, and mail button parents to eliminate `UPDATE_PENDING_MAIL` nil crashes.

### Spin 0.3.8
- Initial square mask texture implementation with automatic `GetMinimapShape` override.
- Decoupled frameless title bar, clock, and coordinate readouts into independently draggable modules.
- Added mouse wheel zoom and button collector tray.

---

## 📋 Living Roadmap & Upcoming Backlog (Next Spins)

### Priority 1: High Priority (Immediate Next Spin)
- [ ] **OneSwatter Logging Integration**: Route debug events through `_G.OneSwatter:LogDebug("OneMiniMap", ...)` when OneSwatter is present.
- [ ] **Dungeon / Subzone Difficulty Badge**: Render heroic/mythic dungeon skull badge cleanly in the square frame corner.

### Priority 2: Medium Priority (Enhancements)
- [ ] **Button Collector Auto-Collapse**: Option to automatically collapse the button tray when mouse leaves the minimap area.
- [ ] **Custom Border Color Tinting**: Allow optional accent tinting for the metal dialog border.

### Priority 3: Low Priority / Exploration
- [ ] **Ping Indicator Animation**: Add high-contrast glowing beacon animation when party/raid members ping the minimap.

---

## 🧪 Testing & Verification Guide

- **Verify Drag**: Type `/omm unlock`. Drag the Minimap, Clock, Title bar, and Coordinates to new positions. Reload (`/reload`) and confirm all 4 frames remember their spots.
- **Button Tray**: Type `/omm test` to inject test buttons into the collector. Verify row/column wrapping.
- **Zone Change**: Teleport or cross zone boundaries. Confirm title bar text and PvP color update instantly without lag.

---

## ⚠️ Technical Constraints & Engine Gotchas

- **Third-Party Blip Math**: Addons like Questie and Gatherer query `GetMinimapShape()`. Never return `"ROUND"`; always return `"SQUARE"` so icons don't bunch into a circle along the edges of the square frame.
- **Minimap Cluster Taint**: In Modern WoW, touching `MinimapCluster` can taint the ObjectiveTracker. Re-parent elements cleanly to custom standalone frames.
