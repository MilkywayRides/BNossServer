# 🔥 BlazeNeuro

**A Debian-based Linux distribution designed to ignite your workflow.**

![Debian Bookworm](https://img.shields.io/badge/base-Debian%20Bookworm-A81D33?logo=debian)
![Desktop](https://img.shields.io/badge/desktop-XFCE4-0e8ed8?logo=xfce)
![Build](https://img.shields.io/badge/build-GitHub%20Actions-2088FF?logo=github-actions)
![License](https://img.shields.io/badge/license-MIT-green)

---

## ✨ Features

- **Debian Bookworm** — Stable, reliable Debian 12 base
- **XFCE4 Desktop** — Lightweight, fast, fully customizable
- **Arc-Dark + Papirus** — Modern dark theme with beautiful icons
- **LightDM Greeter** — Clean, branded login screen
- **Live Boot** — Try without installing, powered by `live-boot`
- **Calamares Installer** — User-friendly graphical installer
- **BIOS + UEFI** — Boot on both legacy and modern hardware
- **Pre-installed Apps** — Firefox ESR, Thunar, Mousepad, GParted, and more
- **Custom Branding** — Unique identity: GRUB, Plymouth, MOTD, neofetch

## 📦 Default Credentials

| Field    | Value         |
|----------|---------------|
| Username | `blazeneuro`  |
| Password | `blazeneuro`  |

> ⚠️ **Change the default password immediately after installation!**

## 🏗️ Building

### Requirements

A Debian/Ubuntu system with root access and the following packages:

```bash
sudo apt-get install -y \
  debootstrap squashfs-tools xorriso isolinux syslinux-efi \
  grub-pc-bin grub-efi-amd64-bin mtools dosfstools
```

### Build the ISO

```bash
sudo bash build-iso.sh
```

The ISO will be output as `blazeneuro-1.0-amd64-YYYYMMDD.iso`.

### CI/CD

Every push to `main` triggers a GitHub Actions build. Download ISOs from:
- **Actions** → Artifacts tab
- **Releases** page (auto-published)

## 📁 Project Structure

```
.
├── build-iso.sh                      # Main ISO build script
├── branding/
│   ├── os-release                    # /etc/os-release
│   └── lsb-release                   # /etc/lsb-release
├── configs/
│   ├── calamares/                    # Installer configuration
│   │   ├── settings.conf
│   │   └── branding/blazeneuro/
│   ├── lightdm/
│   │   └── lightdm-gtk-greeter.conf  # Login screen theme
│   ├── xfce4/                        # Desktop environment config
│   │   ├── panel/
│   │   └── xfconf/
│   ├── plymouth/blazeneuro/          # Boot splash theme
│   └── skel/                         # Default user skeleton
├── .github/workflows/
│   └── build-iso.yml                 # CI/CD pipeline
└── README.md
```

## 📝 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file.

## 🔗 Links

- **Repository**: [github.com/MilkywayRides/BNossServer](https://github.com/MilkywayRides/BNossServer)
- **Issues**: [Report bugs](https://github.com/MilkywayRides/BNossServer/issues)
- **Releases**: [Download ISOs](https://github.com/MilkywayRides/BNossServer/releases)
