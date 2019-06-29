#!/bin/bash
# 2019 (c) Muntashir Al-Islam. All rights reserved.
# This file is converted from the original omaha_request_action.cc
# located at https://chromium.googlesource.com/chromiumos/platform/update_engine/+/refs/heads/master/omaha_response_handler_action.cc
# fetched at 30 Jun 2019
# NOTE: The conversion is a gradual process, it may take some time

. omaha_request_action.sh

kDeadlineFile="/tmp/update-check-response-deadline"

#
# OmahaResponseHandlerAction::PerformAction
#
function OmahaResponseHandlerAction_PerformAction {
    TransferComplete  # Make the request
    if ! [ ${ORA_update_exists} ]; then
      >&2 echo "There are no updates. Aborting."
      exit 1
    fi
    # The whole download_update should go here, but how?
}


# We are on our own now.

function download_update {
    TransferComplete
    # Update available
    # Get required info
    local channel_url=`sed 's/.*codebase="\([^"]\+\).*/\1/' "${response}" 2> /dev/null`
    local file_name="${ORA_package_name}"
    local file_url="${channel_url}${file_name}"
    local file_size=`bc -l <<< "scale=2; ${ORA_size}/1073741824"`
    
    >&2 echo "Update available."
    >&2 echo "Downloading ${file_name} (${file_size} GB)..."
    
    local user=`logname 2> /dev/null`
    if [ "${user}" == "" ]; then user='chronos/user'; fi
    local root="/home/${user}"
    local file_loc="${root}/${file_name}"
    curl -\#L -o "${file_loc}" "${file_url}" -C -
    # TODO: match checksum
    if [ $? -ne 0 ]; then
        >&2 echo "Failed to download ${file_name}. Try again."
        exit 1
    fi
    echo "${file_loc}"
    exit 0
}


# TransferComplete

# Check environment variables
( set -o posix ; set )
