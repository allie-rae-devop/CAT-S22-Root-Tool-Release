# CAT S22 Flip Root Tool v4.0

> **🤖 Development Note:** This tool was developed with assistance from Claude (Anthropic AI) and Claude Code. The codebase has been extensively tested on real hardware and refined through iterative development.

**One-click root tool for CAT S22 Flip (T-Mobile) firmware v30**

## ⚡ Features

- ✅ Automated rooting process
- ✅ Unlocks bootloader
- ✅ Installs Magisk
- ✅ Optional debloat wizard
- ✅ Removes T-Mobile/Google bloatware
- ✅ Battery optimization
- ✅ Full error recovery

## 📋 Requirements

- Windows 10/11
- CAT S22 Flip on firmware v30
- USB cable
- ~500MB free disk space

## 🚀 Quick Start

1. **Enable Developer Options** on phone:
   - Settings → About phone
   - Tap "Build number" 7 times

2. **Enable USB Debugging**:
   - Settings → Developer options
   - Enable "USB debugging"
   - Enable "OEM unlocking"

3. **Run the tool**:
   - Right-click `CAT_S22_Root_Tool.ps1`
   - Select "Run with PowerShell"
   - Follow on-screen instructions

## ⚠️ Important Notes

- **Unlocking bootloader WIPES ALL DATA** - backup first!
- Tool requires internet for first-time setup
- Process takes ~15-20 minutes
- Phone will reboot multiple times

## 📦 What's Included

```
CAT_S22_Root_Tool/
├── CAT_S22_Root_Tool.ps1      # Main tool
├── boot_images/
│   └── boot_v30.img            # Pre-patched boot image
├── Magisk-v25.2.apk            # Magisk installer
├── README.md                   # This file
└── LICENSE                     # MIT License
```

## 🔧 Advanced: Creating boot_v30.img

## 🔧 Advanced: Recreating boot_v30.img

The included `boot_v30.img` was created using the following process.
You only need this if you want to verify or recreate the boot image.

**Note:** OTA files are not included due to size/licensing. Download from:
- [v29 OTA](#) (Google OTA Server)
- [v30 OTA](#) (Google OTA Server)

If you want to create the boot image yourself:

### Prerequisites
- WSL (Windows Subsystem for Linux)
- v29 and v30 OTA packages

### Steps
```bash
# In WSL:
sudo apt install -y libbz2-dev zlib1g-dev libssl-dev brotli

# Clone imgpatchtools:
git clone https://github.com/erfanoabdi/imgpatchtools
cd imgpatchtools
make
sudo cp bin/ApplyPatch /usr/local/bin/

# Extract v29 boot.img and v30 boot.img.p from OTA packages

# Apply v30 patch to v29 base:
cp boot_v29.img boot_v30.img
ApplyPatch boot_v30.img - \
    2781175354d624db73f6a172b796c2c563058e66 \
    33554432 \
    ee07c75d51068a497f194b2acfd2af9f5b54e957 \
    boot.img.p

# Verify SHA1:
sha1sum boot_v30.img
# Should output: 2781175354d624db73f6a172b796c2c563058e66
```

## 🧹 Debloat Feature

After rooting, the tool offers optional debloating:

### Categories Available:
- **T-Mobile/Carrier** - Removes carrier bloat
- **Google Non-Essential** - Keeps Play Store & Services
- **System Bloat** - Removes Facebook, Netflix installers
- **Google Aggressive** - Removes most Google (advanced users)

### Safe to Remove:
- T-Mobile apps
- YouTube, YouTube Music
- Google Maps, Photos
- Gmail, Calendar
- Chrome browser

### KEEP THESE:
- Google Play Store
- Google Play Services
- Google Services Framework

## 🛟 Troubleshooting

### "Device not detected"
- Install Google USB drivers
- Try different USB port
- Enable USB debugging

### "Bootloader unlock failed"
- Ensure OEM unlocking is enabled
- Try manual unlock: `fastboot flashing unlock`

### "Boot loop after flash"
- This shouldn't happen with v4.0!
- If it does, reflash stock firmware

## 📱 Verify Root

```powershell
adb shell su -c "id"
# Should show: uid=0(root)
```

Or open Magisk app - should show "Installed"

## 🤝 Contributing

Found a bug? Have a suggestion?
- Open an issue on GitHub
- Submit a pull request
- Share on XDA Forums

## 📄 License

MIT License - See LICENSE file

## ⚠️ Disclaimer

- This tool voids your warranty
- Root at your own risk
- Author not responsible for bricked devices
- Always backup your data

## 🙏 Credits

- Magisk by topjohnwu
- imgpatchtools by erfanoabdi
- XDA CAT S22 community
- Original rooting guide contributors

## 📚 Resources

- [XDA CAT S22 Forum](https://xdaforums.com/f/cat-s22-flip.12753/)
- [Magisk Documentation](https://topjohnwu.github.io/Magisk/)
- [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools)

---

**Version:** 4.0  
**Last Updated:** January 2026  
**Tested On:** CAT S22 Flip (T-Mobile) firmware v30
