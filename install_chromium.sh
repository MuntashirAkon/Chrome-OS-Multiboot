#!/bin/bash
# Copyright (c) 2019 Muntashir Al-Islam. All rights reserved.

# USAGE: install_chromium.sh <chromiumos_image.img> <efi_part> <root_a_part> <state_part> [--skip-state]
# Example: install_chromium.sh ~/Downloads/ChromeOS/chromiumos_image.img sda4 sda5 sda6

if [ $UID -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

#
# Mount the partition if not already
# $1: Partition name e.g. /dev/sda11
# $2: Mount point
function mountIfNotAlready {
    local part_name="$1"
    local mount_point="$2"
    if [ -e "${mount_point}" ]; then
        umount "${mount_point}" 2> /dev/null
        umount "${part_name}" 2> /dev/null
        rm -rf "${mount_point}"
    fi
    mkdir "${mount_point}"
    mount "${part_name}" "${mount_point}"
}

#
# The main function
# $1: chromiumos_image.img
# $2: HDD EFI-SYSTEM parition id e.g. sda4
# $3: HDD ROOT-A partition id e.g. sda5
# $4: HDD STATE partition id e.g. sda6
function main {
    if ! [ $# -ge 4 ]; then
        echo "Invalid argument!"
        echo "USAGE: install_chromium.sh <chromiumos_image.img> <efi_part> <root_a_part> <state_part> [--skip-state]"
        exit 1
    fi
    
    local skip_state=0
    if [ "$5" == "--skip-state" ]; then
        skip_state=1
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
        echo
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
        echo
        echo "Failed copying files, may contain corrupted files."
        exit 1
    fi

    if [ ${skip_state} -ne 1 ]; then
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
            echo
            echo "Failed copying files, may contain corrupted files."
            exit 1
        fi
    else
        echo "Skipping STATE partition..."
    fi

    # Post installation
    echo -n "Fixing GRUB..."
    local hdd_uuid=`/sbin/blkid -s PARTUUID -o value "${hdd_root_a_part}"`
    local old_uuid=`cat "${local_efi_dir}/efi/boot/grub.cfg" | grep -m 1 "PARTUUID=" | awk '{print $15}' | cut -d'=' -f3`
    sed -i "s/${old_uuid}/${hdd_uuid}/" "${local_efi_dir}/efi/boot/grub.cfg"
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo
        echo "Failed fixing GRUB, please try fixing it manually."
        # exit 1 # This isn't a critical error
    fi
    
    echo -n "Updating partition data..."
    local hdd_efi_part_no=`echo ${hdd_efi_part} | sed 's/^[^0-9]\+\([0-9]\+\)$/\1/'`
    local hdd_root_a_part_no=`echo ${hdd_root_a_part} | sed 's/^[^0-9]\+\([0-9]\+\)$/\1/'`
    local hdd_state_part_no=`echo ${hdd_state_part} | sed 's/^[^0-9]\+\([0-9]\+\)$/\1/'`
    local write_gpt_path="${local_root_a}/usr/sbin/write_gpt.sh"
    # Remove unnecessart partitions & update properties
    cat "${write_gpt_path}" | grep -vE "_(KERN_(A|B|C)|2|4|6|ROOT_(B|C)|5|7|OEM|8|RESERVED|9|10|RWFW|11)" | sed \
    -e "s/^\(\s*PARTITION_NUM_EFI_SYSTEM=\)\"[0-9]\+\"$/\1\"${hdd_efi_part_no}\"/g" \
    -e "s/^\(\s*PARTITION_NUM_12=\)\"[0-9]\+\"$/\1\"${hdd_efi_part_no}\"/g" \
    -e "s/^\(\s*PARTITION_NUM_ROOT_A=\)\"[0-9]\+\"$/\1\"${hdd_root_a_part_no}\"/g" \
    -e "s/^\(\s*PARTITION_NUM_3=\)\"[0-9]\+\"$/\1\"${hdd_root_a_part_no}\"/g" \
    -e "s/^\(\s*PARTITION_NUM_STATE=\)\"[0-9]\+\"$/\1\"${hdd_state_part_no}\"/g" \
    -e "s/^\(\s*PARTITION_NUM_1=\)\"[0-9]\+\"$/\1\"${hdd_state_part_no}\"/g" \
    -e "s/\(\s*DEFAULT_ROOTDEV=\).*$/\1\"\"/" | tee "${write_gpt_path}" > /dev/null
    # -e "w ${write_gpt_path}" # Doesn't work on CrOS
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo
        echo "Failed updating partition data, please try fixing it manually."
        # exit 1 # This isn't a critical error
    fi
    echo -n "Fixing touchpad..."
    local tp_line=`grep -Fn "06cb:*" "${local_root_a}/etc/gesture/40-touchpad-cmt.conf" | sed 's/^\([0-9]\+\):.*$/\1/'`
    tp_line=$((tp_line+3)) # Add at line#21
    sed -i "${tp_line}a\    # Enable tap to click\n    Option          \"libinput Tapping Enabled\" \"1\"\n    Option          \"Tap Minimum Pressure\" \"0.1\"\n" "${local_root_a}/etc/gesture/40-touchpad-cmt.conf"
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo
        echo "Failed fixing touchpad, please try fixing it manually."
        # exit 1 # This isn't a critical error
    fi
    echo "Installation complete!"
    exit 0
}

# Exec part
main "$@"
