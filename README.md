# webview_overlays

- webview_overlays allows you use third party webview providers.
- It can be installed via recovery.
- Survives OTA updates.

## Disclaimer:

```
- The user takes sole responsibility for any damage that might arise due to use of this tool.
- This includes physical damage (to device), injury, data loss, and also legal matters.
- The developers cannot be held liable in any way for the use of this tool.
```

## Requirements for recovery/adb root.

- Android platform tools
- Android device

# Installation

## 1: Download webview_overlays.

Check the "Releases" section on the right.

## 2. Sideload WebViewOverlays.zip.

- Reboot to recovery and select Apply update -> Apply from ADB
- Run this in terminal to install.

```
adb sideload WebViewOverlays.zip
```

## 4: Reboot your device.

## 5: Run below command to set default webview or change it in `Developer options` > `WebView implementation`

```
adb shell cmd webviewupdate set-webview-implementation com.android.webview
```
