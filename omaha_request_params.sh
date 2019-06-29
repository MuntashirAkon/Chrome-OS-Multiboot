#!/bin/bash
# 2019 (c) Muntashir Al-Islam. All rights reserved.
# This file is converted from the original omaha_request_params.cc
# located at https://chromium.googlesource.com/chromiumos/platform/update_engine/+/refs/heads/master/omaha_request_params.cc
# fetched at 28 Jun 2019
# The only modification is the use $CUSTOM_RELEASE_TRACK

# Load environment variables from lsb-release
lsb_release='/etc/lsb-release'
CHROMEOS_AUSERVER=`grep 'CHROMEOS_AUSERVER' "${lsb_release}" | sed 's/.*=\(.*\)/\1/' 2> /dev/null`
CHROMEOS_BOARD_APPID=`grep 'CHROMEOS_BOARD_APPID' "${lsb_release}" | sed 's/.*=\(.*\)/\1/' 2> /dev/null`
CHROMEOS_CANARY_APPID=`grep 'CHROMEOS_CANARY_APPID' "${lsb_release}" | sed 's/.*=\(.*\)/\1/' 2> /dev/null`
CHROMEOS_RELEASE_APPID=`grep 'CHROMEOS_RELEASE_APPID' "${lsb_release}" | sed 's/.*=\(.*\)/\1/' 2> /dev/null`
CHROMEOS_RELEASE_BOARD=`grep 'CHROMEOS_RELEASE_BOARD' "${lsb_release}" | sed 's/.*=\(.*\)/\1/' 2> /dev/null`
CHROMEOS_RELEASE_NAME=`grep 'CHROMEOS_RELEASE_NAME' "${lsb_release}" | sed 's/.*=\(.*\)/\1/' 2> /dev/null`
CHROMEOS_RELEASE_TRACK=`grep 'CHROMEOS_RELEASE_TRACK' "${lsb_release}" | sed 's/.*=\(.*\)/\1/' 2> /dev/null`
CHROMEOS_RELEASE_VERSION=`grep 'CHROMEOS_RELEASE_VERSION' "${lsb_release}" | sed 's/.*=\(.*\)/\1/' 2> /dev/null`
CHROMEOS_IS_POWERWASH_ALLOWED=

# Global vars
kAppId="{87efface-864d-49a5-9bb3-4b050a7c227a}"
kOsPlatform="${CHROMEOS_RELEASE_NAME}"
kOsVersion="Indy"
kProductionOmahaUrl="https://tools.google.com/service/update2"
kUpdateChannelKey="${CHROMEOS_RELEASE_TRACK}"
kIsPowerwashAllowedKey="${CHROMEOS_IS_POWERWASH_ALLOWED}"
kChannelsByStability=(
    # This list has to be sorted from least stable to most stable channel.
    "canary-channel"
    "dev-channel"
    "beta-channel"
    "stable-channel"
)


#
# OmahaRequestDeviceParams::GetMachineType
#
function GetMachineType {
  echo `uname --machine`
}


#
# Taken from OmahaRequestDeviceParams::Init
#
os_platform_=${kOsPlatform}
os_version_=${kOsVersion}
app_version_="${CHROMEOS_RELEASE_VERSION}"
os_sp_="${app_version_}_$(GetMachineType)"
os_board_="${CHROMEOS_RELEASE_BOARD}"
release_app_id="${CHROMEOS_RELEASE_APPID}"
board_app_id_="${CHROMEOS_BOARD_APPID}"
canary_app_id_="${CHROMEOS_CANARY_APPID}"
app_lang_="en-US"
hwid_=  # We don't have this
fw_version_=  # We don't have this
ec_version_=  # We don't have this
current_channel_="${kUpdateChannelKey}"
target_channel_="${kUpdateChannelKey}"
# Use `export CUSTOM_RELEASE_TRACK={dev|canary|beta|stable}-channel` to switch channels
if [ "${CUSTOM_RELEASE_TRACK}" ]; then target_channel_="${CUSTOM_RELEASE_TRACK}"; fi
if [ "${current_channel_}" == "${target_channel_}" ]; then
  if [ -e "/.nodelta" ]; then
    delta_okay_="false";
  else
    delta_okay_="true"
  fi
else
  delta_okay_="false"
fi
update_url_="${CHROMEOS_AUSERVER}"
if [ "${update_url_}" == "" ]; then update_url_="${kProductionOmahaUrl}"; fi
interactive_=true
#
# OmahaRequestDeviceParams::UpdateDownloadChannel
#
download_channel_="${target_channel_}"


#
# OmahaRequestParams::GetAppId
#
function GetAppId {
  if [ "${download_channel_}" == "canary-channel" ]; then
    echo "${canary_app_id_}"
  else
    echo "${board_app_id_}"
  fi
}
