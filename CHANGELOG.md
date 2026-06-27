VERSION="3.3"

# Changelog

## [v3.3] - 2026-06-28
### Changed
- **System Tools**: Redesigned page with tabs (Update System, System Packages, SSH Settings). Each tab has its own context and the permanent terminal is present in applicable tabs.
- **Backup/Restore**: Moved from System Tools to a dedicated tab inside Preferences.
- **SSH Settings**: Added toggle switches for Password Auth and Pubkey Auth directly from the web panel.
- **Terminal Command**: Renamed the CLI shortcut from `bf-ui` to `bfp` for faster access.

## [v3.2] - 2026-06-28
### Added
- **System Tools (Phase 1)**: Migrated 'Essentials' and 'Backup/Restore' from the CLI to a new dedicated Web Panel tab.
- **Backup Vault**: Users can now create, restore, download, and delete full system backups directly from the web interface.
- **Permanent System Terminal**: Added a permanently visible background terminal to execute system updates and restorations in real-time.

## [v3.1] - 2026-06-28
### Added
- **WARP Persistent Terminal**: The WARP installation process now runs in a background thread and logs to `/tmp/warp_install.log`. The frontend uses a collapsible terminal that resumes polling even after a page reload.
### Changed
- **OpenVPN UI Tweaks**: Removed literal placeholders from the Add User form, shortened 'Max Users', and simplified table headers.
- **WARP IP Logic**: Applied Single Green Circle rule: True Server IP gets green when OFF, WARP IP gets green when ON. Inactive WARP IP displays as `Offline`.

## [v3.0] - 2026-06-27
### Fixed
- **OpenVPN Layout Typo**: Corrected 'Sim...Users:' summary text to display 'Simultaneous Users:'.
- **WARP UI States**: Fixed the active/inactive circle colors and conditional rendering. True Server IPs now properly always display as active (green). Uninstalled WARP now displays a clean placeholder instead of unmasked IPs.
- **Engine Controls Theme**: Manually mapped the Start/Stop buttons to perfectly match the requested light-pastel mockup styling, overriding global dark mode.

## [v2.9] - 2026-06-27
### Fixed
- **Version Display Bug**: Fixed path resolution in `app.py` so the About tab dynamically reads the current version.
### Changed
- **WARP UI**: Realigned True Server IP and WARP IP with perfectly centered text and right-aligned status circles. Removed top color bars.
- **OpenVPN UI**: Redesigned structure based on user mockup (Settings banner, inline "Add User" horizontal form, and dark-theme clients table).

## [v2.8] - 2026-06-26
### Added
- `.agents` directory to `.gitignore` to prevent leaking local AI context.

## [v2.7] - 2026-06-26
### Added
- **UI Overhaul**: Complete UI overhaul for WARP, OpenVPN, and Preferences tabs.
- **Server Configuration**: Added Server Name configuration in Preferences.

## [v2.6] - 2026-06-26
### Added
- **Unified Preferences Page**: Combined Settings and Logs into a unified 'Preferences' page with an 'About' tab.
- **Centralized Versioning**: Project version is now centrally defined in `CHANGELOG.md` and read by all Bash and Python scripts.
- **`.gitignore`**: Added strict ignoring for `panel.db`, log files, and Python cache.
- **CLI Logging Enhancement**: All main CLI scripts now output the Toolkit version dynamically on launch.

### Changed
- **Web Panel Sidebar**: Removed categorized groupings and renamed the header to a stylized 'BF Panel'.
- **Panel CLI Menu**: Removed redundant 'View Installation Logs' option to centralize all logging to the unified Log Center.

## [v2.5] - 2026-06-25
### Added
- **Hybrid Log Center**: Introduced a comprehensive centralized logging system supporting 9 different log feeds.
- **Unified Master Stream**: Added a new chronological interleaved log feed covering Web Panel, OpenVPN, and WARP outputs.
- **Backup & Restore Module**: Integrated a new module for archiving and restoring VPN configs and Web Panel database.

### Changed
- **CLI Sub-menus**: Removed redundant log viewing options from OpenVPN, WARP, and Web Panel modules, deferring logging to the new Log Center.
- **CLI Main Menu**: Reordered items logically according to importance (Web Panel, OpenVPN, WARP, Essentials, Backup/Restore, Logs).
- **Web Panel Dashboard**: Integrated Chart.js for real-time network traffic visualization.
- **Web Panel Sidebar**: Grouped items logically under 'Overview', 'Network Services', and 'Administration'.
- **Web Panel OpenVPN UI**: Relocated the user provisioning form into a sleek Floating Action Button (FAB) and modal.
- **Web Panel Logs UI**: Replaced horizontal tabs with a modern dropdown selector.

### Security
- **Subprocess Hardening**: Migrated user script executions in `app.py` from `os.system` to `subprocess.run` to mitigate shell injection.
- **Input Sanitization**: Implemented strict stripping of newlines and quotes for DNS input fields to prevent config corruption.
- **Exception Handling**: Improved `get_traffic()` to gracefully catch `FileNotFoundError` and `PermissionError`.
