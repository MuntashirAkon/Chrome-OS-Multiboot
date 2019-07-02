#!/bin/bash
# 2019 (c) Muntashir Al-Islam. All rights reserved.
# This file is converted from the original omaha_request_action.cc
# located at https://chromium.googlesource.com/chromiumos/platform/update_engine/+/refs/heads/master/omaha_response_handler_action.cc
# fetched at 30 Jun 2019
# NOTE: The conversion is a gradual process, it may take some time

. omaha_request_action.sh

kDeadlineFile="/tmp/update-check-response-deadline"
kCrosUpdateConf="/usr/local/cros_update.conf" # Our conf file
# cros_update.conf format:
# ROOTA='<ROOT-A UUID>'
# ROOTB='<ROOT-B UUID>'
# EFI='<EFI-SYSTEM UUID>'
# TPM=true/false (default: true)


# install_plan assoc array, refer to ./payload_consumer/install_plan.cc
declare -A install_plan


function GetCurrentSlot {  # Actually get current /dev/sdXX
    mount | grep -E '\s/\s' -m 1 | awk '{print $1}' 2> /dev/null
}


# $1: Label
function FindPartitionByLabel {
    local label=$1
    /sbin/blkid -o device -L "${label}"
}


# Get partition by UUID, if not found, try using label
# $1: UUID
# $2: Label
function GetPartitionFromUUID {
    local uuid=$1  # Can be empty
    local label=$2  # Not empty
    local part=
    if [ "$uuid" == "" ]; then
      >&2 echo "Empty UUID for ${label}, default will be used."
      part=$(FindPartitionByLabel "${label}")
    else
      part=`/sbin/blkid --uuid "${uuid}"`
      if [ "${part}" == "" ]; then
        >&2 echo "Given UUID for ${label} not found, default will be used."
        part=$(FindPartitionByLabel "${label}")
      fi
    fi
    echo "${part}"
}


#
# OmahaResponseHandlerAction::PerformAction
#
function OmahaResponseHandlerAction_PerformAction {
    OmahaRequestAction_TransferComplete  # Make the request, probably need to move somewhere else
    if ! [ ${ORA_update_exists} ]; then
      >&2 echo "There are no updates. Aborting."
      exit 1
    fi
    # The whole download_update should go here, but how? using install_plan
    # PayloadState::GetCurrentURL is not necessary right now.
    # We're only going to use the first item
    install_plan['download_url']="${ORA_payload_urls[1]}"
    install_plan['version']="${ORA_version}"
    install_plan['system_version']=  # TODO
    # No p2p support right now
    install_plan['payload_size']="${ORA_size}"  # Renamed to payloads.size
    install_plan['payload_hash']="${ORA_hash}"  # Renamed to payloads.hash
    install_plan['metadata_size']="${ORA_metadata_size}"  # Renamed to payloads.metadata_size
    install_plan['metadata_signature']="${ORA_metadata_signature}"  # Renamed to payloads.metadata_signature
    install_plan['public_key_rsa']="${ORA_public_key_rsa}"
    install_plan['hash_checks_mandatory']=false  # since no p2p support
    install_plan['is_resume']=true  # Since we're using curl with -C option
    install_plan['is_full_update']="${ORA_is_delta_payload}"  # Renamed to payloads.type = is_delta_payload ? kDelta : kFull
    install_plan['kernel_install_path']=  # We don't need this
    install_plan['powerwash_required']=false  # For now
    # target and source slots: we use them as /dev/sdXX loaded from cros_update.conf
    # Details specification: http://www.chromium.org/chromium-os/chromiumos-design-docs/disk-format
    install_plan['target_slot']=  # For our case, it's actually the target partition
    install_plan['source_slot']=  # For our case, it's actually the source partition
    install_plan['efi_slot']=  # Not included in the original install_plan, but required for us
    # Create cros_update.conf if not exists
    touch "${kCrosUpdateConf}"
    # Use the conf
    source "${kCrosUpdateConf}"
    # Set the values of the slot, if not found find them
    # Again, we don't need is_install since install won't be supported
    local root_a=$(GetPartitionFromUUID "${ROOTA}" 'ROOT-A')
    local root_b=$(GetPartitionFromUUID "${ROOTB}" 'ROOT-B')
    local current_slot=$(GetCurrentSlot)
    install_plan['source_slot']=${current_slot}
    if [ "${current_slot}" == "${root_a}" ]; then
      install_plan['target_slot']=${root_b}
    elif [ "${current_slot}" == "${root_b}" ]; then
      install_plan['target_slot']=${root_a}
    else
      >&2 echo "No valid target partition is found. Update aborted."
      exit 1
    fi
    install_plan['efi_slot']=$(GetPartitionFromUUID "${EFI}" 'EFI-SYSTEM')
    
    install_plan['is_rollback']=true  # No functionality
    install_plan['powerwash_required']=false  # No functionality
    # No need for deadline since we're installing right away
}


# Check environment variables
#OmahaResponseHandlerAction_PerformAction
#( set -o posix ; set )
