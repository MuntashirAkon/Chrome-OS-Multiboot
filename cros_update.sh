#!/bin/bash
# 2019 (c) Muntashir Al-Islam. All rights reserved.
# NOTE: TPM 1.2 fix is adapted from the Chromefy project and
# this copyright doesn't apply them.


if [ $UID -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi


# import download_action.sh
. download_action.sh


# Cleanup the mount point if exists
# $1: Partition name e.g. /dev/sda11
# $2: Mount point
function cleanupIfAlreadyExists {
    local part_name="$1"
    local mount_point="$2"
    if [ -e "${mount_point}" ]; then
        umount "${mount_point}" 2> /dev/null
        umount "${part_name}" 2> /dev/null
        rm -rf "${mount_point}"
    fi
    mkdir "${mount_point}"
}


#
# The main function
#
function main {
    echo "Chrome OS Updater"
    echo "-----------------"
    echo
    echo "Sorry, the script is incomplete! Wait until I implement it properly."
    exit 1
    echo "Reading cros_update.conf..."
    # Create cros_update.conf if not exists
    touch "${kCrosUpdateConf}"

    # cros_update.conf format:
    # ROOTA='<ROOT-A UUID>'
    # ROOTB='<ROOT-B UUID>'
    # EFI='<EFI-SYSTEM UUID>'
    # TPM=true/false

    # Read cros_update.conf
    source "${kCrosUpdateConf}"

    # Validate conf
    if [ "${ROOTA}" = "" ] || [ "${ROOTB}" = "" ]; then
      echo "Invalid configuration, mandatory items missing."
      exit 1
    fi

    # Whether to apply TPM 1.2 fix
    local tpm_fix=${TPM}

    # Convert uuid to /dev/sdXX
    local root_a_part=`/sbin/blkid --uuid "${ROOTA}"`
    local root_b_part=`/sbin/blkid --uuid "${ROOTB}"`
    local efi_part=`/sbin/blkid --uuid "${EFI}"`

    # Current root, /dev/sdXX
    local c_root=`mount | grep -E '\s/\s' -m 1 | awk '{print $1}'`
    # Target root, /dev/sdXX
    local t_root=
    if [ "${c_root}" = "${root_a_part}" ]; then
      t_root="${root_b_part}"
    else
      t_root="${root_a_part}"
    fi

    # Set root directory
    local user=`logname 2> /dev/null`
    if [ "${user}" == "" ]; then user='chronos/user'; fi
    local root="/home/${user}"

    # Check for update & download them
    echo "Checking for update..."
    local recovery_img="$(DownloadAction_PerformAction)"
    if [ "${recovery_img}" == "" ]; then exit 1; fi

    local swtpm_tar="${root}/swtpm.tar"
    if [ "${tpm_fix}" == true ]; then
      echo "Downloading swtpm.tar..."
      curl -\#L -o "${swtpm_tar}" "https://github.com/imperador/chromefy/raw/master/swtpm.tar"
    fi

    # Update
    echo -n "Updating Chrome OS..."
    local hdd_root="${root}/target_root"  # Target root dir
    local img_root_a="${root}/img_root"  # Current root dir
    local swtpm="${root}/swtpm"  # swtpm dir
    local efi_dir="${root}/efi"
    
    # Mount target partition
    cleanupIfAlreadyExists "${t_root}" "${hdd_root}"
    mount -o rw -t ext4 "${t_root}" "${hdd_root}"
    # Mount recovery image
    local img_disk=`/sbin/losetup --show -fP "${recovery_img}"`
    local img_root_a_part="${img_disk}p3"
    cleanupIfAlreadyExists "${img_root_a_part}" "${img_root_a}"
    mount -o ro "${img_root_a_part}" "${img_root_a}"
    # Mount EFI partition
    cleanupIfAlreadyExists "${efi_part}" "${efi_dir}"
    mount -o rw "${efi_part}" "${efi_dir}"

    # Copy all the files from image to target partition
    rm -rf "${hdd_root}"/*
    cp -a "${img_root_a}"/* "${hdd_root}" 2> /dev/null
    
    # Copy modified files from current partition to target partition
    rm -rf "${hdd_root}/lib/firmware" "${hdd_root}/lib/modules"
    rm -rf "${hdd_root}/etc/modprobe.d"/alsa*.conf
    cp -a "/lib/firmware" "/lib/modules" "${hdd_root}/lib"
    cp -a "/usr/sbin/write_gpt.sh" "${hdd_root}/usr/sbin"
    cp -a "/etc/gesture/40-touchpad-cmt.conf" "${hdd_root}/etc/gesture"
    cp -a "/etc/chrome_dev.conf" "${hdd_root}/etc"
    cp -a "/etc/init/mount-internals.conf" "${hdd_root}/etc/init" 2> /dev/null
    echo "Done."
    # Apply TPM fix
    if [ "${tpm_fix}" = true ]; then
      echo -n "Fixing TPM..."
      # Extract swtpm.tar
      tar -xf "${swtpm_tar}" -C "${root}"
      # Copy necessary files
        cp -a "${swtpm}"/usr/sbin/* "${hdd_root}/usr/sbin"
        cp -a "${swtpm}"/usr/lib64/* "${hdd_root}/usr/lib64"
        # Symlink libtpm files
        cd "${hdd_root}/usr/lib64"
        ln -s libswtpm_libtpms.so.0.0.0 libswtpm_libtpms.so.0
        ln -s libswtpm_libtpms.so.0 libswtpm_libtpms.so
        ln -s libtpms.so.0.6.0 libtpms.so.0
        ln -s libtpms.so.0 libtpms.so
        ln -s libtpm_unseal.so.1.0.0 libtpm_unseal.so.1
        ln -s libtpm_unseal.so.1 libtpm_unseal.so
        # Start at boot (does this necessary?)
        cat > "${hdd_root}/etc/init/_vtpm.conf" <<EOL
    start on started boot-services

    script
        mkdir -p /var/lib/trunks
        modprobe tpm_vtpm_proxy
        swtpm chardev --vtpm-proxy --tpm2 --tpmstate dir=/var/lib/trunks --ctrl type=tcp,port=10001
        swtpm_ioctl --tcp :10001 -i
    end script
EOL
        echo "Done."
    fi

    # Update Grub FIXME
    echo -n "Updating GRUB..."
    local hdd_uuid=`/sbin/blkid -s PARTUUID -o value "${t_root}"`
    local old_uuid=`cat "${efi_dir}/efi/boot/grub.cfg" | grep -m 1 "PARTUUID=" | awk '{print $15}' | cut -d'=' -f3`
    sed -i "s/${old_uuid}/${hdd_uuid}/" "${efi_dir}/efi/boot/grub.cfg"
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo
        echo "Failed fixing GRUB, please try fixing it manually."
        # exit 1
    fi
    
    echo -n "Updating partition data..."
    local hdd_root_part_no=`echo ${t_root} | sed 's/^[^0-9]\+\([0-9]\+\)$/\1/'`
    local write_gpt_path="${hdd_root}/usr/sbin/write_gpt.sh"
    # Remove unnecessary partitions & update properties
    cat "${write_gpt_path}" | grep -vE "_(KERN_(A|B|C)|2|4|6|ROOT_(B|C)|5|7|OEM|8|RESERVED|9|10|RWFW|11)" | sed -n \
    -e "s/^\(\s*PARTITION_NUM_ROOT_A=\)\"[0-9]\+\"$/\1\"${hdd_root_part_no}\"/g" \
    -e "s/^\(\s*PARTITION_NUM_3=\)\"[0-9]\+\"$/\1\"${hdd_root_part_no}\"/g" \
     | tee "${write_gpt_path}" > /dev/null
    # -e "w ${write_gpt_path}" # doesn't work on CrOS
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo
        echo "Failed updating partition data, please try fixing it manually."
        # exit 1
    fi
}

main "$@"
exit 0
