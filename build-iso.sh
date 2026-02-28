#!/bin/bash
# ============================================================================
#  BlazeNeuro Linux — Debian-Based Live ISO Builder
#  Based on Debian Bookworm (12) with XFCE4 Desktop
# ============================================================================
set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────
DISTRO_NAME="BlazeNeuro"
DISTRO_VERSION="1.0"
DISTRO_CODENAME="ignite"
DISTRO_URL="https://github.com/MilkywayRides/BNossServer"

WORK_DIR="$(pwd)/build"
ISO_DIR="${WORK_DIR}/iso"
ROOTFS_DIR="${WORK_DIR}/rootfs"
ISO_NAME="blazeneuro-${DISTRO_VERSION}-amd64-$(date +%Y%m%d).iso"
DEBIAN_MIRROR="http://deb.debian.org/debian"
DEBIAN_SUITE="bookworm"
ARCH="amd64"

DEFAULT_USER="blazeneuro"
DEFAULT_PASS="blazeneuro"
DEFAULT_HOSTNAME="blazeneuro"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Colors ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $*"; }
info()  { echo -e "${CYAN}[i]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }

banner() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     ____  _               _   _                              ║"
    echo "║    | __ )| | __ _ _______| \ | | ___ _   _ _ __ ___         ║"
    echo "║    |  _ \| |/ _\` |_  / _ \  \| |/ _ \ | | | '__/ _ \        ║"
    echo "║    | |_) | | (_| |/ /  __/ |\  |  __/ |_| | | | (_) |       ║"
    echo "║    |____/|_|\__,_/___\___|_| \_|\___|\__,_|_|  \___/        ║"
    echo "║                                                              ║"
    echo "║              Debian-Based Linux Distribution                  ║"
    echo "║                    ISO Build System                           ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ─── Cleanup handler ────────────────────────────────────────────────────────
cleanup() {
    info "Cleaning up mounts..."
    for mp in dev/pts dev proc sys run; do
        mountpoint -q "${ROOTFS_DIR}/${mp}" 2>/dev/null && umount -lf "${ROOTFS_DIR}/${mp}" 2>/dev/null || true
    done
}
trap cleanup EXIT

# ─── Preflight checks ───────────────────────────────────────────────────────
check_deps() {
    local deps=(debootstrap mksquashfs xorriso)
    local missing=()
    for d in "${deps[@]}"; do
        command -v "$d" &>/dev/null || missing+=("$d")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        error "Install with: sudo apt-get install -y debootstrap squashfs-tools xorriso isolinux syslinux-efi grub-pc-bin grub-efi-amd64-bin mtools dosfstools"
        exit 1
    fi
}

# ============================================================================
#  PHASE 1 — Bootstrap Debian base system
# ============================================================================
phase1_bootstrap() {
    log "Phase 1: Bootstrapping Debian ${DEBIAN_SUITE} (${ARCH})..."

    rm -rf "${WORK_DIR}"
    mkdir -p "${ISO_DIR}"/{live,boot/grub,isolinux,.disk,EFI/BOOT}
    mkdir -p "${ROOTFS_DIR}"

    debootstrap --arch="${ARCH}" --variant=minbase \
        --include=apt-utils,locales,sudo,systemd,systemd-sysv \
        "${DEBIAN_SUITE}" "${ROOTFS_DIR}" "${DEBIAN_MIRROR}"

    log "Base system bootstrapped."
}

# ============================================================================
#  PHASE 2 — Configure system inside chroot
# ============================================================================
phase2_configure() {
    log "Phase 2: Configuring system..."

    # Mount required filesystems
    mount --bind /dev  "${ROOTFS_DIR}/dev"
    mount --bind /proc "${ROOTFS_DIR}/proc"
    mount --bind /sys  "${ROOTFS_DIR}/sys"
    mount --bind /run  "${ROOTFS_DIR}/run"
    mount -t devpts devpts "${ROOTFS_DIR}/dev/pts"

    # Configure APT sources
    cat > "${ROOTFS_DIR}/etc/apt/sources.list" << EOF
deb ${DEBIAN_MIRROR} ${DEBIAN_SUITE} main contrib non-free non-free-firmware
deb ${DEBIAN_MIRROR} ${DEBIAN_SUITE}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${DEBIAN_SUITE}-security main contrib non-free non-free-firmware
EOF

    # Set hostname
    echo "${DEFAULT_HOSTNAME}" > "${ROOTFS_DIR}/etc/hostname"
    cat > "${ROOTFS_DIR}/etc/hosts" << EOF
127.0.0.1   localhost ${DEFAULT_HOSTNAME}
::1         localhost ip6-localhost ip6-loopback ${DEFAULT_HOSTNAME}
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

    # Run chroot configuration
    chroot "${ROOTFS_DIR}" /bin/bash << 'CHROOT_EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

# ── Configure locale ──
apt-get update
apt-get install -y locales
sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# ── Install Linux kernel ──
apt-get install -y linux-image-amd64 linux-headers-amd64 firmware-linux-free

# ── Install live boot system ──
apt-get install -y live-boot live-boot-initramfs-tools live-config live-config-systemd

# ── Install XFCE4 Desktop Environment ──
apt-get install -y \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    xfce4-whiskermenu-plugin \
    xfce4-pulseaudio-plugin \
    xfce4-screenshooter \
    xfce4-taskmanager \
    xfce4-power-manager \
    thunar \
    thunar-archive-plugin \
    thunar-volman \
    mousepad \
    ristretto \
    xfce4-notifyd

# ── Install display manager ──
apt-get install -y lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings

# ── Install essential system tools ──
apt-get install -y \
    network-manager \
    network-manager-gnome \
    openssh-server \
    sudo \
    vim \
    nano \
    curl \
    wget \
    git \
    htop \
    neofetch \
    net-tools \
    iproute2 \
    iputils-ping \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    dbus-x11 \
    policykit-1 \
    udisks2 \
    gvfs \
    gvfs-backends \
    pulseaudio \
    pavucontrol \
    alsa-utils \
    cups \
    system-config-printer \
    bluetooth \
    blueman \
    zip \
    unzip \
    p7zip-full \
    file-roller \
    man-db \
    bash-completion \
    fonts-noto \
    fonts-noto-color-emoji \
    fonts-liberation2 \
    fonts-dejavu-core \
    dmz-cursor-theme \
    adwaita-icon-theme \
    papirus-icon-theme \
    arc-theme \
    plymouth \
    plymouth-themes \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-common

# ── Install desktop applications ──
apt-get install -y \
    firefox-esr \
    synaptic \
    gparted \
    gnome-disk-utility \
    baobab \
    evince \
    eog \
    galculator \
    xterm

# ── Install Calamares installer ──
apt-get install -y calamares calamares-settings-debian || {
    echo "Warning: Calamares not available, skipping installer"
}

# ── Configure locale & timezone ──
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo "UTC" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# ── Set root password ──
echo "root:blazeneuro" | chpasswd

# ── Create default user ──
useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev,bluetooth,lpadmin,scanner "${DEFAULT_USER:-blazeneuro}" 2>/dev/null || true
echo "${DEFAULT_USER:-blazeneuro}:${DEFAULT_PASS:-blazeneuro}" | chpasswd

# ── Configure sudo (passwordless for live) ──
echo "${DEFAULT_USER:-blazeneuro} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/blazeneuro
chmod 440 /etc/sudoers.d/blazeneuro

# ── Enable services ──
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable lightdm 2>/dev/null || true
systemctl enable ssh 2>/dev/null || true
systemctl enable bluetooth 2>/dev/null || true

# ── Configure LightDM autologin for live session ──
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-blazeneuro.conf << 'LIGHTDM_CONF'
[Seat:*]
autologin-user=blazeneuro
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
LIGHTDM_CONF

# ── Update initramfs ──
update-initramfs -u -k all

# ── Clean up ──
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/* /var/tmp/*

CHROOT_EOF

    log "System configuration complete."
}

# ============================================================================
#  PHASE 3 — Apply BlazeNeuro branding
# ============================================================================
phase3_branding() {
    log "Phase 3: Applying BlazeNeuro branding..."

    # ── /etc/os-release ──
    cat > "${ROOTFS_DIR}/etc/os-release" << EOF
PRETTY_NAME="${DISTRO_NAME} ${DISTRO_VERSION} (${DISTRO_CODENAME})"
NAME="${DISTRO_NAME}"
VERSION_ID="${DISTRO_VERSION}"
VERSION="${DISTRO_VERSION} (${DISTRO_CODENAME})"
VERSION_CODENAME=${DISTRO_CODENAME}
ID=blazeneuro
ID_LIKE=debian
HOME_URL="${DISTRO_URL}"
SUPPORT_URL="${DISTRO_URL}/issues"
BUG_REPORT_URL="${DISTRO_URL}/issues"
EOF

    # ── /etc/lsb-release ──
    cat > "${ROOTFS_DIR}/etc/lsb-release" << EOF
DISTRIB_ID=${DISTRO_NAME}
DISTRIB_RELEASE=${DISTRO_VERSION}
DISTRIB_CODENAME=${DISTRO_CODENAME}
DISTRIB_DESCRIPTION="${DISTRO_NAME} ${DISTRO_VERSION} (${DISTRO_CODENAME})"
EOF

    # ── /etc/issue ──
    cat > "${ROOTFS_DIR}/etc/issue" << EOF
${DISTRO_NAME} ${DISTRO_VERSION} \\n \\l

Welcome to ${DISTRO_NAME} — Ignite Your Workflow
Default credentials: blazeneuro / blazeneuro (Please change after install)

EOF

    # ── /etc/issue.net ──
    cat > "${ROOTFS_DIR}/etc/issue.net" << EOF
${DISTRO_NAME} ${DISTRO_VERSION}
EOF

    # ── MOTD ──
    cat > "${ROOTFS_DIR}/etc/motd" << 'EOF'

  ____  _               _   _
 | __ )| | __ _ _______| \ | | ___ _   _ _ __ ___
 |  _ \| |/ _` |_  / _ \  \| |/ _ \ | | | '__/ _ \
 | |_) | | (_| |/ /  __/ |\  |  __/ |_| | | | (_) |
 |____/|_|\__,_/___\___|_| \_|\___|\__,_|_|  \___/

 Welcome to BlazeNeuro — Ignite Your Workflow!
 Documentation: https://github.com/MilkywayRides/BNossServer

EOF

    # ── Copy LightDM greeter config ──
    if [[ -f "${SCRIPT_DIR}/configs/lightdm/lightdm-gtk-greeter.conf" ]]; then
        cp "${SCRIPT_DIR}/configs/lightdm/lightdm-gtk-greeter.conf" \
           "${ROOTFS_DIR}/etc/lightdm/lightdm-gtk-greeter.conf"
    fi

    # ── Copy XFCE4 default config to skeleton ──
    local skel_xfce="${ROOTFS_DIR}/etc/skel/.config/xfce4"
    mkdir -p "${skel_xfce}"
    if [[ -d "${SCRIPT_DIR}/configs/xfce4" ]]; then
        cp -r "${SCRIPT_DIR}/configs/xfce4/"* "${skel_xfce}/"
    fi

    # ── Also apply to the default user ──
    local user_xfce="${ROOTFS_DIR}/home/${DEFAULT_USER}/.config/xfce4"
    mkdir -p "${user_xfce}"
    if [[ -d "${SCRIPT_DIR}/configs/xfce4" ]]; then
        cp -r "${SCRIPT_DIR}/configs/xfce4/"* "${user_xfce}/"
        chroot "${ROOTFS_DIR}" chown -R 1000:1000 "/home/${DEFAULT_USER}/.config"
    fi

    # ── Copy default wallpaper ──
    local wallpaper_dir="${ROOTFS_DIR}/usr/share/backgrounds/blazeneuro"
    mkdir -p "${wallpaper_dir}"
    if [[ -f "${SCRIPT_DIR}/branding/wallpaper.png" ]]; then
        cp "${SCRIPT_DIR}/branding/wallpaper.png" "${wallpaper_dir}/default.png"
    else
        # Generate a simple branded wallpaper placeholder
        info "No wallpaper found, creating branded placeholder..."
        convert -size 1920x1080 \
            -define gradient:angle=135 \
            gradient:'#0f0c29-#302b63-#24243e' \
            -gravity center -pointsize 72 -fill '#ffffff80' \
            -annotate 0 "BlazeNeuro" \
            "${wallpaper_dir}/default.png" 2>/dev/null || {
            # Fallback: create a solid color wallpaper if ImageMagick is not available
            info "ImageMagick not available, skipping wallpaper generation"
        }
    fi

    # ── Copy distro logo ──
    local logo_dir="${ROOTFS_DIR}/usr/share/blazeneuro"
    mkdir -p "${logo_dir}"
    if [[ -f "${SCRIPT_DIR}/branding/logo.png" ]]; then
        cp "${SCRIPT_DIR}/branding/logo.png" "${logo_dir}/logo.png"
    fi

    # ── Copy Calamares branding if exists ──
    if [[ -d "${SCRIPT_DIR}/configs/calamares" ]]; then
        mkdir -p "${ROOTFS_DIR}/etc/calamares"
        cp -r "${SCRIPT_DIR}/configs/calamares/"* "${ROOTFS_DIR}/etc/calamares/"
    fi

    # ── Neofetch config ──
    local neofetch_dir="${ROOTFS_DIR}/etc/skel/.config/neofetch"
    mkdir -p "${neofetch_dir}"
    cat > "${neofetch_dir}/config.conf" << 'NEOFETCH_CONF'
print_info() {
    info title
    info underline
    info "OS" distro
    info "Host" model
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "DE" de
    info "WM" wm
    info "Terminal" term
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory
    info "Disk" disk
    info cols
}
ascii_distro="auto"
NEOFETCH_CONF

    log "Branding applied."
}

# ============================================================================
#  PHASE 4 — Build the bootable ISO
# ============================================================================
phase4_build_iso() {
    log "Phase 4: Building ISO image..."

    # Unmount chroot filesystems
    cleanup

    # ── Create squashfs ──
    info "Creating squashfs filesystem (this takes a while)..."
    mksquashfs "${ROOTFS_DIR}" "${ISO_DIR}/live/filesystem.squashfs" \
        -comp xz -b 1M -Xbcj x86 -no-exports -noappend

    # ── Calculate filesystem size ──
    du -sx --block-size=1 "${ROOTFS_DIR}" | cut -f1 > "${ISO_DIR}/live/filesystem.size"

    # ── Generate package manifest ──
    chroot "${ROOTFS_DIR}" dpkg-query -W --showformat='${Package} ${Version}\n' \
        > "${ISO_DIR}/live/filesystem.manifest" 2>/dev/null || true

    # ── Copy kernel and initrd ──
    info "Copying kernel and initrd..."
    local vmlinuz initrd
    vmlinuz=$(ls "${ROOTFS_DIR}"/boot/vmlinuz-* 2>/dev/null | sort -V | tail -1)
    initrd=$(ls "${ROOTFS_DIR}"/boot/initrd.img-* 2>/dev/null | sort -V | tail -1)

    if [[ -z "$vmlinuz" || -z "$initrd" ]]; then
        error "Kernel or initrd not found in rootfs!"
        exit 1
    fi

    cp "$vmlinuz" "${ISO_DIR}/live/vmlinuz"
    cp "$initrd"  "${ISO_DIR}/live/initrd"

    # ── ISOLINUX / SYSLINUX (BIOS boot) ──
    info "Setting up BIOS boot (ISOLINUX)..."
    cp /usr/lib/ISOLINUX/isolinux.bin "${ISO_DIR}/isolinux/" 2>/dev/null || true
    cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "${ISO_DIR}/isolinux/" 2>/dev/null || true
    cp /usr/lib/syslinux/modules/bios/libutil.c32 "${ISO_DIR}/isolinux/" 2>/dev/null || true
    cp /usr/lib/syslinux/modules/bios/menu.c32    "${ISO_DIR}/isolinux/" 2>/dev/null || true
    cp /usr/lib/syslinux/modules/bios/vesamenu.c32 "${ISO_DIR}/isolinux/" 2>/dev/null || true
    cp /usr/lib/syslinux/modules/bios/libcom32.c32 "${ISO_DIR}/isolinux/" 2>/dev/null || true

    cat > "${ISO_DIR}/isolinux/isolinux.cfg" << 'EOF'
UI vesamenu.c32
TIMEOUT 50
PROMPT 0
DEFAULT blazeneuro

MENU TITLE BlazeNeuro Boot Menu
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std

LABEL blazeneuro
    MENU LABEL ^BlazeNeuro — Live Desktop
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd boot=live components quiet splash

LABEL blazeneuro-safe
    MENU LABEL BlazeNeuro — ^Safe Mode (No Graphics)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd boot=live components nomodeset

LABEL blazeneuro-toram
    MENU LABEL BlazeNeuro — ^Load to RAM
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd boot=live components toram quiet splash

LABEL blazeneuro-text
    MENU LABEL BlazeNeuro — ^Text Console
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd boot=live components textonly
EOF

    # ── GRUB (UEFI boot) ──
    info "Setting up UEFI boot (GRUB)..."
    cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'EOF'
set default="0"
set timeout=10

insmod all_video
insmod gfxterm
insmod png

set gfxmode=auto
terminal_output gfxterm

set menu_color_normal=white/black
set menu_color_highlight=black/light-cyan

menuentry "BlazeNeuro — Live Desktop" {
    linux /live/vmlinuz boot=live components quiet splash
    initrd /live/initrd
}

menuentry "BlazeNeuro — Safe Mode (No Graphics)" {
    linux /live/vmlinuz boot=live components nomodeset
    initrd /live/initrd
}

menuentry "BlazeNeuro — Load to RAM" {
    linux /live/vmlinuz boot=live components toram quiet splash
    initrd /live/initrd
}

menuentry "BlazeNeuro — Text Console" {
    linux /live/vmlinuz boot=live components textonly
    initrd /live/initrd
}
EOF

    # ── EFI boot image ──
    info "Creating EFI boot image..."
    grub-mkstandalone \
        --format=x86_64-efi \
        --output="${WORK_DIR}/bootx64.efi" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg" 2>/dev/null || true

    if [[ -f "${WORK_DIR}/bootx64.efi" ]]; then
        # Create EFI partition image
        dd if=/dev/zero of="${ISO_DIR}/boot/grub/efi.img" bs=1M count=10
        mkfs.vfat "${ISO_DIR}/boot/grub/efi.img"
        local efi_mount="${WORK_DIR}/efi_mount"
        mkdir -p "${efi_mount}"
        mount "${ISO_DIR}/boot/grub/efi.img" "${efi_mount}"
        mkdir -p "${efi_mount}/EFI/BOOT"
        cp "${WORK_DIR}/bootx64.efi" "${efi_mount}/EFI/BOOT/BOOTX64.EFI"
        umount "${efi_mount}"
        cp "${WORK_DIR}/bootx64.efi" "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI"
    fi

    # ── Disk info ──
    echo "${DISTRO_NAME} ${DISTRO_VERSION} \"${DISTRO_CODENAME}\" - Built $(date +%Y-%m-%d)" \
        > "${ISO_DIR}/.disk/info"
    echo "full" > "${ISO_DIR}/.disk/cd_type"

    # ── Build the final ISO ──
    info "Generating ISO file: ${ISO_NAME}"

    local xorriso_cmd=(
        xorriso -as mkisofs
        -iso-level 3
        -full-iso9660-filenames
        -volid "BlazeNeuro"
        -J -joliet-long
        -rational-rock
    )

    # Add BIOS boot if isolinux.bin exists
    if [[ -f "${ISO_DIR}/isolinux/isolinux.bin" ]]; then
        xorriso_cmd+=(
            -eltorito-boot isolinux/isolinux.bin
            -eltorito-catalog isolinux/boot.cat
            -no-emul-boot
            -boot-load-size 4
            -boot-info-table
            -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin
        )
    fi

    # Add UEFI boot if EFI image exists
    if [[ -f "${ISO_DIR}/boot/grub/efi.img" ]]; then
        xorriso_cmd+=(
            -eltorito-alt-boot
            -e boot/grub/efi.img
            -no-emul-boot
            -isohybrid-gpt-basdat
        )
    fi

    xorriso_cmd+=(-output "${ISO_NAME}" "${ISO_DIR}")

    "${xorriso_cmd[@]}"

    log "ISO build complete!"
    echo ""
    echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  ${DISTRO_NAME} ${DISTRO_VERSION} ISO built successfully!${NC}"
    echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════${NC}"
    ls -lh "${ISO_NAME}"
    echo ""
    echo -e "  ${CYAN}Boot:${NC} BIOS (ISOLINUX) + UEFI (GRUB)"
    echo -e "  ${CYAN}Base:${NC} Debian ${DEBIAN_SUITE} (${ARCH})"
    echo -e "  ${CYAN}Desktop:${NC} XFCE4 + LightDM"
    echo -e "  ${CYAN}User:${NC} ${DEFAULT_USER} / ${DEFAULT_PASS}"
    echo ""
}

# ============================================================================
#  Main
# ============================================================================
main() {
    banner
    check_deps

    info "Building ${DISTRO_NAME} ${DISTRO_VERSION} (${DISTRO_CODENAME})"
    info "Base: Debian ${DEBIAN_SUITE} (${ARCH})"
    info "Mirror: ${DEBIAN_MIRROR}"
    echo ""

    phase1_bootstrap
    phase2_configure
    phase3_branding
    phase4_build_iso
}

main "$@"
