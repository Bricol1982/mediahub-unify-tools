#!/bin/bash
# Check SMART health status of external HDD
# Recommended before first use

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "  Disk Health Check"
echo "  Seagate SkyHawk ST2000VX003"
echo "========================================="
echo ""

# Check if smartctl is installed
if ! command -v smartctl &> /dev/null; then
    echo "Installing smartmontools..."
    sudo apt-get update && sudo apt-get install -y smartmontools
fi

# Find the disk
echo "Detecting disks..."
lsblk -d -o NAME,SIZE,MODEL | grep -E "sd|NAME"
echo ""

read -p "Enter disk name (e.g., sda): " disk_name

if [[ ! -b "/dev/$disk_name" ]]; then
    echo -e "${RED}Disk /dev/$disk_name not found${NC}"
    exit 1
fi

DISK="/dev/$disk_name"

echo ""
echo "=== Disk Information ==="
sudo smartctl -i "$DISK" | grep -E "Model|Serial|Capacity|Hours|Sector"
echo ""

echo "=== SMART Health Status ==="
health=$(sudo smartctl -H "$DISK" | grep "SMART overall-health")
if echo "$health" | grep -q "PASSED"; then
    echo -e "${GREEN}$health${NC}"
else
    echo -e "${RED}$health${NC}"
    echo -e "${RED}WARNING: Disk may have issues!${NC}"
fi
echo ""

echo "=== Key SMART Attributes ==="
echo "Power-On Hours:"
sudo smartctl -A "$DISK" | grep "Power_On_Hours" | awk '{print "  " $10 " hours (" int($10/24) " days)"}'

echo "Reallocated Sectors:"
realloc=$(sudo smartctl -A "$DISK" | grep "Reallocated_Sector" | awk '{print $10}')
if [[ "$realloc" == "0" ]]; then
    echo -e "  ${GREEN}$realloc (Good)${NC}"
else
    echo -e "  ${YELLOW}$realloc (Monitor this)${NC}"
fi

echo "Current Pending Sectors:"
pending=$(sudo smartctl -A "$DISK" | grep "Current_Pending_Sector" | awk '{print $10}')
if [[ "$pending" == "0" ]]; then
    echo -e "  ${GREEN}$pending (Good)${NC}"
else
    echo -e "  ${RED}$pending (Bad sectors pending!)${NC}"
fi

echo "Temperature:"
temp=$(sudo smartctl -A "$DISK" | grep "Temperature_Celsius" | awk '{print $10}')
if [[ -n "$temp" ]]; then
    if [[ $temp -gt 50 ]]; then
        echo -e "  ${RED}${temp}°C (Too hot!)${NC}"
    elif [[ $temp -gt 40 ]]; then
        echo -e "  ${YELLOW}${temp}°C (Warm)${NC}"
    else
        echo -e "  ${GREEN}${temp}°C (Good)${NC}"
    fi
fi

echo ""
echo "=== Recommendation ==="
if echo "$health" | grep -q "PASSED" && [[ "$realloc" == "0" ]] && [[ "$pending" == "0" ]]; then
    echo -e "${GREEN}Disk is healthy and ready for MediaHub!${NC}"
    echo "You can proceed with formatting."
else
    echo -e "${YELLOW}Consider monitoring or replacing this disk${NC}"
fi
echo ""

# Optional: Full SMART test
read -p "Run extended SMART test? (takes ~30min for 2TB) (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting extended test..."
    sudo smartctl -t long "$DISK"
    echo "Test started. Check results later with:"
    echo "  sudo smartctl -a $DISK"
fi
