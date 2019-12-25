# Chrome OS Multiboot

My approach to multiboot Chrome OS or Chromium OS on regular machines.

> If you're looking for updating your Chrome OS installation, the project is move [here](https://github.com/MuntashirAkon/chrome_os_updater).

<details>
 <summary>Index</summary>
 
- [Multiboot guide](#multiboot-guide)
  * [Prerequisites](#prerequisites)
  * [Process](#process)
    - [Creating partitions](#creating-partitions)
    - [Converting Chromium OS to Chrome OS](#converting-chromium-os-to-chrome-os)
    - [Installing on HDD](#installing-on-hdd)
- [Updating Chrome OS](#updating-chrome-os)
    - [Want to update natively?](#want-to-update-natively)
- [Mounting internal partitions](#mounting-internal-partitions)
- [References](#references)
</details>

## Multiboot guide

### Prerequisites
1. A Linux distro e.g. Ubuntu, Mint, etc. (may need installing since the files to be downloaded need a lot of space)
2. [chromefy.h](https://github.com/imperador/chromefy/releases)
3. [swtpm.tar](https://github.com/imperador/chromefy/raw/master/swtpm.tar) - To solve TPM related problem on modern PCs
4. @arnoldthebat's [Chromium OS Special build](https://chromium.arnoldthebat.co.uk/index.php?dir=special&order=modified&sort=desc) (R74 or later)
5. [Eve or similar recovery file](https://cros-updates-serving.appspot.com) matching your hardware specifications
  (check [here](https://www.chromium.org/chromium-os/developer-information-for-chrome-os-devices) for more info)
6. [install_chromium.sh](https://raw.githubusercontent.com/MuntashirAkon/Chrome-OS-Multiboot/master/install_chromium.sh)

If you're going to install Chromium OS (not Chrome OS), you don't need 2, 3, and 5 prerequisites.

### Process

#### Creating partitions

You'll need to create 3/4 partitions in GPT mode:
1. **EFI-SYSTEM**: Type `FAT16` (32 MB) [assume, the device id is `sda4`]
2. **ROOT-A**: Type `EXT2` (around 5 GB) [assume `sda5`]
3. **ROOT-B**: Type `EXT2` (around 5 GB) [assume `sda7`] (Optional if you don't want to update Chrome OS natively)
4. **STATE**: Type `EXT4` (this is where user files will be kept, so the size of the partition depends on you;
   20 GB recommended) [assume `sda6`]

#### Converting Chromium OS to Chrome OS

_[Skip this step if you are not going to install Chrome OS, just Chromium OS]_

- Download the prequisites at `~/Downloads/ChromeOS` and extract them there as well.
  Don't delete the zipped files yet (as something might be broken). The file structure should look something like this:
  ```
  Camd64OS_R72-11316.B-Special.7z
  chromefy.sh
  install_chromium.sh
  chromeos_11316.165.0_eve_recovery_stable-channel_mp.bin
  chromeos_11316.165.0_eve_recovery_stable-channel_mp.bin.zip
  chromiumos_image.img
  swtpm.tar
  ```
- Now, run the following command to convert Chromium OS to Chrome OS:
  ```bash
  cd ~/Downloads/ChromeOS/ && sudo bash chromefy.sh chromiumos_image.img chromeos_11151.113.1_eve_recovery_stable-channel_mp.bin swtpm.tar
  ```
  
  At some point, the script might prompt you to know if you want to set **SELINUX** to *permissive*, just press `n` and enter.

#### Installing on HDD

- Run the following command to install chromium on HDD:
  ```bash
  cd ~/Downloads/ChromeOS/ && sudo bash install_chromium.sh chromiumos_image.img sda4 sda5 sda6
  ```
  Before running the above command, replace `chromiumos_image.img` with the chromium image (should be unchanged if you're following the guide), `sda4` with **EFI-SYSTEM**
  partition's id, `sda5` with **ROOT-A** partition's id and `sda6` with **STATE** partition's id.

Now you can safely boot into the newly installed OS.

## Updating Chrome OS

_[Applied for Chrome OS only, if you're looking for updating @ArnoldTheBat's Chromium build, contact him instead]_

**<span color="red">! Warning !</span>** This process is experimental, be sure to issue a report if you stumble upon something.

You can use the **update_chromium.sh** script located in this repo to update Chrome OS to the latest version (should work with regular installation as well). To do this you'll need to download the latest recovery update for your platform (e.g. eve) which can be downloaded from [here](https://cros-updates-serving.appspot.com). If you needed **swtpm.tar**, download the latest file from [here](https://github.com/imperador/chromefy/raw/master/swtpm.tar).

Currently, `update_chromium.sh` takes three arguments (last is optional): the first argument is the recovery.bin file, the second argument is the device id of the **ROOT-A** partition (`sda5` if you're following this guide and `sda3` for regular installation) and the third argument is the optional **swtpm.tar**. For example:
```
update_chromium.sh ~/Downloads/chromeos_11647.104.3_eve_recovery_stable-channel_mp.bin sda5 swtpm.tar
```

You can use Ubuntu Live (ie. without installing a Linux distro) to update Chrome OS.

### Want to update natively?

Move to another repo as the project appears to be more complex than I imagined. Refer [here](https://github.com/MuntashirAkon/chrome_os_updater).

## Mounting internal partitions

As you may have noticed, internal partitions are not mounted by default (since Chrome OS is never meant to be used this way).
So, in order to mount the internal partitions, you'll need to edit `/etc/fstab` **_after_ you have created an user account in the Chrome OS.** The idea is to mount them inside the **~/Downloads** folder so that you can access these partitions from there.

Considering the fact that we may frequently need to change the partitions in the `fstab`, instead of editing `/etc/fstab`, we will be creating `/usr/local/fstab` which can be edited in Chrome OS later on.

#### Editing `/usr/local/fstab`

- First, you need to determine which partition(s) should be mounted on startup. You can get the device ids using various
  methods. For instance, in Chrome OS, you can get a list of mountable partitions using the following command:
  ```bash
  sudo /sbin/blkid -o full | grep -E "^/dev/sd.*TYPE" | grep -vE "EFI|STATE|ROOT-A"
  ```
  (Here **EFI**, **STATE** and **ROOT-A** partitions are ignored)
  
  You'll see something like this:
  ```
  /dev/sda2: UUID="97867245-0528-320d-94c1-c166b79375d9" LABEL="Ocean" TYPE="hfsplus" PARTUUID="864b7c8d-499e-11e7-8dc3-806e6f6e6963"
  /dev/sda3: UUID="f567c6b2-df56-37c2-b9f3-412a02695d30" LABEL="Shore" TYPE="hfsplus" PARTUUID="222c8fbe-9c8c-4ccc-a2d3-148c89b375ab"
  /dev/sda6: LABEL="WindowsOS" UUID="1EA06E1DA06DFC21" TYPE="ntfs" PARTLABEL="Basic data partition" PARTUUID="2ef2d893-6135-49f5-8792-a06e9eb40ef8"
  /dev/sda7: UUID="565E0E935E0E6C55" TYPE="ntfs" PARTUUID="5386f571-f91d-4c4b-b5b9-6599b2e64a5b"
  /dev/sda8: UUID="6ff85824-b561-3ffa-a1c2-171e142a9797" LABEL="macOSHighSierra" TYPE="hfsplus" PARTLABEL="Basic data partition" PARTUUID="5230f7de-347a-4091-963b-ae5cfbe9e37d"
  /dev/sda9: UUID="5e657717-36a7-3ff3-9f3b-7075104742bb" LABEL="Recovery HD" TYPE="hfsplus" PARTUUID="9b6e2c8a-bb3c-48e3-8a8b-56a26d86c5cd"
  /dev/sda12: UUID="f2d6d289-1c60-4d94-82f5-fa9132246a47" TYPE="ext4" PARTUUID="a61af699-38f7-47c3-bb97-10cbdf2dbedf"
  ```
  Note the device ids which are to be mounted on startup. (Suppose `sda2`, `sda3`, `sda6`, `sda8`, `sda12`)
- Open crosh and run the following:
  ```sh
  echo /home/$USER/u-$CROS_USER_ID_HASH/MyFiles/Downloads
  ```
  Or, if you're running Chrome OS 73 or less:
  ```sh
  echo /home/$USER/u-$CROS_USER_ID_HASH/Downloads
  ```
  You'll get a path which is accessible from **Files** app. Let call it Files path. (Suppose Files path is `/home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/MyFiles/Downloads`)
- For each of the partitions that you've noted earlier, assign a directory name after the Files path. For instance, for `sda2`, I can assign `Ocean`, thus the whole directory becomes `/home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/MyFiles/Downloads/Ocean`
- Create `/usr/local/fstab` using vim:
  ```
  sudo vim /usr/local/fstab
  ```
  Add the partition ids along with the mount points like this:
  ```
  /dev/sda2   /home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/MyFiles/Downloads/Ocean            auto    defaults   0      0
  /dev/sda3   /home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/MyFiles/Downloads/Shore            auto    defaults   0      0
  /dev/sda6   /home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/MyFiles/Downloads/WindowsOS        auto    defaults   0      0
  /dev/sda8   /home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/MyFiles/Downloads/macOSHighSierra  auto    defaults   0      0
  /dev/sda12  /home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/MyFiles/Downloads/Ubuntu           auto    defaults   0      0
  ```
  Now save the file.
  
  (If you don't know the `fstab` format, see the third reference bellow.)

#### Copying startup script
- Download this file ([mount-internals.conf](https://raw.githubusercontent.com/MuntashirAkon/Chrome-OS-Multiboot/master/mount-internals.conf)) at `~/Downloads` directory.
- Mount root partition for writing
  ```sh
  sudo mount -o rw,remount /
  ```
- Copy **mount-internals.conf** at `/etc/init/`:
  ```
  sudo cp ~/Downloads/mount-internals.conf /etc/init/
  ```
Now, you can safely reboot. This method should work on multiple user environment as well. But beware that the `CROS_USER_ID_HASH` different for each user and you've to configure each of them separately in the fstab file.

**NOTE:** Mounted partitions don't show up on Android, further study needed.

## References
1. https://github.com/imperador/chromefy
2. https://docs.google.com/document/d/1uBU4IObDI8IFhSjeCMvKw46O4vKCnfeZTGF7Jx8Brno/edit
3. https://wiki.debian.org/fstab
4. https://www.chromium.org/chromium-os/chromiumos-design-docs/disk-format
