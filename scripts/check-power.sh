#!/bin/bash
# Check power supply and undervoltage warnings for Raspberry Pi 4

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "  Power Supply & USB Check"
echo "========================================="
echo ""

# Check for undervoltage warnings
echo "=== Undervoltage Warnings ==="
undervoltage=$(dmesg | grep -i "under-voltage" | wc -l)

if [[ $undervoltage -gt 0 ]]; then
    echo -e "${RED}WARNING: $undervoltage undervoltage events detected!${NC}"
    echo "Recent warnings:"
    dmesg | grep -i "under-voltage" | tail -5
    echo ""
    echo "Recommendations:"
    echo "  - Use official Raspberry Pi 15W power supply"
    echo "  - Consider a powered USB hub for external drives"
    echo "  - Reduce USB device load"
else
    echo -e "${GREEN}No undervoltage warnings detected${NC}"
fi
echo ""

# Check throttling
echo "=== CPU Throttling Status ==="
throttle=$(vcgencmd get_throttled 2>/dev/null)
if [[ "$throttle" == "throttled=0x0" ]]; then
    echo -e "${GREEN}No throttling - Power supply is adequate${NC}"
else
    echo -e "${YELLOW}Throttling detected: $throttle${NC}"
    echo ""
    echo "Throttle flags:"
    echo "  0x1  = Under-voltage detected"
    echo "  0x2  = Arm frequency capped"
    echo "  0x4  = Currently throttled"
    echo "  0x8  = Soft temperature limit active"
    echo "  0x10000 = Under-voltage has occurred"
    echo "  0x20000 = Arm frequency capping has occurred"
    echo "  0x40000 = Throttling has occurred"
    echo "  0x80000 = Soft temperature limit has occurred"
fi
echo ""

# USB devices
echo "=== USB Devices ==="
lsusb -t 2>/dev/null || lsusb
echo ""

# External HDD detection
echo "=== External Storage ==="
if lsblk | grep -q "sd"; then
    lsblk -o NAME,SIZE,MODEL,TRAN,STATE | grep -E "sd|NAME"
    echo ""

    # Check if Toshiba Canvio detected
    if lsblk -o MODEL | grep -qi "canvio\|toshiba"; then
        echo -e "${GREEN}Toshiba Canvio detected!${NC}"
    fi
else
    echo -e "${YELLOW}No external USB storage detected${NC}"
fi
echo ""

# Power consumption estimate
echo "=== Power Consumption Estimate ==="
echo "  Raspberry Pi 4 8GB: ~6W (max 7.5W under load)"
echo "  Toshiba Canvio 2TB: ~2.5W (max 4.5W at startup)"
echo "  ----------------------------------------"
echo "  Estimated total: ~8.5W to 12W"
echo "  Your power supply: 15W"
echo -e "  ${GREEN}Margin: +3W to +6.5W${NC}"
echo ""

# Temperature check
echo "=== System Temperature ==="
if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp_c=$((temp/1000))
    if [[ $temp_c -gt 70 ]]; then
        echo -e "  CPU: ${RED}${temp_c}°C - Too hot! Add cooling${NC}"
    elif [[ $temp_c -gt 60 ]]; then
        echo -e "  CPU: ${YELLOW}${temp_c}°C - Warm, monitor closely${NC}"
    else
        echo -e "  CPU: ${GREEN}${temp_c}°C - Good${NC}"
    fi
fi
echo ""

# Recommendations
echo "=== Recommendations ==="
if [[ $undervoltage -gt 0 ]]; then
    echo -e "${RED}CRITICAL: Power supply issues detected${NC}"
    echo "  1. Check power supply cable quality"
    echo "  2. Use official Raspberry Pi 15W PSU"
    echo "  3. Consider powered USB hub for HDD"
elif [[ "$throttle" != "throttled=0x0" ]]; then
    echo -e "${YELLOW}Monitor power supply closely${NC}"
    echo "  - Check after extended HDD usage"
    echo "  - Monitor during heavy downloads"
else
    echo -e "${GREEN}Power supply configuration looks good!${NC}"
    echo "  - Direct USB connection should work fine"
    echo "  - Monitor for first few days of use"
fi
echo ""

echo "Run this script periodically to check for power issues:"
echo "  ./scripts/check-power.sh"
