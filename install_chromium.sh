#!/bin/bash
# Copyright (c) 2019 Muntashir Al-Islam. All rights reserved.

# USAGE: install_chromium.sh <chromiumos_image.img> <efi_part> <root_a_part> <state_part>
# Example: install_chromium.sh ~/Downloads/ChromeOS/chromiumos_image.img sda4 sda5 sda6

if [ $UID -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

#
# Mount the partition if not already
# $1: Partition name e.g. sda11
# $2: Mount point
function mountIfNotAlready {
    if [ -e "$2" ]; then
        umount "$2" 2> /dev/null
        umount "/dev/$1" 2> /dev/null
        rm -rf "$2"
    fi
    mkdir "$2"
    mount "/dev/$1" "$2"
}

#
# The main function
# $1: chromiumos_image.img
# $2: HDD EFI-SYSTEM parition id e.g. sda4
# $3: HDD ROOT-A partition id e.g. sda5
# $4: HDD STATE partition id e.g. sda6
function main {
    if [ $# -ne 5 ]; then
        echo "Invalid argument!"
        echo "USAGE: install_chromium.sh <chromiumos_image.img> <efi_part> <root_a_part> <state_part>"
        exit 1
    fi
    
    local chrome_image=$1
    local hdd_efi_part="/dev/$2"
    local hdd_root_a_part="/dev/$3"
    local hdd_state_part="/dev/$4"
    
    # Mount the image
    local img_disk=`/sbin/losetup --show -fP "${chrome_image}"`
    local img_efi_part="${img_disk}p12"
    local img_root_a_part="${img_disk}p3"
    local img_state_part="${img_disk}p1"
    
    local user=`logname`
    if [ $? -ne 0 ]; then
        user="chronos"
    fi
    local root="/home/${user}"
    local efi_dir="${root}/efi"
    local local_efi_dir="${root}/localefi"
    local root_a="${root}/roota"
    local local_root_a="${root}/localroota"
    local state="${root}/state"
    local local_state="${root}/localstate"
    
    echo "ChromiumOS HDD installer"
    echo "------------------------"
    echo
    echo -n "Copying EFI-SYSTEM..."
    # Mount partition#12 (EFI-SYSTEM) of the image
    mountIfNotAlready "${img_efi_part}" "${efi_dir}"
    # Mount the EFI-SYSTEM partition of the HDD
    mountIfNotAlready "${hdd_efi_part}" "${local_efi_dir}"
    # Delete all the contents of the local partition
    rm -Rf "${local_efi_dir}"/*
    # Copy files
    cp -a "${efi_dir}"/* "${local_efi_dir}" 2> /dev/null
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo "Failed copying files, may contain corrupted files."
        exit 1
    fi

    echo -n "Copying ROOT-A..."
    # Mount partition#3 (ROOT-A) of the image
    mountIfNotAlready "${img_root_a_part}" "${root_a}"
    # Mount the ROOT-A partition of the HDD
    mountIfNotAlready "${hdd_root_a_part}" "${local_root_a}"
    # Delete all the contents of the local partition
    rm -Rf "${local_root_a}"/*
    # Copy files
    cp -a "${root_a}"/* "${local_root_a}" 2> /dev/null
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo "Failed copying files, may contain corrupted files."
        exit 1
    fi

    echo -n "Copying STATE..."
    # Mount partition#1 (STATE) of the image
    mountIfNotAlready "${img_state_part}" "${state}"
    # Mount the STATE partition of the HDD
    mountIfNotAlready "${hdd_state_part}" "${local_state}"
    # Delete all the contents of the local partition
    rm -Rf "${local_state}"/*
    # Copy files
    cp -a "${state}"/* "${local_state}" 2> /dev/null
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo "Failed copying files, may contain corrupted files."
        exit 1
    fi
    echo
    echo "Now edit ${local_root_a}/usr/sbin/write_gpt.sh to keep only the required partitions."
    exit 0
}

# Exec part
main "$@"
