#!/bin/bash
# Copyright (c) 2019 Muntashir Al-Islam. All rights reserved.

# USAGE: install_chromium.sh <usb> <efi_part> <root_a_part> <state_part>
# Example: install_chromium.sh sdb sda4 sda5 sda6

if [ $UID -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

user=`logname`
root="/home/${user}"
efi_dir="${root}/efi"
local_efi_dir="${root}/localefi"
root_a="${root}/roota"
local_root_a="${root}/localroota"
state="${root}/state"
local_state="${root}/localstate"

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
# $1: USB device id e.g. sdb, sdc
# $2: HDD EFI-SYSTEM parition id e.g. sda4
# $3: HDD ROOT-A partition id e.g. sda5
# $4: HDD STATE partition id e.g. sda6
function main {
    if [ $# -ne 5 ]; then
        echo "Invalid argument!"
        echo "USAGE: install_chromium.sh <usb> <efi_part> <root_a_part> <state_part>"
        exit 1
    fi
    local usb="$1"
    echo "ChromiumOS HDD installer"
    echo "------------------------"
    echo
    echo -n "Copying EFI-SYSTEM..."
    # Mount partition#12 (EFI-SYSTEM) of the image
    mountIfNotAlready "${usb}12" "${efi_dir}"
    # Mount the EFI-SYSTEM partition of the HDD
    mountIfNotAlready "$2" "${local_efi_dir}"
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
    mountIfNotAlready "${usb}3" "${root_a}"
    # Mount the ROOT-A partition of the HDD
    mountIfNotAlready "$3" "${local_root_a}"
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
    mountIfNotAlready "${usb}1" "${state}"
    # Mount the STATE partition of the HDD
    mountIfNotAlready "$4" "${local_state}"
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
