#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

clear

echo "========================================"
echo " System Information"
echo "========================================"
echo

echo "RAM:"
free -h

echo
echo "Disk Usage:"
df -h /

echo
TOTAL_DISK=$(df -h / | awk 'NR==2 {print $2}')
USED_DISK=$(df -h / | awk 'NR==2 {print $3}')
FREE_DISK=$(df -h / | awk 'NR==2 {print $4}')

echo
echo "Total Disk Space : $TOTAL_DISK"
echo "Used Disk Space  : $USED_DISK"
echo "Free Disk Space  : $FREE_DISK"

echo
CURRENT_SWAP=$(free -h | awk '/Swap:/ {print $2}')
echo "Current Swap     : $CURRENT_SWAP"

echo
echo "Suggested Swap Sizes:"
echo "  1G   -> Small VPS (1GB RAM)"
echo "  2G   -> Small VPS (2GB RAM)"
echo "  4G   -> Medium VPS (4GB RAM)"
echo "  8G   -> Large VPS (8GB+ RAM)"
echo

read -p "Enter swap size (e.g. 1G, 2G, 4G, 8G): " SWAPSIZE

if [[ ! "$SWAPSIZE" =~ ^[0-9]+[GgMm]$ ]]; then
    echo "Invalid size format."
    exit 1
fi

if [ -f /swapfile ]; then
    echo
    echo "Existing swapfile found."

    read -p "Remove and recreate swap? (y/n): " CONFIRM

    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        swapoff /swapfile 2>/dev/null || true
        sed -i '\|/swapfile|d' /etc/fstab
        rm -f /swapfile
    else
        echo "Cancelled."
        exit 0
    fi
fi

echo
echo "Creating swap file..."

if command -v fallocate >/dev/null 2>&1; then
    fallocate -l "$SWAPSIZE" /swapfile
else
    dd if=/dev/zero of=/swapfile bs=1M count=$(( ${SWAPSIZE%[Gg]} * 1024 ))
fi

chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

grep -q "^/swapfile" /etc/fstab || \
echo "/swapfile none swap sw 0 0" >> /etc/fstab

echo
echo "Applying recommended kernel settings..."

mkdir -p /etc/sysctl.d

cat > /etc/sysctl.d/99-swap.conf << EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF

sysctl vm.swappiness=10
sysctl vm.vfs_cache_pressure=50

sysctl --system >/dev/null 2>&1 || true

echo
echo "========================================"
echo " Swap Configuration Complete"
echo "========================================"

echo
echo "Active Swap:"
swapon --show

echo
echo "Memory Status:"
free -h

echo
echo "Kernel Parameters:"
sysctl vm.swappiness
sysctl vm.vfs_cache_pressure

echo
echo "Swap is active immediately."
echo "No reboot is required."

echo
read -p "Do you want to reboot now anyway? (y/n): " REBOOT

if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
    reboot
fi
