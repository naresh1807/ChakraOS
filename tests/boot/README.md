# tests/boot/

Booting the finished ISO is not something the chroot suite can do, so it
stays a documented manual/CI step.

## QEMU smoke (built into the pipeline)

```
sudo build/scripts/build_iso.sh --test
```

`--test` runs `boot_test()` after the ISO is written: `qemu-system-x86_64
-m 2048 -cdrom <iso> -boot d` (with `-enable-kvm` when `/dev/kvm`
exists). It confirms the ISO is bootable — GRUB → live-boot → a working
init. It does not log in or drive the desktop.

## VirtualBox desktop test (per-phase, manual)

Each phase in this project was verified in a persistent VirtualBox VM
named **ChakraOS** (Debian_64, ~3.5 GB RAM, BIOS, IDE controller),
driven headless:

```
VBoxManage storageattach ChakraOS --storagectl IDE --port 0 --device 0 \
  --type dvddrive --medium <path-to-iso>
VBoxManage startvm ChakraOS --type headless
# wait ~3 min for the Plasma desktop
VBoxManage controlvm ChakraOS keyboardputscancode 38 3c bc b8   # Alt+F2 (KRunner)
VBoxManage controlvm ChakraOS keyboardputstring "konsole"
VBoxManage controlvm ChakraOS keyboardputscancode 1c 9c         # Enter
VBoxManage controlvm ChakraOS keyboardputstring "chakra-health; chakra-score"
VBoxManage controlvm ChakraOS screenshotpng /tmp/shot.png
```

What to eyeball on the desktop: the Chakra wallpaper + Windows-style
desktop icons render; the Start menu has the Security Tools / Chakra
Tools / Developer Tools / System Maintenance / Security Research /
Mobile / Appearance / Compatibility / Office sections; `chakra-shell
theme light` recolours the session live; `chakra-compat run <exe>`
opens a Windows program; `chakra-office open <doc>` opens LibreOffice
read-only.

A scripted VirtualBox harness (`tests/boot/vbox-smoke.sh`) is a
worthwhile follow-up — it isn't written yet.
