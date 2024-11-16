#!/bin/bash

# Loop through command line options
# Set REBOOT flag if "--reboot" option is provided
# Set USE_REMOUNT flag if "--use_remount" option is provided
while getopts ":-:" o; do
    case "${OPTARG}" in
    reboot)
        REBOOT=1
        ;;
    use_remount)
        USE_REMOUNT=1
        ;;
    esac
done

# Wait for the device to be available and then run root command
adb wait-for-device root

# Unmount /system/bin and /system/etc if /system is mounted as tmpfs
adb wait-for-device shell "mount | grep -q ^tmpfs\ on\ /system && umount -fl /system/{bin,etc} 2>/dev/null"

# Remount /system as read-write if USE_REMOUNT flag is set, otherwise check if /system has available blocks and mount it as read-write
if [[ "${USE_REMOUNT}" = "1" ]]; then
    adb wait-for-device shell "remount"
elif [[ "$(adb shell stat -f --format %a /system)" = "0" ]]; then
    echo "ERROR: /system has 0 available blocks, consider using --use_remount"
    exit -1
else
    adb wait-for-device shell "stat --format %m /system | xargs mount -o rw,remount"
fi

# Push necessary files to the device
if [ -f WebViewOverlays.zip ]; then
    unzip -oq WebViewOverlays.zip 'system/*'
elif  [ ! -d system ]; then
    echo "Build WebViewOverlays first" && exit 1
fi
adb wait-for-device push system/addon.d/30-webview.sh /system/addon.d/
adb wait-for-device push system/product/overlay/GmsConfigOverlayCommon.apk /product/overlay/

# Reboot the device if REBOOT
if [[ "${REBOOT}" = "1" ]]; then
    adb wait-for-device reboot
fi

read -r -p "Press any key to exit..." && exit
