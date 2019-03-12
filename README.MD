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
- [Mounting internal partitions](#mounting-internal-partitions) [Incomplete]
- [References](#references)

## Multiboot guide

### Prerequisites
1. A pendrive with 16 GB space (10 GB is enough)
2. A Linux distro e.g. Ubuntu, Mint, etc. (may need installing since the files to be downloaded need a lot of space)
3. [Chromefy script](https://github.com/imperador/chromefy/releases)
4. @arnoldthebat's [Chromium OS Special build](https://chromium.arnoldthebat.co.uk/index.php?dir=special&order=modified&sort=desc)
5. [Caroline & Eve recovery files](https://cros-updates-serving.appspot.com) (for Intel) matching the @arnoldthebat's build
  (check [here](https://www.chromium.org/chromium-os/developer-information-for-chrome-os-devices) for more info)
6. `install_chrome` script found in this repo
  
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

As you may have noticed, internal partitions are not mounted by default (since Chrome OS is never meant to be used this way).
So, in order to mount the internal partitions, you'll need to edit `/etc/fstab` **_after_ you have created an user account in the Chrome OS.** The idea is to mount them inside the **~/Downloads** folder so that you can access these partitions from there.

By default, `/etc/fstab` is not executed (that's good, because we need to mount the partitions after the user has logged in). But to do that we need to execute `mount -a -T /etc/fstab` after the user has logged in. This can be achieved by adding (or editing an existing) _configuration_ file in the `/etc/init` directory.

#### Editing `/etc/fstab`
TODO

#### Mounting partitions

### References
- https://github.com/imperador/chromefy
- https://docs.google.com/document/d/1uBU4IObDI8IFhSjeCMvKw46O4vKCnfeZTGF7Jx8Brno/edit
- https://wiki.debian.org/fstab
