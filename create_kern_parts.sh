#!/bin/bash
# 2019 (c) Muntashir Al-Islam. All rights reserved.

# A standalone script that finds free space to create KERN-A and KERN-B
# Refs:
# https://chromium.googlesource.com/chromiumos/platform/vboot_reference/+/refs/heads/master/scripts/image_signing/common_minimal.sh
# https://chromium.googlesource.com/chromiumos/platform/vboot_reference/+/refs/heads/master/scripts/image_signing/make_dev_ssd.sh

# Get script directory 
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

GPT="/usr/bin/cgpt"
if ! [ -f $GPT ]; then
  GPT="\"$SCRIPT_DIR\"/cgpt"
fi

# Find the block size of a device in bytes
# Args: DEVICE (e.g. /dev/sda)
# Return: block size in bytes
function blocksize {
  local output=''
  local path="$1"
  if [ -b "${path}" ]; then
    local dev="${path##*/}"
    local sys="/sys/block/${dev}/queue/logical_block_size"
    output="$(cat "${sys}" 2>/dev/null)"
  fi
  echo "${output:-512}"
}

# Read GPT table to find the starting location of a specific partition.
# Args: DEVICE PARTNUM
# Return: offset (in sectors) of partition PARTNUM
function partoffset {
  $GPT show -b -i $2 $1
}

# Read GPT table to find the size of a specific partition.
# Args: DEVICE PARTNUM
# Return: size (in sectors) of partition PARTNUM
function partsize {
  $GPT show -s -i $2 $1
}

# Find the size of a device in bytes
# Args: DEVICE (e.g. /dev/sda)
# Return: size in bytes
function devsize {
  local output=''
  local path="$1"
  if [ -b "${path}" ]; then
    local dev="${path##*/}"
    local sys="/sys/block/${dev}/size"
    output="$(cat "${sys}" 2>/dev/null)"
  fi
  echo "${output}"
}

# Load partition data
# Args: DEVICE (e.g. /dev/sda)
# Return:
#  Array with columns accessible via awk
#  Column format: <1:start> <2:end> <3:size> <4:part_no> <5:free_space_after>
function load_partitions {
    local device=$1
    local partitions=
    # Load partitions, sorted by start block in asc order
    mapfile -t partitions < <($GPT show -q "${device}" | awk '{print $1, $1 + $2, $2, $3}' | sort -k 1 -n)
    local gpt_start_block=40  # Not checked as it was assumed that the first partition is ESP
    local gpt_end_block=$(( $(devsize $device) - 40 ))
    local c_parts=$(( ${#partitions[@]} - 1 ))
    for (( i=0; i<$c_parts; i++ )); do
      local this_part_end=`echo ${partitions[${i}]} | awk '{print $2}'`
      local next_part_begin=`echo ${partitions[$((i+1))]} | awk '{print $1}'`
      echo "${partitions[${i}]} $(( $next_part_begin - $this_part_end ))"
    done
    local last_part_end=`echo ${partitions[${c_parts}]} | awk '{print $2}'`
    echo "${partitions[${c_parts}]} $(( $gpt_end_block - $last_part_end ))"
}

# Filter usable unallocated space
# Args: DEVICE SIZE (e.g. /dev/sda 16000)
# If SIZE is greater than 1 GB, add 128 MB with it (maybe several times
# depending on how many partition is being made inside this block)
# before supplying as argument. It is better to create partition one by
# one to prevent any inconistencies: call this function, create a new
# partition, call this function again, create another partition, and so on.
# Return:
#  Array with columns accessible via awk
#  Column format: <1:start> <2:end> <3:size> <4:part_no> <5:free_space_after> <6:need_128MB>
function filter_usable_spaces {
    local device=$1
    local size=$2
    local partitions=
    # load partitions, sorted by amount of free space after the part in asc order
    mapfile -t partitions < <(load_partitions $device)
    local bs="$(blocksize "${device}")"
    # Apple recommends 128 MB space after > 1 GB partitions
    # More at https://www.rodsbooks.com/gdisk/advice.html
    local preserved_size=$(( 128 * 1024 * 1024 / bs ))
    local total_size=$(( preserved_size + size ))
    local one_gb=$(( 1024 * 1024 * 1024 / bs ))
    local c_parts=${#partitions[@]}
    for (( i=0; i<$c_parts; i++ )); do
      local free_space=`echo ${partitions[${i}]} | awk '{print $5}'`
      local part_size=`echo ${partitions[${i}]} | awk '{print $3}'`
      # These checkings may not be enough for some cases.
      # One example is that the free space below the ESP of Windows and
      # above Microsoft reserved partition cannot be used.
      if [ $part_size -ge $one_gb ]; then
        if [ $free_space -ge $total_size ]; then
            echo "${partitions[${i}]} 1"
        fi
      else
        if [ $free_space -ge $size ]; then
            echo "${partitions[${i}]} 0"
        fi
      fi
    done
}


function main {
    local root_dev="$1"
    if ! [ $root_dev ]; then
      root_dev=`rootdev -s -d 2> /dev/null`
    fi
    if ! ( [ $root_dev ] && [ -e $root_dev ] ); then
      >&2 echo "Root device doesn't exist!"
      exit 1
    fi
    local bs="$(blocksize "${root_dev}")"
    local kernel_size=$(( 8000 * 1024 / bs ))  # 8000 KB minimum
    # Create Kernel partitions
    >&2 echo "Creating KERN-A..."
    if $GPT show "$root_dev" | grep -q "KERN-A"; then
      >&2 echo "KERN-A partition exists!"
    else
      local partitions=
      # load partitions, sorted by amount of free space after the part in desc order
      mapfile -t partitions < <(filter_usable_spaces $root_dev $kernel_size | sort -k 5 -r -n)
      $GPT add -b $(echo ${partitions[0]} | awk '{print $2}') -s $kernel_size -t kernel -l "KERN-A" "$root_dev"
      if [ $? -ne 0 ]; then
        >&2 echo "Failed to create KERN-A partition!"
      fi
    fi
    >&2 echo "Creating KERN-B..."
    if $GPT show "$root_dev" | grep -q "KERN-B"; then
      >&2 echo "KERN-B partition exists!"
    else
      local partitions=
      # load partitions, sorted by amount of free space after the part in desc order
      mapfile -t partitions < <(filter_usable_spaces $root_dev $kernel_size | sort -k 5 -r -n)
      $GPT add -b $(echo ${partitions[0]} | awk '{print $2}') -s $kernel_size -t kernel -l "KERN-B" "$root_dev"
      if [ $? -ne 0 ]; then
        >&2 echo "Failed to create KERN-B partition!"
      fi
    fi
}

main "$@"
exit 0