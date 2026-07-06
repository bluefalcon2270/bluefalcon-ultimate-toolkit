VERSION="8.1"

# Changelog

## [v8.1] - 2026-07-06
### Fixed
- OpenVPN CLI: Added the ability to install OpenVPN directly from the terminal CLI even before the Web Panel is configured.
- WARP Core: Implemented robust retry loops for Cloudflare `wgcf` registration and configuration generation to handle API timeouts and rate limits, preventing "warp not installed" errors.

## [v8.0] - 2026-07-06
### Added
- Resizable Global Deployment Terminal: Added a vertical drag handle so the user can easily adjust the terminal drawer height.
- Intelligent Auto-Refresh: Terminal now seamlessly reloads the page only when an installation successfully completes, eliminating the hard-coded timeout glitch.

## [v7.9] - 2026-07-06
### Added
- Unified Global Deployment Terminal in dashboard footer.
- Separation of WARP (wgcf) interface from WireGuard (wg) for accurate traffic stats.
- 4-column dashboard layout separating Live Speed and Total Usage, with Download/Upload.

## [v7.8] - 2026-07-06
### Changed
- **Client List Layouts**: Overhauled the OpenVPN and WireGuard client lists to closely mirror the Sanaie UI style. Client names and IDs are now elegantly stacked, pause/resume actions have been converted into modern iOS-style toggle switches, status indicators use clean colored-dot badges, and action buttons have been consolidated.
- **Config Downloads**: Removed the redundant "Manual" OpenVPN download button. All config downloads (OpenVPN and WireGuard) now strictly follow the intuitive `ServerName - ClientName` file naming convention.

## [v7.7] - 2026-07-06
### Added
- **Advanced Network Monitoring**: Transformed the Dashboard's "Overall Speed" into a 3-column Network Overview grid displaying Global Edge, OpenVPN Tunnel, and WireGuard Tunnel traffic independently.
- **Per-User Live Speeds**: Upgraded the Active Clients table in both OpenVPN and WireGuard tabs to display real-time live Upload/Download speeds and Total Data usage for every individual connected user.

## [v7.6] - 2026-07-06
### Fixed
- **Network Stats Double Counting**: Fixed an issue where the Overall Speed and Total Data metrics were displaying roughly double the actual values. This was caused by `psutil` summing the traffic across all network interfaces, which resulted in VPN traffic being counted twice (once on the virtual `tun`/`wg` interface, and once on the physical `eth`/`ens` interface as encapsulated packets). The system now explicitly filters out virtual loopback and tunnel interfaces (`lo`, `tun`, `wg`, `docker`, etc.) to measure pure, raw edge-server traffic.

## [v7.5] - 2026-07-06
### Fixed
- **Dashboard Stats**: Fixed a bug where Swap, Storage, and Overall Speed were stuck at 0 due to a JavaScript error caused by removing unused UI elements. The metrics have been correctly remapped.
- **Traffic Reporting Perspective**: Swapped the Total Data (Sent/Received) values and Overall Speed logic to reflect the *client's perspective* based on global server traffic, rather than the server's perspective based on OpenVPN logs alone.
- **Refresh Rate**: Doubled the dashboard refresh rate from 2 seconds to 1 second to match the snappy feel of the Sanaie panel.

## [v7.4] - 2026-07-06
### Changed
- **UI Enhancements**: Restructured the Dashboard to only display the core resource rings, overall speed, and total data usage. Realigned the WireGuard page layout to match the clean, horizontal styling of the OpenVPN page. Client action buttons are now permanently visible rather than requiring a hover state.

## [v7.3] - 2026-07-06
### Fixed
- **Dashboard Crash**: Fixed another 500 Internal Server Error when accessing the web panel dashboard. The `url_for('system')` link was invalid because the actual underlying Python function for the system tools page is named `system_tools`, not `system`.

## [v7.2] - 2026-07-06
### Fixed
- **Dashboard Crash**: Fixed a 500 Internal Server Error when accessing the web panel dashboard. The Jinja `url_for('logs')` function was crashing the Flask router because the route had been renamed to `system` in a previous restructuring.

## [v7.1] - 2026-07-06
### Fixed
- **Mojibake & UTF-8 Encoding**: Fixed an issue where scripts were accidentally saved with a UTF-8 BOM, causing `/bin/bash` execution to break on Linux and converting the interactive terminal menu emojis (🧰, ✖, ✔) into unreadable garbage characters.
- **V7 Database Migration**: Fixed a bug introduced in v7.0 where fresh installations or updates would fail to launch the web panel because the `data/` folder didn't exist. The panel installer now properly creates `data/` and automatically migrates any legacy `panel.db` into the new v7 architecture.

## [v7.0] - 2026-07-06
### Changed
- **Massive Architectural Restructure**: Completely reorganized the underlying folder layout of the entire codebase to properly separate concerns and drastically improve maintainability.
  - Extracted all Web Panel files to be strictly contained within `panel/`.
  - Migrated the old terminal `modules/` into a dedicated `cli/` directory.
  - Consolidated all backend VPN generation scripts (formerly `vpn-scripts/`) directly into the `core/` engine folder so both the terminal UI and Web Panel pull from one unified source.
  - Moved the `panel.db` SQLite database out of the root directory and into a dedicated `data/` folder.
  - Executed a codebase-wide string replacement, updating over 30+ internal hardcoded paths across Python and Bash scripts to successfully link the new architecture together.

## [v6.3] - 2026-07-06
### Changed
- **Dashboard Aesthetic Overhaul**: Completely redesigned the Web Panel dashboard to match the deeply aesthetic, dark-themed Sanaie (3X-UI) visual style. Replaced horizontal progress bars with animated SVG circular rings and introduced a dense 2-column metrics grid.
- **Enhanced Telemetry**: Expanded the `/api/sysinfo` backend API to supply Swap Memory, OS Uptime, Thread Counts, and active TCP/UDP connections to feed the new dashboard layout. Removed the intrusive Unified Network Manager WARP banner to preserve the aesthetic.

## [v6.2] - 2026-07-06
### Fixed
- **VPN Script Failures**: Fixed a critical issue in `openvpn/add_user.sh`, `wireguard/core_setup.sh`, and `wireguard/add_user.sh` where `curl ifconfig.me` would crash the script under strict `set -e` mode if the external service was unreachable. Added robust fallback mechanisms (`|| echo "127.0.0.1"`) to prevent abrupt terminations and configuration corruption.
- **Removed Setup Hacks**: Removed dirty Python-based `sed` script replacements in `app.py` that were attempting to patch `curl` logic across all scripts. The correct interface-bound curl logic is now natively embedded in the bash scripts.

## [v6.1] - 2026-07-06
### Fixed
- **SSH Port Update Bug**: Fixed an issue where changing the SSH port failed to apply if the `Port` directive in `/etc/ssh/sshd_config` contained spaces or was completely missing. The backend now robustly updates or appends the port and automatically opens the new port in UFW/iptables before restarting `sshd` to prevent accidental lockouts.
- **Seamless Panel Port Transition**: Replaced the instant HTTP redirect when changing the panel port with a styled "Applying New Port" HTML transition screen. This screen waits 5 seconds to gracefully redirect the browser only *after* the panel has successfully rebooted on the new port, eliminating the broken "Connection Refused" page.

## [v6.0] - 2026-07-06
### Fixed
- **Panel Port Changes**: Fixed an issue where changing the panel port in the initial wizard or in the panel settings failed to update the underlying service. Port updates will now correctly modify the `systemd` service using regex replacement, apply the appropriate UFW/iptables rules, and dynamically redirect the user's browser to the new port address without returning a connection error.

## [v5.9] - 2026-07-02
### Fixed
- **WARP Toggle**: Fixed an unbound variable error (`$1: unbound variable`) in `core/warp/action.sh` when the script is sourced without arguments during WARP toggle operations.

## [v5.8] - 2026-07-02
### Fixed
- **SSH Disconnection**: Fixed a critical bug introduced during modularization (v5.4+) where sourcing the `action.sh` file internally overwrote the `TARGET` variable with the `LICENSE` string. This caused the VPS's anti-lockout routing rules (`PostUp` and `PreUp`) to be completely bypassed, forcing all VPS traffic—including SSH connections—through WARP, instantly dropping the user's connection during "Building Configuration".

## [v5.7] - 2026-07-02
### Fixed
- **Terminal Hanging**: Fixed a deep technical issue where the `wgcf generate` binary would indefinitely hang in the background when running from the terminal menu. The Go-based binary was attempting to probe the interactive TTY session (even when there was no prompt to display), which caused the Linux kernel to suspend it via a `SIGTTIN` signal. It is now safely detached using `setsid` and wrapped with timeouts to guarantee the installation never stalls.

## [v5.6] - 2026-07-02
### Fixed
- **Configuration Hanging**: Fixed an issue where running the WARP installation while a WARP profile already existed would cause the terminal installation to hang permanently at "Building Configuration". The `wgcf generate` command was silently waiting for user confirmation to overwrite the existing profile.

## [v5.5] - 2026-07-02
### Fixed
- **Terminal Menu Freezing**: Fixed a bug introduced in v5.4 where the terminal would appear frozen and blank when installing or uninstalling WARP. The loading spinner's visual output was accidentally being redirected into the log file rather than the terminal screen.

## [v5.4] - 2026-07-02
### Fixed
- **Terminal UI Granularity**: Restored the granular, multi-step loading spinners for the WARP installation process in the terminal menu that were temporarily removed during the architectural unification. Refactored the core `action.sh` script to be modular, allowing the terminal to execute and display visual spinners for each individual step (Prerequisites, Profile Registration, Configuration) while still maintaining a single shared codebase with the web panel.

## [v5.3] - 2026-07-02
### Fixed
- **WARP Incoming Connection Timeout**: Added `rp_filter=2` (loose reverse path filtering) to sysctl during WARP installation. This permanently fixes a kernel bug where incoming connections to the VPS (like Let's Encrypt SSL validation on port 80 or 3x-ui panel access) would be falsely flagged as spoofed martians and dropped while the `0.0.0.0/0` WARP route was active.

## [v5.2] - 2026-07-02
### Changed
- **Architectural Unification**: Refactored the terminal and web panel backends to use a single source of truth. Eliminated massively duplicated WARP installation code in `warp_manager.sh`, replacing it with a direct invocation of the web panel's `action.sh` script. Removed confusing file copying logic from `panel_manager.sh` and updated `app.py` and `openvpn_manager.sh` to natively point to the `core` directory. This permanently resolves drift bugs across the codebase.

## [v5.1] - 2026-07-02
### Changed
- **Terminal WARP Installer Synchronization**: Eradicated the outdated `cloudflare-warp` desktop daemon installation logic from the terminal installer (`modules/warp_manager.sh`). The terminal now perfectly matches the web panel's lightweight `wgcf` engine. This drops the terminal installation time from ~10 minutes down to 20 seconds. Also attached a loading spinner to the prerequisite installation so it no longer appears frozen.

## [v5.0] - 2026-07-02
### Fixed
- **WARP IPv6 Routing Crash**: Added conditional checks to the WireGuard configuration builder so that `ip -6 rule` PreUp/PostUp commands are only generated if the VPS actually possesses a public IPv6 address. This prevents a fatal `inet6 prefix is expected rather than "lookup"` error from crashing `wg-quick` on IPv4-only servers.

## [v4.9] - 2026-07-02
### Fixed
- **WARP DNS Resolution Fix**: Removed the explicit `DNS = 8.8.8.8...` line from the generated `wgcf.conf` payload to resolve a critical startup error (`dbus-org.freedesktop.resolve1.service not found`) on VPS distributions where `systemd-resolved` is missing or inactive. WARP will now correctly rely on the server's native DNS resolution over the tunnel.

## [v4.8] - 2026-06-30
### Fixed
- **IPv6 SLAAC Disablement Bug**: Fixed an extremely obscure Linux kernel quirk where enabling IPv6 forwarding (`net.ipv6.conf.all.forwarding=1`) automatically forces the server to drop all Router Advertisements (SLAAC) on reboot. This caused VPS providers with dynamic IPv6 allocations to permanently lose their native IPv6 route upon server restart. Hardcoded `accept_ra=2` in sysctl to force the kernel to maintain its native IPv6 configuration while simultaneously routing VPN traffic.

## [v4.7] - 2026-06-30
### Added
- **Dual-Stack Native IPv6 Tunneling**: Massively upgraded both OpenVPN and WireGuard routing engines to natively support IPv6 inside the VPN tunnels using Unique Local Address (ULA) subnets (`fd42::`). This permanently fixes IPv6 leaks on client devices and allows connected clients to utilize WARP's IPv6 routing seamlessly.
  - Added `ip6tables` NAT routing and `sysctl` IPv6 forwarding to all VPN installations.
  - Wireguard client generator now pushes `::/0` and statically assigns `fd42:42:42:43::/128` per user.
  - OpenVPN core setup now pushes `route-ipv6 2000::/3` and assigns a `server-ipv6 fd42:42:42:42::/112` topology.

## [v4.6] - 2026-06-30
### Fixed
- **True VPS IPv6 Detection**: Fixed an issue where the True VPS IPv6 address displayed as `N/A` on the WARP dashboard. The detection logic now strictly queries the `main` routing table rather than globally, preventing WARP's virtual interface from blinding the server to its native public interface.
- **Login Page UI Refinement**: Updated the login screen aesthetics for better clarity. Modified titles and properly contrasted the error banner using Tailwind classes (`bg-red-900/50 text-red-200`) so "Invalid Credentials" warnings are readable in dark mode. Also fixed a bug where the error banner displayed unconditionally on fresh page loads.
- **Bootstrapper Speed**: Added verbose logging to `install.sh` so the initial deployment no longer appears to hang while fetching core dependencies (`git`, `curl`, `wget`) on a fresh Ubuntu machine.

## [v4.5] - 2026-06-30
### Fixed
- **WARP Boot Sequence Bug**: Fixed a critical issue where WARP (`wg-quick@wgcf`) would initialize too early during the server boot sequence, causing DNS resolution and outgoing internet traffic to fail, effectively blackholing `bfu` and OpenVPN. Added an `@reboot` delayed start cron to ensure a clean initialization.
- **Preflight Internet Check**: Upgraded the `curl` internet connectivity check to bypass DNS resolution (`1.1.1.1`) to prevent false positives when WARP overrides `resolv.conf`.
- **Panel Internal Server Error**: Fixed a 500 crash in the Preferences tab caused by an unclosed database connection and an invalid `.get()` method call on a raw `sqlite3.Row` object.
- **Readonly Variable Crash**: Removed legacy `readonly APP_DIR` declarations across all module scripts that were crashing the `bfu` terminal command when sourced.

## [v4.4] - 2026-06-30
### Fixed
- **OpenVPN + WARP Routing Integrity**: Fixed a critical routing bug where OpenVPN failed to establish connections or drop packets when WARP was enabled.
  - Added `multihome` directive for UDP protocols so the OpenVPN server correctly replies from the original public interface instead of the WARP virtual interface.
  - Added `mssfix 1240` to clamp OpenVPN tunnel MTU below WARP's strict 1280 MTU, preventing MTU packet-loss blackholes.
  - Forced loose `rp_filter` (Reverse Path filtering) in sysctl to prevent the Linux kernel from dropping cross-routed packets natively.

## [v4.3] - 2026-06-29
### Changed
- **Unified Network Manager**: Completely overhauled the WARP installation script (`core/warp/action.sh`). Eradicated the official `cloudflare-warp` desktop daemon which was causing catastrophic routing conflicts and pulling in 662MB of GUI bloatware. Replaced it with pure `wgcf` + `wireguard-tools` policy routing.
- **Conflict Warning UI**: Added dynamic warning banners to the Web Panel dashboard. If WARP is running concurrently with OpenVPN or WireGuard, the dashboard actively informs the user that client outbound traffic is being bridged through Cloudflare.
- **Cross-Platform Compatibility**: Normalized all bash and python scripts to Linux (LF) line endings to fix `\r` crash bugs on fresh deployments. Added `.gitattributes` to enforce this behavior.
- **System Logs**: Fixed an issue where Ubuntu 24.04 nodes failed to load the authentication logs via `tail /var/log/auth.log`. Ported the logic to `journalctl -u ssh.service`.
- **Preflight Checks**: Replaced brittle ICMP `ping` checks with HTTPS `curl` checks to ensure compatibility with strict cloud provider firewalls (AWS, Oracle, etc).

## [v4.2] - 2026-06-29
### Fixed
- **WARP Client Revert**: Restored the exact `cloudflare-warp` installation behavior from `v4.0`. Removed the `--no-install-recommends` flag, as Cloudflare's proprietary client silently relies on some of those "recommended" dependencies (like `systemd-resolved` or `glib` networking tools) to establish its tunnel correctly.

## [v4.1] - 2026-06-29
### Fixed
- **WARP Bloatware Installation**: Added `--no-install-recommends` to the Cloudflare WARP client installation script. This prevents the server from unnecessarily downloading and installing over 600MB of useless graphical desktop environments and GUI libraries on a headless VPS.

## [v4.0] - 2026-06-29
### Changed
- **Terminal Shortcut**: Renamed the global terminal shortcut back to `bfu` (BlueFalcon Ultimate) per user request.

## [v3.9.1] - 2026-06-29
### Fixed
- **Panel Access Blocked via UFW**: Fixed an issue where installing OpenVPN or WARP would reload UFW and accidentally block the Web Panel port (2020).
- **Wizard Redirect Loop**: Fixed a bug where restarting the server with only one protocol installed would mistakenly trigger the Setup Wizard due to a flawed database check.

## [v3.9] - 2026-06-29
### Fixed
- **Server Name Display**: Fixed bug where the panel would always display "openvpn" as the server name. Added a dedicated `display_name` column to allow custom node names while keeping protocol identifiers intact.
- **Install State Persistence**: Fixed bug where running an install from the dashboard tabs wouldn't properly update the `is_installed` status upon completion, leaving the UI stuck in the "Not Installed" state.

## [v3.8] - 2026-06-28
### Fixed
- **WireGuard Panel (Critical)**: Fixed `Internal Server Error` caused by calling `get_db_connection()` which doesn't exist — all calls now correctly use `get_db()`.
- **OpenVPN Install (Critical)**: Same undefined function fix for the `/api/openvpn_stream` and `/api/add_wg_user` routes.
- **OpenVPN & WireGuard "Not Installed" UI**: Completely redesigned to match the WARP page — full-width card with persistent, large terminal always visible on screen. Terminal shows live log as soon as you click Install.
- **Auto-resume polling**: If you navigate away and come back while an install is running, the terminal will automatically resume showing the live log.

## [v3.7] - 2026-06-28
### Added
- **Wizard Redesign**: The deployment wizard has been completely redesigned. It now features sleek collapsible boxes for OpenVPN, WireGuard, and WARP, with modern toggle switches (defaulting to OFF).
- **Modular OpenVPN**: OpenVPN is no longer forced to install during the initial setup wizard. It can be skipped and installed later directly from the Web Panel, matching the behavior of WireGuard and WARP.

## [v3.6] - 2026-06-28
### Added
- **WireGuard Protocol**: Added full support for WireGuard.
  - **CLI Menu**: Manage WireGuard installation, port selection, and users via `bfp`.
  - **Web Panel**: A new dedicated WireGuard tab featuring installation streams, custom port selection, user management, `.conf` downloads, and live QR code generation for mobile devices.

## [v3.5] - 2026-06-28
### Fixed
- **System Packages**: Docker Engine and Docker Compose are now correctly installed via the "Install Missing" button. Previously, it skipped the Docker repository setup.
- **Terminal Formatting**: The system update and package installation terminal logs now perfectly mirror the CLI menu's exact text layout and hide raw `apt` output during package installation.

## [v3.4] - 2026-06-28
### Added
- **ANSI Color Rendering**: All terminal outputs (System Tools, WARP, Backup) now render colored output identical to the CLI menu — bold blue headers, green checkmarks, red errors.
- **Auto-scroll Toggle**: Every terminal in the panel now has a green toggle switch. When ON, the terminal auto-scrolls to the newest line. When OFF, you can freely scroll to read previous output without being interrupted.
- **Styled Scrollbar**: All terminals now have a thin, dark-styled scrollbar that is always visible.
- **`install_packages` action**: System Packages tab now installs all missing packages via the live terminal.

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
- **`.gitignore`**: Added strict ignoring for `data/panel.db`, log files, and Python cache.
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
