<div align="center">

# 🧰 BlueFalcon Ultimate Toolkit

**The fast, safe, and modular way to prepare, route, and manage a fresh Linux server.**

![Version](https://img.shields.io/badge/Version-v1.0-blue?style=for-the-badge)
![Linux](https://img.shields.io/badge/Platform-Debian%20%7C%20Ubuntu-FCC624?style=for-the-badge&logo=linux&logoColor=black)
[![Language](https://img.shields.io/badge/Written%20in-Shell/Python-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)
[![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/@BlueFalcon2270)

<br />
</div>

An all-in-one, automated deployment toolkit designed to completely set up a fresh Linux server. Built on a clean, scalable architecture, it handles everything from initial security and utility installations to advanced Cloudflare WARP routing, and features a universal web dashboard for one-click VPN management.

<br>

## ⚡ Quick Run
Run this single command with root privileges on your fresh VPS. It acts as an intelligent bootstrapper, safely handling fresh installations as well as pulling the latest updates without merge conflicts:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/bluefalcon2270/bluefalcon-ultimate-toolkit/main/install.sh)
```

Once installed, simply type `bf-ui` from anywhere in your terminal to instantly launch the master control panel!

<br>

## 🏗️ System Architecture
The toolkit is structured for maximum maintainability and protocol independence:

* **Universal Web Panel (`/panel`):** The Flask-based MVC web dashboard sits entirely in the root directory. This ensures it remains strictly independent of any single VPN protocol (like OpenVPN), allowing easy expansion for future protocols like WireGuard or Xray.
* **Centralized Utilities (`/modules/essential_tools.sh`):** Core dependencies and advanced environments like Docker are treated as standard packages within the core utility deployment, streamlining the setup process into one highly efficient module.
* **Isolated VPN Engines (`/vpn-scripts`):** Backend execution scripts are categorized by protocol, ensuring easy debugging and safe updates without cross-contamination.

<br>

## 🌟 Features

### 1️⃣ Essential Tools
* **Update System:** Run standard package updates non-interactively.
* **System Packages:** Installs a critical checklist of packages (`nano`, `curl`, `git`, `htop`, `ufw`, `iptables`, and the complete `docker-ce` engine & compose plugins).
* **SSH Settings:** Change your SSH port, root password, and securely toggle password vs. key logins directly from a status dashboard.

### 2️⃣ Universal Web Panel & OpenVPN
* **Live Dashboards:** Monitor your server's live health (CPU, RAM, Disk, Network) with real-time dynamic graphs.
* **Protocol Execution:** Currently ships with the OpenVPN engine for automated deployment, traffic tracking, and automated profile generation. 
* **One-Click Controls:** Pause/resume users, set expiry dates, and download mobile/desktop profiles instantly.

### 3️⃣ Cloudflare WARP
* **Dual-Stack Routing:** Hide your server's true IP and bypass restrictions by routing IPv4 and/or IPv6 traffic through Cloudflare's WireGuard network (`wgcf`).
* **WARP+ Support:** Upgrade your connection instantly using a premium license key.
* **Modern Dashboard:** Displays active connection statuses, server IPs, and WARP masking IPs via modern routing cards in the web panel.

<br>

## ✅ Supported Systems
| Distribution | Compatibility |
| :--- | :---: |
| **Ubuntu** (22.04, 24.04) | ✅ |
| **Debian** (11, 12, 13) | ✅ |

<br>

---
**Watch the Tutorial:** I use this exact toolkit in my YouTube tutorials to ensure viewers have a standardized, error-free environment before we dive into advanced server deployments. Subscribe at [@BlueFalcon2270](https://www.youtube.com/@BlueFalcon2270).