#!/bin/bash
# 2019 (c) Muntashir Al-Islam. All rights reserved.
# This file is converted from the original omaha_request_action.cc
# located at https://chromium.googlesource.com/chromiumos/platform/update_engine/+/refs/heads/master/omaha_request_action.cc
# fetched at 28 Jun 2019
# NOTE: The conversion is a gradual process, it may take some time

. omaha_request_params.sh

# List of custom pair tags that we interpret in the Omaha Response:
kTagDeadline="deadline"
kTagDisablePayloadBackoff="DisablePayloadBackoff"
kTagVersion="version"
# Deprecated: "IsDelta"
kTagIsDeltaPayload="IsDeltaPayload"
kTagMaxFailureCountPerUrl="MaxFailureCountPerUrl"
kTagMaxDaysToScatter="MaxDaysToScatter"
# Deprecated: "ManifestSignatureRsa"
# Deprecated: "ManifestSize"
kTagMetadataSignatureRsa="MetadataSignatureRsa"
kTagMetadataSize="MetadataSize"
kTagMoreInfo="MoreInfo"
# Deprecated: "NeedsAdmin"
kTagPrompt="Prompt"
kTagSha256="sha256"
kTagDisableP2PForDownloading="DisableP2PForDownloading"
kTagDisableP2PForSharing="DisableP2PForSharing"
kTagPublicKeyRsa="PublicKeyRsa"

# Global var
kGupdateVersion="ChromeOSUpdateEngine-0.1.0.0"


#
# GetOsXml
#
function GetOsXml {
  echo "    <os version=\"${os_version_}\" platform=\"${os_platform_}\" sp=\"${os_sp_}\"></os>"
}


#
# GetAppXml
#
function GetAppXml {
    local app_body="<ping active=\"1\" a=\"-1\" r=\"-1\"></ping>
        <updatecheck targetversionprefix=\"\"></updatecheck>"  # For now, I'm getting tired
    local app_versions="version=\"${app_version_}\""  # The conditional in the original code isn't use since it pw doesn't work
    local app_channels="track=\"${download_channel_}\""
    if ! [ "${current_channel_}" == "${download_channel_}" ]; then
        app_channels="${app_channels} from_track=\"${current_channel_}\" "
    fi
    local install_date_in_days_str=  # installdate="%d" or nothing
    cat <<EOL
    <app appid="$(GetAppId)" ${app_versions} ${app_channels} lang="${app_lang_}" board="${os_board_}" hardware_class="${hwid_}" delta_okay="${delta_okay_}" fw_version="${fw_version_}" ec_version="${ec_version_}" ${install_date_in_days_str}>
        ${app_body}
    </app>
EOL
}


#
# GetRequestXml
#
function GetRequestXml {
    local os_xml=$(GetOsXml)
    local app_xml=$(GetAppXml)
    local install_source=
    if [ ${interactive_} ]; then
      install_source='ondemandupdate'
    else
      install_source='scheduler'
    fi
    
    cat <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0" version="${kGupdateVersion}" updaterversion="${kGupdateVersion}" installsource="${install_source}" ismachine="1">
${os_xml}
${app_xml}
</request>
EOL
}

response='/tmp/response.xml'

function OmahaRequestAction {
    curl -sL -X POST --data "$(GetRequestXml)" "${update_url_}" -o "${response}"
}


# We are on our own now.
#OmahaRequestAction  # Get update response

# Check for update
grep 'event="update"' "${response}" > /dev/null

if [ $? -ne 0 ]; then
  echo "No update is available."
  exit 1
fi

# Get required info
channel_url=`sed 's/.*codebase="\([^"]\+\).*/\1/' "${response}" 2> /dev/null`
file_name=`sed 's/.*run="\([^"]\+\).*/\1/' "${response}" 2> /dev/null`
file_url="${channel_url}${file_name}"
file_size=`sed 's/.*size="\([^"]\+\).*/\1/' "${response}" 2> /dev/null`
file_size=`bc -l <<< "scale=2; ${file_size}/1073741824"`
rem_platform=`sed 's/.*ChromeOSVersion="\([^"]\+\).*/\1/' "${response}" 2> /dev/null`

# echo "Downloading ${file_name} (${file_size} GB)..."
