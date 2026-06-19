#!/usr/bin/env bash

# ==============================================================================
# BlueFalcon Bootstrapper
# ==============================================================================

echo "🦅 Initializing BlueFalcon Ultimate Toolkit..."

# 1. Silently install dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get update -y > /dev/null 2>&1
apt-get install git curl wget -y > /dev/null 2>&1

# 2. Prevent Git merge conflicts by wiping the old codebase (data is safe in /etc/ and panel.db)
rm -rf /opt/bluefalcon-ultimate-toolkit

# 3. Pull the fresh modular repository
git clone -q https://github.com/bluefalcon2270/bluefalcon-ultimate-toolkit.git /opt/bluefalcon-ultimate-toolkit

# 4. Execute the main God Script
cd /opt/bluefalcon-ultimate-toolkit
chmod +x setup.sh
./setup.sh