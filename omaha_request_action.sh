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

# These values are inside output_object, most of them doesn't need but still kept
ORA_payload_urls=()
ORA_package_name=   # Not included in the output_object, but required for us
ORA_version=
ORA_hash=
ORA_update_exists=
ORA_size=
ORA_more_info_url=
ORA_metadata_size=
ORA_metadata_signature=
ORA_prompt=
ORA_deadline=
ORA_max_days_to_scatter=
ORA_disable_p2p_for_downloading=
ORA_disable_p2p_for_sharing=
ORA_public_key_rsa=
ORA_max_failure_count_per_url=
ORA_is_delta_payload=
ORA_disable_payload_backoff=


#
# OmahaRequestAction::PerformAction
#
function PerformAction {
    curl -sL -X POST --data "$(GetRequestXml)" "${update_url_}" -o "${response}"
    if [ $? -ne 0 ]; then
      >&2 echo "Omaha request network transfer failed."
      exit 1
    fi
}


#
# OmahaRequestAction::ParseStatus
#
function ParseStatus {
    local status=`/usr/bin/xmllint --xpath 'string(//updatecheck/@status)' "${response}"`
    if [ "${status}" == "noupdate" ]; then
      >&2 echo "No update available."
      ORA_update_exists=false
      exit 1
    fi
    if [ "${status}" != "ok" ]; then
      >&2 echo "Unknown Omaha response status: ${status}"
      exit 1
    fi
}


#
# OmahaRequestAction::ParseUrls
#
function ParseUrls {
    local kUpdateUrlNodeXPath='/response/app/updatecheck/urls/url'
    /usr/bin/xmllint --xpath "${kUpdateUrlNodeXPath}" "${response}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      >&2 echo "XPath missing ${kUpdateUrlNodeXPath}"
      exit 1
    fi
    local c_urls=`/usr/bin/xmllint --xpath "count(${kUpdateUrlNodeXPath})" "${response}" 2> /dev/null`
    for (( i=1; i<=c_urls; i++ )); do
      local url=`/usr/bin/xmllint --xpath "string(${kUpdateUrlNodeXPath}[${i}]/@codebase)" "${response}" 2> /dev/null`
      if [ "${url}" == "" ]; then
        >&2 echo "Omaha Response URL has empty codebase"
        exit 1
      fi
      ORA_payload_urls+=("${url}")
    done
}


#
# OmahaRequestAction::ParsePackage
#
function ParsePackage {
    local kPackageNodeXPath='/response/app/updatecheck/manifest/packages/package'
    /usr/bin/xmllint --xpath "${kPackageNodeXPath}" "${response}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      >&2 echo "XPath missing ${kPackageNodeXPath}"
      exit 1
    fi
    ORA_package_name=`/usr/bin/xmllint --xpath "string(${kPackageNodeXPath}[1]/@name)" "${response}" 2> /dev/null`
    if [ "${ORA_package_name}" == "" ]; then
      >&2 echo "Omaha Response has empty package name"
      exit 1
    fi
    # Append package name
    local c_urls=${#ORA_payload_urls[@]}
    for (( i=0; i<c_urls; i++ )); do
        ORA_payload_urls[${i}]="${ORA_payload_urls[${i}]}${ORA_package_name}"
    done
    ORA_size=`/usr/bin/xmllint --xpath "string(${kPackageNodeXPath}[1]/@size)" "${response}" 2> /dev/null`
    # NOTE: hash_sha256 attribute under package is the output of sha256sum <file>
}


#
# OmahaRequestAction::ParseParams
#
function ParseParams {
    local kManifestNodeXPath='/response/app/updatecheck/manifest'
    local kActionNodeXPath='/response/app/updatecheck/manifest/actions/action'
    /usr/bin/xmllint --xpath "${kManifestNodeXPath}" "${response}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      >&2 echo "XPath missing ${kManifestNodeXPath}"
      exit 1
    fi
    ORA_version=`/usr/bin/xmllint --xpath "string(${kManifestNodeXPath}/@${kTagVersion})" "${response}" 2> /dev/null`
    if [ "${ORA_version}" == "" ]; then
      >&2 echo "Omaha Response does not have version in manifest!"
      exit 1
    fi
    /usr/bin/xmllint --xpath "${kActionNodeXPath}" "${response}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      >&2 echo "XPath missing ${kActionNodeXPath}"
      exit 1
    fi
    local c_action=`/usr/bin/xmllint --xpath "count(${kActionNodeXPath})" "${response}" 2> /dev/null`
    local postinstall_index=0
    for (( i=1; i<=c_action; i++ )); do
      local event=`/usr/bin/xmllint --xpath "string(${kActionNodeXPath}[${i}]/@event)" "${response}" 2> /dev/null`
      echo ${event}
      if [ "${event}" == "postinstall" ]; then
        postinstall_index=${i}
        break
      fi
    done
    if [ ${postinstall_index} -le 0 ]; then
      >&2 echo "Omaha Response has no postinstall event action"
      exit 1
    fi
    ORA_hash=`/usr/bin/xmllint --xpath "string(${kActionNodeXPath}[${postinstall_index}]/@${kTagSha256})" "${response}" 2> /dev/null`
    if [ "${ORA_hash}" == "" ]; then
      >&2 echo "Omaha Response has empty sha256 value"
      exit 1
    fi
    # TODO: Get the optional properties one by one.
}


#
# OmahaRequestAction::ParseResponse
#
function ParseResponse {
    /usr/bin/xmllint --xpath '/response/app/updatecheck' "${response}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      >&2 echo "XPath missing UpdateCheck NodeSet"
      exit 1
    fi
    # Date time and other not needed things are not included
    ParseStatus
    ParseUrls
    ParsePackage
    ParseParams
}


#
# utils::CalculateP2PFileId, Kept it though I may not provide any support for P2P
#
function CalculateP2PFileId {
    local encoded_hash=`cat "${ORA_hash}" | base64 2> /dev/null`
    echo "cros_update_size_${ORA_size}_hash_${encoded_hash}"
}


#
# OmahaRequestAction::TransferComplete
#
function TransferComplete {
    PerformAction  # Get update response, not part of the original method
    /usr/bin/xmllint "${response}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      >&2 echo "Omaha response not valid XML"
      exit 1
    fi
    # Don't need to check stupid ping values!
    ParseResponse  # set ORA_ vars
    ORA_update_exists=true
    # No need to check ShouldIgnoreUpdate()   
}
