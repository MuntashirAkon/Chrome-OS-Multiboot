#!/bin/bash
# Copyright (c) 2019 Muntashir Al-Islam. All rights reserved.
# NOTE: TPM 1.2 fix is adapted from the Chromefy project and
# this copyright doesn't apply them.

# USAGE: update_chromium.sh <recovery.bin> <root_a_part>  [<tpm_recovery.bin>]
# Example: update_chromium.sh ~/Downloads/chromeos_11647.104.3_eve_recovery_stable-channel_mp.bin sda5

# TODO: Run cleanup

if [ $UID -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

#
# Mount the partition if not already
# $1: Partition name e.g. /dev/sda11
# $2: Mount point
# $3: Readonly
function mountIfNotAlready {
    local part_name="$1"
    local mount_point="$2"
    if [ -e "${mount_point}" ]; then
        umount "${mount_point}" 2> /dev/null
        umount "${part_name}" 2> /dev/null
        rm -rf "${mount_point}"
    fi
    mkdir "${mount_point}"
    if [ $3 -eq 1 ]; then
        mount -o ro "${part_name}" "${mount_point}"
    else
        mount "${part_name}" "${mount_point}"
    fi
}

#
# The main function
# $1: recovery.bin
# $2: ROOT-A partition id, e.g. sda5
function main {
    if [ $# -ne 2 ] && [ $# -ne 3 ]; then
        echo "Invalid argument!"
        echo "USAGE: update_chromium.sh <recovery.bin> <root_a_part> [<tpm_recovery.bin>]"
        exit 1
    fi
    
    local fix_tpm=false
    local tpm_root_a_part=""
    if [ $# -eq 3 ]; then
       local img_tpm=$3
       local tpm_disk=`/sbin/losetup --show -fP "${img_tpm}"`
       tpm_root_a_part="${tpm_disk}p3"
       fix_tpm=true
    fi
    
    local recovery_img=$1
    local hdd_root_a_part="/dev/$2"

    local img_disk=`/sbin/losetup --show -fP "${recovery_img}"`
    local img_root_a_part="${img_disk}p3"

    local user=`logname`
    if [ $? -ne 0 ]; then
        user="chronos"
    fi
    local root="/home/${user}"
    local hdd_root_a="${root}/roota"
    local img_root_a="${root}/localroota"
    local tpm_root_a="${root}/tmproota"
    local backup="${root}/cros_backup"
    if [ -e "${backup}" ]; then
        rm -rf "${backup}"
    fi
    mkdir "${backup}"

    echo "ChromiumOS updater"
    echo "------------------"
    echo
    echo -n "Backing up necessary info..."
    # Mount partition#3 (ROOT-A) of the image
    mountIfNotAlready "${img_root_a_part}" "${img_root_a}" 1
    # Mount the ROOT-A partition of the HDD
    mountIfNotAlready "${hdd_root_a_part}" "${hdd_root_a}" 0
    # Backup important data
    # .. write_gpt.sh
    # .. 40-touchpad-cmt.conf
    # .. firmware
    # .. modules
    # TODO: /usr/lib64/{dri,va} as well?
    cp -a "${hdd_root_a}/usr/sbin/write_gpt.sh" \
        "${hdd_root_a}/etc/gesture/40-touchpad-cmt.conf" \
        "${hdd_root_a}/lib/firmware" \
        "${hdd_root_a}/lib/modules" "${backup}"
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo
        echo "Failed backing up data. Operation terminated for your own safety."
        exit 1
    fi

    echo -n "Installing new update..."
    # Delete all the contents of the hdd partition
    rm -Rf "${hdd_root_a}"/*
    # Copy files
    cp -a "${img_root_a}"/* "${hdd_root_a}" 2> /dev/null
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo
        echo "Failed copying files. You'll need to reinstall Chrome OS at this point."
        exit 1
    fi
    
    echo -n "Restoring backup..."
    # Remove firware and modules
    rm -rf "${hdd_root_a}/lib/firmware" "${hdd_root_a}/lib/modules"
    # Remove alsa-*.conf files
    rm -rf "${hdd_root_a}/etc/modprobe.d"/alsa*.conf
    # Restore backups
    cp -a "${backup}/firmware" "${backup}/modules" "${hdd_root_a}/lib"
    cp -a "${backup}/write_gpt.sh" "${hdd_root_a}/usr/sbin"
    cp -a "${backup}/40-touchpad-cmt.conf" "${hdd_root_a}/etc/gesture"
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo
        echo "Failed restoring backups. You'll need to reinstall Chrome OS at this point."
        exit 1
    fi
    
    # Fix TPM
    if [ "${fix_tpm}" = true ]; then
        echo -n "Fixing TPM..."
        # Remove TPM 2.0 services
        rm -rf "${hdd_root_a}"/etc/init/{attestationd,cr50-metrics,cr50-result,cr50-update,tpm_managerd,trunksd,u2fd}.conf
        # Copy TPM 1.2 file
        mountIfNotAlready "${tpm_root_a_part}" "${tpm_root_a}" 1
        cp -a "${tpm_root_a}"/etc/init/{chapsd,cryptohomed,cryptohomed-client,tcsd,tpm-probe}.conf "${hdd_root_a}"/etc/init/
	    cp -a "${tpm_root_a}"/etc/tcsd.conf "${hdd_root_a}"/etc/
	    cp -a "${tpm_root_a}"/usr/bin/{tpmc,chaps_client} "${hdd_root_a}"/usr/bin/
    	cp -a "${tpm_root_a}"/usr/lib64/libtspi.so{,.1{,.2.0}} "${hdd_root_a}"/usr/lib64/
	    cp -a "${tpm_root_a}"/usr/sbin/{chapsd,cryptohome,cryptohomed,cryptohome-path,tcsd} "${hdd_root_a}"/usr/sbin/
	    cp -a "${tpm_root_a}"/usr/share/cros/init/{tcsd-pre-start,chapsd}.sh "${hdd_root_a}"/usr/share/cros/init/
        cp -a "${tpm_root_a}"/etc/dbus-1/system.d/{Cryptohome,org.chromium.Chaps}.conf "${hdd_root_a}"/etc/dbus-1/system.d/
        if [ ! -f "${hdd_root_a}"/usr/lib64/libecryptfs.so ] && [ -f "${hdd_root_a}"/usr/lib64/libecryptfs.so ]; then
            cp -a "${tpm_root_a}"/usr/lib64/libecryptfs* "${hdd_root_a}"/usr/lib64/
            cp -a "${tpm_root_a}"/usr/lib64/ecryptfs "${hdd_root_a}"/usr/lib64/
        fi

    	# Add tss user and group
	    echo 'tss:!:207:root,chaps,attestation,tpm_manager,trunks,bootlockboxd' >> "${hdd_root_a}"/etc/group
	    echo 'tss:!:207:207:trousers, TPM and TSS operations:/var/lib/tpm:/bin/false' >> "${hdd_root_a}"/etc/passwd
	    echo "Done."
	    # TODO: Verify whether everything is copied as expected
    fi
    
    # Set SELinux to permissive
    sed '0,/enforcing/s/enforcing/permissive/' -i "${hdd_root_a}/etc/selinux/config"
    echo "Update complete!"
    exit 0
}

# Exec part
main "$@"
