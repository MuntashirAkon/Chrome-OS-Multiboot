# Chrome OS Multiboot

My collection of scripts and tutorials to multiboot Chrome OS with other operating systems

### Index
- [Multiboot guide](#multiboot-guide)
  * [Prerequisites](#prerequisites)
  * [Process](#process)
    - [Creating partitions](#creating-partitions)
    - [Converting Chromium OS to Chrome OS](#converting-chromium-os-to-chrome-os)
    - [Installing on HDD](#installing-on-hdd)
  * [Post-installation](#post-installation)
    - [Fix GRUB (the bootloader)](#fix-grub-the-bootloader)
    - [Fix partition table info](#fix-partition-table-info) [Incomplete]
    - [Enable tap to click (optional and for Synaptics Touchpad only)](#enable-tap-to-click-optional-and-for-synaptics-touchpad-only)
- [Updating Chrome OS](#updating-chrome-os) [Incomplete]
- [Some important Chrome flags](#some-important-chrome-flags)
- [Mounting internal partitions](#mounting-internal-partitions)
- [References](#references)

## Multiboot guide

### Prerequisites
1. A pendrive with 16 GB space (10 GB is enough)
2. A Linux distro e.g. Ubuntu, Mint, etc. (may need installing since the files to be downloaded need a lot of space)
3. [chromefy.h](https://github.com/imperador/chromefy/releases)
4. @arnoldthebat's [Chromium OS Special build](https://chromium.arnoldthebat.co.uk/index.php?dir=special&order=modified&sort=desc)
5. [Caroline & Eve recovery files](https://cros-updates-serving.appspot.com) (for Intel) matching the @arnoldthebat's build
  (check [here](https://www.chromium.org/chromium-os/developer-information-for-chrome-os-devices) for more info)
6. [install_chrome.h](https://raw.githubusercontent.com/MuntashirAkon/Chrome-OS-Multiboot/master/install_chromium.sh)
  
### Process

#### Creating partitions

You'll need to create 3 partitions in GPT mode:
1. **EFI-SYSTEM**: Type `FAT16` (32 MB) [assume, the device id is `sda4`]
2. **ROOT-A**: Type `EXT2` (around 5 GB) [assume `sda5`]
3. **STATE**: Type `EXT4` (this is where user files will be kept, so the size of the partition depends on you;
   20 GB recommended) [assume `sda6`]

#### Converting Chromium OS to Chrome OS

- Download the prequisites at `~/Downloads/ChromeOS` and extract them there as well.
  Don't delete the zipped files yet (as something might be broken). The file structure should look something like this:
  ```
  Camd64OS_R72-11316.B-Special.7z
  chromefy.sh
  install_chromium.sh
  chromeos_11316.165.0_caroline_recovery_stable-channel_mp.bin
  chromeos_11316.165.0_caroline_recovery_stable-channel_mp.bin.zip
  chromeos_11316.165.0_eve_recovery_stable-channel_mp.bin
  chromeos_11316.165.0_eve_recovery_stable-channel_mp.bin.zip
  chromiumos_image.img
  ```
- Now, run the following command to convert Chromium OS to Chrome OS:
  ```bash
  cd ~/Downloads/ChromeOS/ && sudo bash chromefy.sh chromiumos_image.img chromeos_11151.113.1_eve_recovery_stable-channel_mp.bin chromeos_11151.113.0_caroline_recovery_stable-channel_mp.bin
  ```
  As you perhaps noticed, `chromeos_11151.113.1_eve_recovery_stable-channel_mp.bin` and
  `chromeos_11151.113.0_caroline_recovery_stable-channel_mp.bin` should match the versions that you're using.
  
  At some point, the script might prompt you to know if you will set SELINUX=permissive, just press `n` and enter.

#### Installing on HDD

[There is a better way, but currently this one is the one that I followed]

- Insert pendrive and find the device id using **Disks** or similar program (suppose, the device id is `sdb`)
- Run the following command to install Chrome OS on your pendrive: (**All data in the pendrive will be erased!)
  ```bash
  cd ~/Downloads/ChromeOS/ && sudo dd if=chromiumos_image.img of=/dev/sdb bs=4M
  ```
  Replace `sdb` with the device id of your pendrive
- Run the following command to install chromium on HDD
  ```bash
  cd ~/Downloads/ChromeOS/ && sudo install_chromium.sh sdb sda4 sda5 sda6
  ```
  Replace `sdb` with the device id of your pendrive, `sda4` with **EFI-SYSTEM** partition's id,
  `sda5` with **ROOT-A** partition's id and `sda6` with **STATE** partition's id

#### Post-installation

##### Fix GRUB (the bootloader)
In order to boot into the installed OS, the bootloader is needed to be configured properly. The boot parition is **ROOT-A**,
hence we need the partition UUID of it. To get the partition UUID, run: (assuming `sda5` to be the **ROOT-A** partition)
```bash
sudo sfdisk --part-uuid "/dev/sda" 5
```
Note the above partition UUID.

Now, to fix the bootloader, open `~/localefi/efi/boot/grub.cfg` with your favourite editor with admin privilege, e.g.:
```bash
sudo gedit ~/localefi/efi/boot/grub.cfg
```
Delete everything from there and copy-and-paste the contents bellow:
```bash
set default=0
set timeout=2
menuentry "Chrome OS" {
  linux /syslinux/vmlinuz.A init=/sbin/init boot=local rootwait ro noresume noswap loglevel=7 noinitrd console=  i915.modeset=1 cros_efi cros_debug root=PARTUUID=<partition-uuid>
}
```
Now, replace `<partition-uuid>` with the partition UUID that you've noted earlier.

##### Fix partition table info
To fix partition table info, open `~/localroota/usr/sbin/write_gpt.sh` with your favourite editor with admin privilege, e.g.:
```bash
sudo gedit ~/localroota/usr/sbin/write_gpt.sh
```

TODO

##### Enable tap to click (optional and for Synaptics Touchpad only)
To enable tap to click, open `~/localroota/etc/gesture/40-touchpad-cmt.conf` with your favourite editor with admin privilege, e.g.:
```bash
sudo gedit ~/localroota/etc/gesture/40-touchpad-cmt.conf
```
Find `CMT for Synaptics Touchpad` and add these lines in a new line inside this section
```
    # Enable tap to click
    Option          "libinput Tapping Enabled" "1"
    Option          "Tap Minimum Pressure" "0.1"
```

Now you can safely boot into the newly installed OS.

### Updating Chrome OS
TODO

### Some important Chrome flags
Since `Chrome://flags` results in a blank page on Chrome OS, here I've listed some important Chrome flags for better user experience.
```
--enable-fast-unload
--enable-google-branded-context-menu
--enable-offline-auto-reload-visible-only
--enable-offline-auto-reload
--enable-physical-keyboard-autocorrect
--enable-quic
--enable-smooth-scrolling
--enable-wifi-credential-sync
--enable-features=Pepper3DImageChromium,PointerEvent,MachineLearningService,ChromeOSAssistant,EnableBackgroundBlur,Crostini,ExperimentalCrostiniUI,ArcEnableUnifiedAudioFocus,ArcVpn,ArcBootCompletedBroadcast,ChromeOSAccountManager,EnableNewStyleLauncher,NewStyleNotifications,ExperimentalUi,ParallelDownloading,UseModernMediaControls,CrostiniUsbSupport,EnableAppShortcutSearch,EnableBackgroundBlur,EnablePlayStoreAppSearch,EnableHomeLauncher,EnableSettingsShortcutSearch,EnableAppsGridGapFeature,
--show-saved-copy
--enable-virtual-keyboard
--enable-lock-screen-apps
```
To add these flags, open `~/localroota/etc/chrome_dev.conf` with your favourite editor with admin privilege, e.g.:
```bash
sudo gedit ~/localroota/etc/chrome_dev.conf
```
Now, add the flags at the bottom of the file.

You can also test them _inside_ Chrome OS, to do that run the following commands on CrOS terminal:
```bash
sudo su
cp /etc/chrome_dev.conf /usr/local/
mount --bind /usr/local/chrome_dev.conf /etc/chrome_dev.conf
exit
```
Now, you can use `vim` editor to edit the file.
```bash
sudo vim /etc/chrome_dev.conf
```

### Mounting internal partitions

(Except where noted, you can follow this guide entirely on Chrome OS)

As you may have noticed, internal partitions are not mounted by default (since Chrome OS is never meant to be used this way).
So, in order to mount the internal partitions, you'll need to edit `/etc/fstab` **_after_ you have created an user account in the Chrome OS.** The idea is to mount them inside the **~/Downloads** folder so that you can access these partitions from there.

Considering the fact that we may frequently need to change the partitions in the `fstab`, instead of editing `/etc/fstab`, we will be creating `/usr/local/fstab` which can be edited in Chrome OS later on.

#### Editing `/usr/local/fstab`

- First, you need to determine which partition(s) should be mounted on startup. You can get the device ids using various
  methods. For instance, in Chrome OS, you can get a list of mountable partitions using the following command:
  ```bash
  sudo /sbin/blkid -o full | grep -E "^/dev/sda.*TYPE" | grep -vE "EFI|STATE|ROOT-A"
  ```
  (Here **EFI**, **STATE** and **ROOT-A** partitions are ignored)
  
  You'll see somthing like this:
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
- Find your profile path. The quick way would be to open `chrome://version/#profile_path` on your Chrome OS.
  Suppose the profile path is `/home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0`
- Append `/Downloads` at the end of the profile path (namely Downloads path), i.e. `/home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/Downloads`
- For each of the partitions that you've noted earlier, assign a directory name after the downloads path. For instance, for `sda2`, I can assign `Ocean`, thus the whole directory becomes `/home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/Downloads/Ocean`
- Create `/usr/local/fstab` using vim:
  ```
  sudo vim /usr/local/fstab
  ```
  Add the partition ids along with the mount points like this:
  ```
  /dev/sda2   /home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/Downloads/Ocean            auto    defaults   0      0
  /dev/sda3   /home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/Downloads/Shore            auto    defaults   0      0
  /dev/sda6   /home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/Downloads/WindowsOS        auto    defaults   0      0
  /dev/sda8   /home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/Downloads/macOSHighSierra  auto    defaults   0      0
  /dev/sda12  /home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/Downloads/Ubuntu           auto    defaults   0      0
  ```
  Now save the file and boot into a linux distro.
  
  (If you don't know the `fstab` format, see the third reference bellow.)

#### Copying startup script

On your linux distro:
- Download this file ([mount-internals.conf](https://raw.githubusercontent.com/MuntashirAkon/Chrome-OS-Multiboot/master/mount-internals.conf)) at `~/Downloads` directory.
- Mount **ROOT-A** partition using file manager or disks (the location should be `/media/${USER}/ROOT-A`)
- Copy **mount-internals.conf** at **/media/${USER}/ROOT-A/etc/init/**:
  ```
  sudo cp ~/Downloads/mount-internals.conf /media/${USER}/ROOT-A/etc/init/
  ```

Now, you can safely reboot. This method should work on multiple user environment as well.

**NOTE:** Mounted partitions don't show up on Android, further study needed. 

### References
1. https://github.com/imperador/chromefy
2. https://docs.google.com/document/d/1uBU4IObDI8IFhSjeCMvKw46O4vKCnfeZTGF7Jx8Brno/edit
3. https://wiki.debian.org/fstab
