# Changelog

## [v2.8] - 2026-06-25
### Changed
- **Dynamic Versioning**: Refactored `setup.sh` and the Flask backend (`app.py`, `index.html`) to dynamically extract and display the central `${SCRIPT_VERSION}` variable instead of relying on hardcoded strings, ensuring visual consistency across all menus and the Web Panel.

## [v2.7] - 2026-06-25
### Fixed
- **Tailwind Rendering**: Fixed a critical bug where the main SPA interface lost styling by migrating `style.css` to a Jinja-injected template block, allowing the Tailwind CDN to correctly parse custom `@apply` directives.
- **Unified Aesthetics**: Rewrote the Setup Wizard (`wizard.html`), Deployment Stream (`stream.html`), and Login (`login.html`) pages using the Modern Panel's glassmorphism and animated components to ensure a seamless UI experience end-to-end.

### Changed
- **Terminal Consolidation**: Removed the redundant "View Installation Logs" option from the Web Panel Management CLI menu, strictly enforcing the new Log Center as the single source of truth.

## [v2.6] - 2026-06-25
### Added
- **Modern Panel UI**: Completely replaced the old web interface with a modern, animated Single-Page Application (SPA) designed with Vite, Tailwind CSS, and vanilla JS.
- **RESTful Integration**: Refactored the Flask backend (`app.py`) to inject dynamic JSON data (`window.APP_DATA`) seamlessly into the new frontend architecture.
- **Theme Engine**: Added Light, Dark, and Auto system theme support in the new panel.
- **Git Ignore Rules**: Added robust `.gitignore` file to ensure `Modern Panel` source and build artifacts stay out of version control.

### Changed
- Converted the Modern Panel source code from Persian RTL (`dir="rtl"`, `lang="fa"`) to fully translated English LTR.
- Repurposed the panel's default financial metrics (Transactions/Sales) to accurately reflect VPN logic (Data Usage, Network Latency, and OpenVPN Client connection logs).

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
