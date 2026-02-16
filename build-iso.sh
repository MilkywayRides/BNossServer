#!/bin/bash
set -e

WORK_DIR=$(pwd)/build
ISO_DIR=$WORK_DIR/iso
ROOTFS_DIR=$WORK_DIR/rootfs
KERNEL_VERSION="6.6.15"
ISO_NAME="bnoss-server-$(date +%Y%m%d).iso"

echo "=== Building BNoss Server ==="

# Clean previous builds
rm -rf $WORK_DIR
mkdir -p $ISO_DIR/{casper,isolinux,install}
mkdir -p $ROOTFS_DIR

# Create base Ubuntu system
echo "Creating base system..."
debootstrap --arch=amd64 jammy $ROOTFS_DIR http://archive.ubuntu.com/ubuntu/

# Configure the system
echo "Configuring system..."
cat > $ROOTFS_DIR/etc/hostname << EOF
bnoss-server
EOF

cat > $ROOTFS_DIR/etc/hosts << EOF
127.0.0.1   localhost bnoss-server
::1         localhost ip6-localhost ip6-loopback
EOF

# Mount necessary filesystems
mount --bind /dev $ROOTFS_DIR/dev
mount --bind /proc $ROOTFS_DIR/proc
mount --bind /sys $ROOTFS_DIR/sys

# Install essential packages
chroot $ROOTFS_DIR /bin/bash << 'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    linux-image-generic \
    systemd \
    systemd-sysv \
    network-manager \
    openssh-server \
    sudo \
    vim \
    curl \
    wget \
    net-tools \
    iproute2 \
    iputils-ping \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    locales \
    tzdata \
    grub-pc-bin \
    grub-common

# Configure locale
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# Set root password
echo "root:bnoss" | chpasswd

# Create default user
useradd -m -s /bin/bash -G sudo bnoss
echo "bnoss:bnoss" | chpasswd

# Enable services
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable ssh 2>/dev/null || true

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*
CHROOT_EOF

# Unmount filesystems
umount $ROOTFS_DIR/dev
umount $ROOTFS_DIR/proc
umount $ROOTFS_DIR/sys

# Add branding
cat > $ROOTFS_DIR/etc/issue << 'EOF'
BNoss Server \n \l

Welcome to BNoss Server - Your Custom Linux Distribution
Default credentials: bnoss/bnoss (Please change after first login)

EOF

cat > $ROOTFS_DIR/etc/motd << 'EOF'
  ____  _   _                 ____                            
 | __ )| \ | | ___  ___ ___  / ___|  ___ _ ____   _____ _ __ 
 |  _ \|  \| |/ _ \/ __/ __| \___ \ / _ \ '__\ \ / / _ \ '__|
 | |_) | |\  | (_) \__ \__ \  ___) |  __/ |   \ V /  __/ |   
 |____/|_| \_|\___/|___/___/ |____/ \___|_|    \_/ \___|_|   

Welcome to BNoss Server!
For support, visit: https://github.com/MilkywayRides/BNossServer

EOF

# Create squashfs
echo "Creating squashfs..."
mksquashfs $ROOTFS_DIR $ISO_DIR/casper/filesystem.squashfs -comp xz

# Copy kernel and initrd
echo "Copying kernel..."
cp $ROOTFS_DIR/boot/vmlinuz-* $ISO_DIR/casper/vmlinuz
cp $ROOTFS_DIR/boot/initrd.img-* $ISO_DIR/casper/initrd

# Create isolinux config
cat > $ISO_DIR/isolinux/isolinux.cfg << 'EOF'
DEFAULT bnoss
LABEL bnoss
  KERNEL /casper/vmlinuz
  APPEND boot=casper initrd=/casper/initrd quiet splash ---
TIMEOUT 50
PROMPT 1
EOF

# Copy isolinux files
cp /usr/lib/ISOLINUX/isolinux.bin $ISO_DIR/isolinux/
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 $ISO_DIR/isolinux/

# Create grub config
mkdir -p $ISO_DIR/boot/grub
cat > $ISO_DIR/boot/grub/grub.cfg << 'EOF'
set default="0"
set timeout=10

menuentry "BNoss Server" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "BNoss Server (Safe Mode)" {
    linux /casper/vmlinuz boot=casper nomodeset quiet splash ---
    initrd /casper/initrd
}
EOF

# Create disk info
cat > $ISO_DIR/.disk/info << EOF
BNoss Server $(date +%Y%m%d)
EOF

# Generate manifest
chroot $ROOTFS_DIR dpkg-query -W --showformat='${Package} ${Version}\n' > $ISO_DIR/casper/filesystem.manifest

# Create ISO
echo "Creating ISO..."
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "BNoss Server" \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -output $ISO_NAME \
    $ISO_DIR 2>/dev/null || \
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "BNoss Server" \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -output $ISO_NAME \
    $ISO_DIR

echo "=== Build complete: $ISO_NAME ==="
ls -lh $ISO_NAME
