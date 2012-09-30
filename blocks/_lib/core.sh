#!/bin/bash
# ------------------------------------------------------------------------
# archblocks - modular Arch Linux install script
# ------------------------------------------------------------------------
# blocks/lib/core.sh - main installer execution sequence

# PREFLIGHT --------------------------------------------------------------

# buckle up
set -o errexit

# check if we're in an IO redirect of some sort
[ ! -f "${0}" ] && echo "Don't run this directly from curl. Save to file first." && exit

# set mount point, temp directory, script values
MNT=/mnt; TMP=/tmp/archblocks; POSTSCRIPT="/post-chroot.sh"

# DEFAULT VALUES ---------------------------------------------------------

#TODO: make sure this is a check for UNSET to allow for user to set to empty value
#_defaultvalue USERNAME user
#_defaultvalue SYSTEMTYPE unknown
_defaultvalue HOSTNAME archlinux
_defaultvalue USERSHELL /bin/bash
_defaultvalue FONT Lat2-Terminus16
_defaultvalue FONT ""
_defaultvalue LANGUAGE en_US.UTF-8
_defaultvalue KEYMAP us
_defaultvalue TIMEZONE US/Pacific
_defaultvalue MODULES ""
_defaultvalue HOOKS "base udev autodetect pata scsi sata filesystems usbinput fsck"
_defaultvalue KERNEL_PARAMS "quiet" # set/used in FILESYSTEM,INIT,BOOTLOADER blocks
_defaultvalue DRIVE /dev/sda # this overrides any default value set in FILESYSTEM block
_defaultvalue PRIMARY_BOOTLOADER UEFI # UEFI or BIOS (case insensitive)
_defaultvalue REMOTE https://raw.github.com/altercation/archblocks/master
_defaultvalue AURHELPER packer
#TODO: add AURHELPER default (packer)

# ARCH PREP & SYSTEM INSTALL (PRE CHROOT) --------------------------------

if [ ! -e "${POSTSCRIPT}" ] && [ ! -e "${MNT}${POSTSCRIPT}" ]; then

# WARN USER OF IMPENDING DOOM
_initialwarning

# SET FONT FOR PLEASANT INSTALL EXPERIENCE
setfont $FONT

# ATTEMPT TO LOAD EFIVARS, EVEN IF NOT USING EFI (REQUIRED)
_load_efi_modules || true

# LOAD FILESYSTEM (FUNCTIONS AND VARIABLE DECLARATION ONLY)
_loadblock "${FILESYSTEM}"

# FILESYSTEM CREATION AND CONFIG
_filesystem_pre_baseinstall

# INSTALL ARCH
pacstrap ${MOUNT_PATH} base base-devel

# WRITE FSTAB/CRYPTTAB AND ANY OTHER POST INTALL FILESYSTEM CONFIG
_filesystem_post_baseinstall

# PROBABLY UNMOUNT OF BOOT IF INSTALLING UEFI MODE
_filesystem_pre_chroot

# CHROOT AND CONTINUE EXECUTION
_chroot_postscript

fi

# ARCH CONFIG (POST CHROOT) ----------------------------------------------

if [ -e "${POSTSCRIPT}" ]; then

# SHOULDN'T HAVE CHANGED
setfont $FONT

# ATTEMPT TO RELOAD EVIVARS, EVEN IF NOT USING EFI (REQUIRED)
_load_efi_modules || true

# FILESYSTEM POST-CHROOT CONFIGURATION
_loadblock "${FILESYSTEM}"
_filesystem_post_chroot

# LOCALE
_uncommentvalue ${LANGUAGE} /etc/locale.gen; locale-gen
export LANG=${LANGUAGE}; echo LANG=${LANGUAGE} > /etc/locale.conf
echo -e "KEYMAP=${KEYMAP}\nFONT=${FONT}\nFONT_MAP=${FONTMAP}" > /etc/vconsole.conf

# TIME
_loadblock "${TIME}"

# HOSTNAME
echo ${HOSTNAME} > /etc/hostname; sed -i "s/localhost\.localdomain/${HOSTNAME}/g" /etc/hosts

# TIME
ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime; echo ${TIMEZONE} >> /etc/timezone
hwclock --systohc --utc # set hardware clock
_installpkg ntp
sed -i "/^DAEMONS/ s/hwclock /!hwclock @ntpd /" /etc/rc.conf

# DAEMONS

# INIT/SYSTEMD

# NETWORKING
_loadblock "${NETWORK}"

# AUDIO
_loadblock "${AUDIO}"

# VIDEO
_loadblock "${VIDEO}"

# POWER
_loadblock "${POWER}"

# KERNEL
#_loadblock "${KERNEL}"

# RAMDISK
cp /etc/mkinitcpio.conf /etc/mkinitcpio.orig
sed -i "s/^MODULES.*$/MODULES=\"${MODULES}\"/" /etc/mkinitcpio.conf
sed -i "s/^HOOKS.*$/HOOKS=\"${HOOKS}\"/" /etc/mkinitcpio.conf
mkinitcpio -p linux

# BOOTLOADER
_loadblock "${BOOTLOADER}"

fi

