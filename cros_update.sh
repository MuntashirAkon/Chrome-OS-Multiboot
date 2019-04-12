#!/bin/bash
# 2019 (c) Muntashir Al-Islam. All rights reserved.
# NOTE: TPM 1.2 fix is adapted from the Chromefy project and
# this copyright doesn't apply them.

if [ $UID -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

# Get installed version info
# Output: <milestone> <platform version> <cros version>
# Example: 72 11316.165.0 72.0.3626.122
function get_installed {
  local rel_info=`cat /etc/lsb-release | grep CHROMEOS_RELEASE_BUILDER_PATH | sed -e 's/^.*=\(.*\)-release\/R\(.*\)-\(.*\)$/\2 \3/'` # \1 = code name, eg. eve
  local cros_v=`/opt/google/chrome/chrome --version | sed -e 's/^[^0-9]\+\([0-9\.]\+\).*$/\1/'`
  echo "${rel_info} ${cros_v}"
}

# Get current (stable) version info
# $1: Code name, e.g. eve
# Output: <cros version> <platform version>
# Example: 72.0.3626.122 11316.165.0
function get_current {
  local code_name=$1
  local rel_info=`curl -sL https://cros-updates-serving.appspot.com/csv | grep -E "\b${code_name}\b" | sed 's/^[^,]\+,[^,]\+,\([^,]\+\),\([^,]\+\),.*$/\1 \2/'`
  echo $rel_info
}

# Check if there's an update
# $1: Code Name
# $2: Milestone
# $3: Platform version
# $4: Cros version
# NOTE: <update available> is 0 if there's an update, 1 otherwise
function update_available {
  local code_name=$1
  local remote_data=`get_current "${code_name}"`
  local ins_plarform=$3
  local rem_platform=`echo "${remote_data}" | awk '{print $2}'`

  if [ "${ins_plarform}" = "${rem_platform}" ]; then
    echo ""
    return 1
  else
    echo "https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_${rem_platform}_${code_name}_recovery_stable-channel_mp.bin.zip"
    return 0
  fi
}

#
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

function main {
    echo "Chrome OS Updater"
    echo "-----------------"
    echo
    echo "Reading cros_update.conf..."
    local conf_path="/usr/local/cros_update.conf"
    # Create cros_update.conf if not exists
    touch "${conf_path}"

    # cros_update.conf format:
    # ROOTA <ROOT-A UUID, lowercase>
    # ROOTB <ROOT-B UUID, lowercase>
    # EFI <EFI-SYSTEM UUID, lowercase>
    # RECOVERY <Code name, eg. eve>
    # TPM <optional, Code name of TPM 1.2 distro, eg. caroline>

    # Read cros_update.conf
    local root_a_uuid=`grep -E '\s*ROOTA' "${conf_path}" | awk '{print $2}'`
    local root_b_uuid=`grep -E '\s*ROOTB' "${conf_path}" | awk '{print $2}'`
    local efi_uuid=`grep -E '\s*EFI' "${conf_path}" | awk '{print $2}'`
    local recovery_code_name=`grep -E '\s*RECOVERY' "${conf_path}" | awk '{print $2}'`
    local tpm_code_name=`grep -E '\s*RECOVERY' "${conf_path}" | awk '{print $2}'`

    # Validate conf
    if [ "${root_a_uuid}" = "" ] || [ "${root_b_uuid}" = "" ] || [ "${recovery_code_name}" = "" ]; then
      echo "Invalid configuration, mandatory items missing."
      exit 1
    fi

    # Whether to apply TPM 1.2 fix
    local tpm_fix=true
    if [ "${tpm_code_name}" = "" ]; then
      tpm_fix=false
    fi

    # Convert uuid to /dev/sdXX
    local root_a_part=`sudo /sbin/blkid --uuid "${root_a_uuid}"`
    local root_b_part=`sudo /sbin/blkid --uuid "${root_b_uuid}"`

    # Current root, /dev/sdXX
    local c_root=`mount | grep -E '\s/\s' -m 1 | awk '{print $1}'`
    # Target root, /dev/sdXX
    local t_root=''
    if [ "${c_root}" = "${root_a_part}" ]; then
      t_root="${root_b_part}"
    else
      t_root="${root_a_part}"
    fi

    # Check for update
    echo "Checking for update..."
    local installed_data=`get_installed`
    local recovery_url=`update_available "${recovery_code_name}" ${installed_data}`
    if [ "${recovery_url}" = "" ]; then
      echo "No update available."
      exit 1
    fi
    local tpm_url=''
    if [ "${tpm_fix}" = true ]; then
      tpm_url=`update_available "${tpm_code_name}" ${installed_data}`
      if [ "${tpm_url}" = "" ]; then
        echo "No TPM update available."
        exit 1
      fi
    fi

    # Download update(s)
    echo "Downloading update(s)..."
    local user=`logname`
    if [ $? -ne 0 ]; then
        user="chronos"
    fi
    local root="/home/${user}"
    local tpm_img="${root}/${tpm_code_name}.bin"
    local recovery_img="${root}/${recovery_code_name}.bin"
    # FIXME: Ask to resume download if interrupted
    echo -n "Dowloading ${recovery_code_name}..."
    curl -\#L -o "${recovery_img}" "${recovery_url}"
    echo "Done."
    if [ "${tpm_fix}" = true ]; then
      echo -n "Dowloading ${tpm_code_name}..."
      curl -\#L -o "${tpm_img}" "${tpm_url}"
      echo "Done."
    fi
    
    # Update
    echo -n "Updating Chrome OS..."
    local hdd_root="${root}/root" # Target root
    local img_root_a="${root}/localroota"
    local tpm_root_a="${root}/tmproota"
    
    # Mount target partition
    cleanupIfAlreadyExists "${t_root}" "${hdd_root}"
    mount -o rw -t ext4 "${t_root}" "${hdd_root}"

    # Mount recovery image
    local img_disk=`/sbin/losetup --show -fP "${recovery_img}"`
    local img_root_a_part="${img_disk}p3"
    cleanupIfAlreadyExists "${img_root_a_part}" "${img_root_a}"
    mount -o ro "${img_root_a_part}" "${img_root_a}"

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
        # Remove TPM 2.0 services
        rm -rf "${hdd_root}"/etc/init/{attestationd,cr50-metrics,cr50-result,cr50-update,tpm_managerd,trunksd,u2fd}.conf
        # Copy TPM 1.2 file
        local tpm_disk=`/sbin/losetup --show -fP "${tpm_img}"`
        local tpm_root_a_part="${tpm_disk}p3"
        cleanupIfAlreadyExists "${tpm_root_a_part}" "${tpm_root_a}"
        mount -o ro "${tpm_root_a_part}" "${tpm_root_a}"
        cp -a "${tpm_root_a}"/etc/init/{chapsd,cryptohomed,cryptohomed-client,tcsd,tpm-probe}.conf "${hdd_root}"/etc/init/
	    cp -a "${tpm_root_a}"/etc/tcsd.conf "${hdd_root}"/etc/
	    cp -a "${tpm_root_a}"/usr/bin/{tpmc,chaps_client} "${hdd_root}"/usr/bin/
    	cp -a "${tpm_root_a}"/usr/lib64/libtspi.so{,.1{,.2.0}} "${hdd_root}"/usr/lib64/
	    cp -a "${tpm_root_a}"/usr/sbin/{chapsd,cryptohome,cryptohomed,cryptohome-path,tcsd} "${hdd_root}"/usr/sbin/
	    cp -a "${tpm_root_a}"/usr/share/cros/init/{tcsd-pre-start,chapsd}.sh "${hdd_root}"/usr/share/cros/init/
        cp -a "${tpm_root_a}"/etc/dbus-1/system.d/{Cryptohome,org.chromium.Chaps}.conf "${hdd_root}"/etc/dbus-1/system.d/
        if [ ! -f "${hdd_root}"/usr/lib64/libecryptfs.so ] && [ -f "${hdd_root}"/usr/lib64/libecryptfs.so ]; then
            cp -a "${tpm_root_a}"/usr/lib64/libecryptfs* "${hdd_root}"/usr/lib64/
            cp -a "${tpm_root_a}"/usr/lib64/ecryptfs "${hdd_root}"/usr/lib64/
        fi

    	# Add tss user and group
	    echo 'tss:!:207:root,chaps,attestation,tpm_manager,trunks,bootlockboxd' >> "${hdd_root}"/etc/group
	    echo 'tss:!:207:207:trousers, TPM and TSS operations:/var/lib/tpm:/bin/false' >> "${hdd_root}"/etc/passwd
	    echo "Done."
    fi

    # Update Grub
    echo -n "Updating GRUB..."
    local efi_dir="${root}/efi"
    local hdd_uuid=`/sbin/blkid -s PARTUUID -o value "${t_root}"`
    local old_uuid=`cat "${efi_dir}/efi/boot/grub.cfg" | grep -m 1 "PARTUUID=" | awk '{print $15}' | cut -d'=' -f3`
    sed -i "s/${old_uuid}/${hdd_uuid}/" "${efi_dir}/efi/boot/grub.cfg"
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo
        echo "Failed fixing GRUB, please try fixing it manually."
        exit 1
    fi
    
    echo -n "Updating partition data..."
    local hdd_root_part_no=`echo ${t_root} | sed 's/^[^0-9]\+\([0-9]\+\)$/\1/'`
    local write_gpt_path="${hdd_root}/usr/sbin/write_gpt.sh"
    # Remove unnecessart partitions & update properties
    cat "${write_gpt_path}" | grep -vE "_(KERN_(A|B|C)|2|4|6|ROOT_(B|C)|5|7|OEM|8|RESERVED|9|10|RWFW|11)" | sed -n \
    -e "s/^\(\s*PARTITION_NUM_ROOT_A=\)\"[0-9]\+\"$/\1\"${hdd_root_part_no}\"/g" \
    -e "s/^\(\s*PARTITION_NUM_3=\)\"[0-9]\+\"$/\1\"${hdd_root_part_no}\"/g" \
    -e "w ${write_gpt_path}"
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo
        echo "Failed updating partition data, please try fixing it manually."
        exit 1
    fi
}

main "$@"
exit 0
