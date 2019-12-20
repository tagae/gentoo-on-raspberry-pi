Gentoo Linux on Raspberry Pi
============================

![test](https://github.com/tagae/gentoo-on-raspberry-pi/workflows/test/badge.svg)

This repository contains a number of tools to install Gentoo Linux on the
[Raspberry Pi 4 Model B] platform.

These tools automate parts of the [Gentoo Handbook] to obtain in the end a
minimal installation based on [systemd] that is able to boot and accept SSH
connections. Provisioning and further system configuration are out of scope for
this project.

The built system is meant to run as a headless server. The installation has
been tested only by accessing the Raspberry Pi through a serial console
connection (using a USB to TTL serial cable), and through SSH
connections. Visual functionality (e.g., HDMI support, 3D graphics
acceleration) has not been tested.

[Raspberry Pi 4 Model B]: https://www.raspberrypi.org/products/raspberry-pi-4-model-b/
[Gentoo Handbook]: https://wiki.gentoo.org/wiki/Handbook:Main_Page
[systemd]: https://systemd.io/


Build environment
-----------------

This projects builds and installs Gentoo using Gentoo as build environment.

If your host runs Gentoo, you can use it as build environment by provisioning
your system with the needed tools through the `provision` command:

    sudo ./provision

If your host system is not Gentoo (or even if it is but you prefer to keep your
system untouched), you can run all commands in a `chroot`-ed Gentoo environment
through the `builder` command.  So the previous command becomes instead:

    sudo ./builder ./provision

The `builder` command creates a `builder.img` image containing a Gentoo build
environment. You can remove the image once no longer needed.

All instructions in this guide assume the use of the `builder` environment,
because it is the more general procedure that applies irrespective of the host
Linux distribution. Keep in mind however that if you use your Gentoo system as
build environment, you can simplify all commands shown in this guide by
omitting the `builder` wrapper.

If your host architecture is not aarch64 (64-bit ARM), the build system will
take care of cross-compiling the needed resources.

### Build Parameters

The parameters needed for installation are the following:

    export MACHINE=gentoo  # hostname of the installed system
    export PROFILE=rpi4    # only currently supported profile

If installing directly to a Micro SD card, you also need

    export DEVICE=/dev/mmcblk0 # target block device for installation

These environment variables are defined only for convenience in this guide;
you can inline their values if you prefer.

### Kernel Requirements

Your build system must run a kernel that supports Master Boot Record partitions
(`MSDOS_PARTITION`), FAT file systems (`FAT_FS`) and BTRFS file systems
(`BTRFS_FS`). Most Linux distributions meet these requirements out of the box.


Installation
------------

The `install` command installs a Gentoo system onto any given block device,
such that it can be booted by the Raspberry Pi. Concretely, the install process
will:

* Partition the device, creating
  * a boot partition containing a FAT file system, and
  * a base partition containing a BTRFS file system.

* For the boot file system, the `install` command will
  * fetch, compile and install the Linux kernel and modules, and
  * fetch and install the Raspberry Pi firmware.

* For the base file system, the `install` command will bootstrap a Gentoo
  system, as described in the "Bootstrapping" section.

The `install` command can write directly to the microSD card that will be used
to run the Raspberry Pi. Simply issue:

    sudo -E ./builder ./install $MACHINE $PROFILE $DEVICE

Once the installation is complete, you can insert the card into your Raspberry
Pi, connect the Pi via an Ethernet cable to your network, and you will be able
to SSH into it with

    ssh root@$MACHINE.local

This assumes that the system from which you connect is able to resolve
Multicast DNS (`.local`) domains. Otherwise you need to find the IP address of
the Pi host in your network.

By default the installed system will be configured to allow SSH connections
from your key at `~/.ssh/id_rsa`, if available.  If unavailable (in particular,
if you omit the `-E` option from `sudo`), a fresh key will be generated at
`install.d/ssh/$MACHINE` and used instead.


Packaging
---------

The `package` command creates an image containing a Gentoo installation that
can boot on the Raspberry Pi, as described in the "Installation" section.

To create the image, issue

    sudo -E ./builder ./package $MACHINE.$PROFILE.img

The image will have `$MACHINE` as default hostname, and will allow SSH
connections for your personal key at `$HOME/.ssh/id_rsa`.

You can omit the `-E` option from `sudo` if you prefer to use the key at
`install.d/ssh/$MACHINE`. The key will be automatically generated unless it
already exists.

Given that you can install Gentoo directly to a microSD card (see
"Installation" section), the main reason to build an image is to boot it
through an emulator (see "Booting" section) for the sake of exploration and
testing.


Booting
-------

The `boot` command runs a QEMU virtual machine that has an image of the system
(see "Packaging" section) as main hard disk:

    sudo -E ./builder ./boot $MACHINE.$PROFILE.img

This makes it possible to test the system locally, before it is written to a
microSD card and run on the Raspberry Pi.

To connect to the virtual machine, issue

    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 2222 root@localhost

The `-o` options avoid polluting your `~/.ssh/known_hosts` with the fingerprint
of a machine that you are only testing.

Currently QEMU cannot emulate the Raspberry Pi 4 hardware, and thus the image
is run in a generic 64-bit ARM machine that has none of the hardware specific
to the Raspberry Pi. Still, this is enough to test most of the relevant parts
of the system before it is actually deployed on the Pi.


Bootstrapping
-------------

The `bootstrap` command will deploy a bare-bones (stage3) Gentoo system onto
any given sub-directory that is part of a BTRFS file system.

The `bootstrap` command is akin to tools like [debootstrap] for Debian, and
[arch-bootstrap] for Arch Linux.

Bootstrapping is used both to create build environments (see "Build
environment" section), and to bootstrap the system that will run on the
Raspberry Pi.

You can of course bootstrap Gentoo for other purposes, and use it as `chroot`
jail or `systemd-nspawn` container.

[debootstrap]: https://wiki.debian.org/Debootstrap
[arch-bootstrap]: https://github.com/tokland/arch-bootstrap
