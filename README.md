<div align="center">

# 🧰 BlueFalcon Ultimate Toolkit

**The fast, safe, and modular way to prepare, route, and manage a fresh Linux server.**

![Version](https://img.shields.io/badge/Version-v2.0-blue?style=for-the-badge)
![Linux](https://img.shields.io/badge/Platform-Debian%20%7C%20Ubuntu-FCC624?style=for-the-badge&logo=linux&logoColor=black)
[![Language](https://img.shields.io/badge/Written%20in-Shell/Python-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)]([https://www.gnu.org/software/bash/](https://www.gnu.org/software/bash/))
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)
[![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/@BlueFalcon2270)

<br />
</div>

An all-in-one, automated deployment toolkit designed to completely set up a fresh Linux server. Built on a clean, scalable architecture, it handles everything from initial security and utility installations to advanced Cloudflare WARP routing, and features a Google Material Design 3 web dashboard for one-click VPN management.

<br>

## ⚡ Quick Run
Run this single command with root privileges on your fresh VPS. It acts as an intelligent bootstrapper, safely handling fresh installations as well as pulling the latest updates without merge conflicts:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/bluefalcon2270/bluefalcon-ultimate-toolkit/main/install.sh)
```

**Global Shortcut:** Once installed, simply type `bf-ui` from anywhere in your terminal to instantly launch the master control panel!

<br>

## 🏗️ System Architecture
The toolkit is structured for maximum maintainability and professional scaling:

* **Material Design Web UI (`/panel`):** A Flask-based MVC web dashboard fully rewritten using Google Material Design 3. Features a persistent left-navigation sidebar, separating routing, management, and system logs into dedicated views.
* **Centralized Utilities (`/modules/essential_tools.sh`):** Core dependencies and advanced environments like Docker are treated as standard packages within the core utility deployment.
* **Isolated VPN Engines (`/vpn-scripts`):** Backend execution scripts are categorized by protocol, ensuring easy debugging and safe updates without cross-contamination.

<br>

## 🌟 Features

### 1️⃣ System Essentials
* **Update System:** Run standard package updates non-interactively.
* **System Packages:** Installs a critical checklist of packages (`nano`, `curl`, `git`, `htop`, `ufw`, `iptables`, and the complete `docker-ce` engine & compose plugins).
* **SSH Settings:** Change your SSH port, root password, and securely toggle password vs. key logins directly from a status dashboard.

### 2️⃣ Master Web Panel & Initialization
* **Unified Setup Wizard:** Configure your OpenVPN engine, panel credentials, and WARP endpoints from a single, centralized web setup page.
* **Live SSE Streaming:** Watch background deployment scripts execute in real-time directly inside your browser.
* **Centralized Log Center:** Read `journalctl` outputs for OpenVPN, WARP, and System services directly from the web browser without SSHing into the server.

### 3️⃣ OpenVPN Management
* **Terminal & Web Sync:** Create, pause, and revoke users directly from the terminal, with all changes instantly reflected in the Web Panel database.
* **Live Dashboards:** Monitor your server's live health (CPU, RAM, Disk, Network) with real-time dynamic, AWS-style progress bars.
* **Automated Profiles:** Download mobile/desktop profiles instantly.

### 4️⃣ Cloudflare WARP
* **Dual-Stack Routing:** Hide your server's true IP and bypass restrictions by routing IPv4 and/or IPv6 traffic through Cloudflare's WireGuard network (`wgcf`).
* **WARP+ Support:** Upgrade your connection instantly using a premium license key.
* **Intelligent Network Bypassing:** OpenVPN config generators are hardcoded to bypass the WARP tunnel, ensuring your VPN files are always mapped to your true physical server IP.

<br>

## ✅ Supported Systems
| Distribution | Compatibility |
| :--- | :---: |
| **Ubuntu** (22.04, 24.04) | ✅ |
| **Debian** (11, 12, 13) | ✅ |

<br>

---
**Watch the Tutorial:** I use this exact toolkit in my YouTube tutorials to ensure viewers have a standardized, error-free environment before we dive into advanced server deployments. Subscribe at [@BlueFalcon2270](https://www.youtube.com/@BlueFalcon2270).