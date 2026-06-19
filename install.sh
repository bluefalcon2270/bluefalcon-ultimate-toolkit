#!/usr/bin/env bash

# ==============================================================================
# BlueFalcon Bootstrapper
# ==============================================================================

echo "🦅 Initializing BlueFalcon Ultimate Toolkit..."

# 1. Silently install dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get update -y > /dev/null 2>&1
apt-get install git curl wget -y > /dev/null 2>&1

# 2. Safely clone or force-update the repository (Preserves panel.db and configs!)
if [ -d "/opt/bluefalcon-ultimate-toolkit/.git" ]; then
    cd /opt/bluefalcon-ultimate-toolkit
    # Force Git to overwrite modified scripts without touching untracked user data
    git fetch --all > /dev/null 2>&1
    git reset --hard origin/main > /dev/null 2>&1
else
    # Move to a safe directory so we never delete the ground we are standing on
    cd /opt
    git clone -q https://github.com/bluefalcon2270/bluefalcon-ultimate-toolkit.git
fi

# 3. Execute the main God Script
cd /opt/bluefalcon-ultimate-toolkit
chmod +x setup.sh
./setup.sh