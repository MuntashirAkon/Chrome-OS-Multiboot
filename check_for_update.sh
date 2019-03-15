#!/bin/bash
# 2019 (c) Muntashir Al-Islam. All rights reserved.

# Checks for update of your Chrome OS
# Run it on Crosh

# Get installed version info
# Output: <code name> <milestone> <platform version> <cros version>
# Example: eve 72 11316.165.0 72.0.3626.122
function get_installed {
  local rel_info=`cat /etc/lsb-release | grep CHROMEOS_RELEASE_BUILDER_PATH | sed -e 's/^.*=\(.*\)-release\/R\(.*\)-\(.*\)$/\1 \2 \3/'`
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
# Output: <code name> <platform version> <cros version> <update available>
# Example: eve 11316.165.0 72.0.3626.122
# NOTE: <update available> is 0 if there's an update, 1 otherwise
function update_available {
  local installed_data=$(get_installed)
  local code_name=`echo "${installed_data}" | awk '{print $1}'`
  local ins_plarform=`echo "${installed_data}" | awk '{print $3}'`
  local ins_cros=`echo "${installed_data}" | awk '{print $4}'`
  local remote_data=$(get_current "${code_name}")
  local rem_platform=`echo "${remote_data}" | awk '{print $2}'`
  local rem_cros=`echo "${remote_data}" | awk '{print $1}'`
  # This may not always work as expected!!
  # echo "[ '${ins_plarform}' = '${rem_platform}' ]"
  if [ "${ins_plarform}" = "${rem_platform}" ]; then
    echo "${code_name} ${ins_plarform} ${ins_cros} 1"
    return 1
  else
    echo "${code_name} ${rem_platform} ${rem_cros} 0"
    return 0
  fi
}

# main
function main {
  local update_info=$(update_available)
  local update_available=`echo "${update_info}" | awk '{print $4}'`
  local platform=`echo "${update_info}" | awk '{print $2}'`
  local code_name=`echo "${update_info}" | awk '{print $1}'`
  if [ $update_available -eq 0 ]; then
    echo "Update available!"
    echo "Download link: https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_${platform}_${code_name}_recovery_stable-channel_mp.bin.zip"
  else
    echo "No new update is available."
  fi
}

main "$@"
exit 0
