# Chrome OS Multiboot

My approach to multiboot Chrome OS or Chromium OS on regular machines.

> If you're looking for updating you regular installation, nevigate [here](#want-to-update-natively).

<details>
 <summary>Index</summary>
 
- [Multiboot guide](#multiboot-guide)
  * [Prerequisites](#prerequisites)
  * [Process](#process)
    - [Creating partitions](#creating-partitions)
    - [Converting Chromium OS to Chrome OS](#converting-chromium-os-to-chrome-os)
    - [Installing on HDD](#installing-on-hdd)
- [Updating Chrome OS](#updating-chrome-os)
    - [Want to update natively?](#want-to-update-natively) [Incomplete]
- [Some important Chrome flags](#some-important-chrome-flags)
- [Mounting internal partitions](#mounting-internal-partitions)
- [References](#references)
</details>

## Multiboot guide

### Prerequisites
1. A Linux distro e.g. Ubuntu, Mint, etc. (may need installing since the files to be downloaded need a lot of space)
2. [chromefy.h](https://github.com/imperador/chromefy/releases)
3. @arnoldthebat's [Chromium OS Special build](https://chromium.arnoldthebat.co.uk/index.php?dir=special&order=modified&sort=desc)
4. [Caroline & Eve recovery files](https://cros-updates-serving.appspot.com) (for Intel) matching the @arnoldthebat's build
  (check [here](https://www.chromium.org/chromium-os/developer-information-for-chrome-os-devices) for more info)
5. [install_chrome.h](https://raw.githubusercontent.com/MuntashirAkon/Chrome-OS-Multiboot/master/install_chromium.sh)

If you're going to install Chromium OS (not Chrome OS), you don't need 2 and 4 prerequisites.

### Process

#### Creating partitions

You'll need to create 3 partitions in GPT mode:
1. **EFI-SYSTEM**: Type `FAT16` (32 MB) [assume, the device id is `sda4`]
2. **ROOT-A**: Type `EXT2` (around 5 GB) [assume `sda5`]
3. **STATE**: Type `EXT4` (this is where user files will be kept, so the size of the partition depends on you;
   20 GB recommended) [assume `sda6`]

#### Converting Chromium OS to Chrome OS

_[Skip this step if you are not going to install Chrome OS, just Chromium OS]_

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

You can use the **update_chromium.sh** script located in this repo to update Chrome OS to the latest version (should work with regular installation as well). To do this you'll need to download the latest recovery update for your platform (e.g. eve) which can be downloaded from [here](https://cros-updates-serving.appspot.com). If you needed a TPM 1.2 recovery image (e.g. caroline), download the latest recovery image for that as well.

Currently, `update_chromium.sh` takes three arguments (last is optional): the first argument is the recovery.bin file, the second argument is the device id of the **ROOT-A** partition (sda5 if you're following this guide and sda3 for regular installation) and the third argument is the optional TPM 1.2 recovery image. For example:
```
update_chromium.sh ~/Downloads/chromeos_11647.104.3_eve_recovery_stable-channel_mp.bin sda5 ~/Downloads/chromeos_11647.104.0_caroline_recovery_stable-channel_mp.bin
```

You can use Ubuntu Live to update Chrome OS.

**NOTE:** Your user account may be reset after update (not sure what causes it though).

### Want to update natively?

Yes, it is possible to update Chrome OS from the Chrome OS itself (without needing another Linux distro). But this requires 
another partition (namely **ROOT-B**) since you cannot modify the partition you're currently in. While I may add support for 
this kind of update later, you can do the update using the **update_chromium.sh** script as well. But each time you update, 
you'll need to modify the grub configuration in order to set the right partition to boot into. The idea is that, if you're 
currently booting from **ROOT-A** (current) partition, you'll install the update in the **ROOT-B** (target) partition and vice 
versa. To do that you'll need to mount the target partition and delete the content of it and copy everything from the current 
partition (to make the task easy). Then download the relevant images and run the script using the target partitions device ID 
as an argument. Then edit the grub config to boot from the target partition. If another update comes in, just install it to 
the **ROOT-A** partition using the similar process described above. This way you won't need any extra Linux distro (with a 
cost of another root partition, of course but it is already available in regular installation).

You can also use **cros_update.sh** (available in this repo) to update natively. But ***this script is not tested yet!*** So
only try it if you know what you're doing. To use the script, you'll need to create a configuration file as 
`/usr/local/cros_update.conf`. The format is given bellow:
```
ROOTA <ROOT-A UUID, lowercase>
ROOTB <ROOT-B UUID, lowercase>
EFI <EFI-SYSTEM UUID, lowercase>
RECOVERY <Code name, eg. eve>
TPM <optional, Code name of TPM 1.2 distro, eg. caroline>
```
You can get UUID for a disk ID using the following command:

```bash
/sbin/blkid -s PARTUUID -o value /dev/<disk-id>
```

After setting that, simply run the script without any argument to start updating.

**Note:** **cros_update.sh** automatically downloads the necessary files (> 2 GB, > 5 GB with TPM) and can download only the stable recovery updates.

## Some important Chrome flags

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
To add these flags, mount the **ROOT-A** partition in any linux distro (assume it is mounted at `/media/$USER/ROOT-A`) and open `/media/$USER/ROOT-A/etc/chrome_dev.conf` using your favourite text editor with admin privileges, e.g.:
```bash
sudo gedit /media/$USER/ROOT-A/etc/chrome_dev.conf
```
Add your desired flags at the bottom of the file (each in a new line or separated by a space) and save it.

Now you can safely restart and boot into Chrome OS.

**<span color="blue">!! PRO TIPS !!</span>**
You can also test them _inside_ Chrome OS (will be reset upon a restart), to do that run the following commands on CrOS terminal:
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

## Mounting internal partitions

_[Except where noted, you can follow this guide entirely on Chrome OS]_

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
  
  **NOTE:** As of Chrome OS version 74, you may need to append `/MyFiles/Downloads` instead of just `/Downloads`, i.e `/home/chronos/u-910450b5b86edd74333ce14f446ec9c7a44301e0/MyFiles/Downloads`. Be sure to try both of them
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
- Copy **mount-internals.conf** at `/media/${USER}/ROOT-A/etc/init/`:
  ```
  sudo cp ~/Downloads/mount-internals.conf /media/${USER}/ROOT-A/etc/init/
  ```
Now, you can safely reboot. This method should work on multiple user environment as well.

**NOTE:** Mounted partitions don't show up on Android, further study needed.

## References
1. https://github.com/imperador/chromefy
2. https://docs.google.com/document/d/1uBU4IObDI8IFhSjeCMvKw46O4vKCnfeZTGF7Jx8Brno/edit
3. https://wiki.debian.org/fstab
4. https://www.chromium.org/chromium-os/chromiumos-design-docs/disk-format
