# Minimal CloudGFE Setup

This readme will guide you through bringing up an F1 instance with a CloudGFE processor. Currently supported:
* Rocket P1 running FreeRTOS
* Rocket P2 running Linux and FreeBSD
* Bluespec P2 running Linux and FreeBSD

This assumes you are familiar with AWS.

## Start F1 Instance

Launch a new `f1.2xlarge` instance with `FPGA Developer AMI - 1.6.0`. It must be this specific AMI, otherwise you will have to compile your own kernel modules. It's recently become more difficult to search for this instance. If it does not appear under the Community AMI section using the name above, try searching for `ami-02b792770bf83b668`.

Once the instance launches, login and add your AWS keys, either via copy/pasting the environmental variables or using `aws configure`.

## Access

The quick-start files are located on Amazon S3. The CloudGFE AFI is also access-controlled. If you are not using the `Galois_TA-2_F1_DEV` account, you'll need to create an github issue or send both your [AWS ID and canonical user ID](https://docs.aws.amazon.com/general/latest/gr/acct-identifiers.html) to [dhand@galois.com](mailto:dhand@galois.com) for access to both. The canonical ID can quickly be found using `aws s3api list-buckets`.

## Pull a CloudGFE Software Support Package

See the [README](README.md) for a full list of software packages. We'll use the Chisel P2 in this example.

Download the setup package from S3:
```
cd ~
aws s3 cp s3://firesim-localuser/swpkgs/firesim-cloudgfe-chisel-p2-sw.tgz .
tar xzvf firesim-cloudgfe-chisel-p2-sw.tgz
```

## Initial Setup

This setup installs the FPGA SDK and necessary kernel modules. It will build the full SDK the first time it runs.
Subsequent runs should only setup the kernel modules. Thus, you can run this script once every time you reboot the F1
instance. It does not need to be run between simulations.

```
cd ~/sw
./setup.sh
```

## Example Binaries

A number of example binaries have been precompiled and provided for use (FreeRTOS, Linux, FreeBSD, and a helloworld bare-metal example).
To download this package:
```
cd ~
aws s3 cp s3://firesim-localuser/swpkgs/cloudgfe_binaries.tgz
tar xzvf cloudgfe_binaries.tgz
```

## `run_sim.sh` Script

Inside the `~/sw/sim` folder, the `./run_sim.sh` script handles configuring networking, bringing up the switch software, programming the FPGA, and starting the simulation.
It expects three arguments:

```
./run_sim.sh <blockimage> <dwarf> <elf>
```

* `blockimage` - the image file presented via the block device
* `dwarf` - currently unknown purpose. Give it `elf-dwarf` as an argument for now
* `elf` - ELF binary to be loaded into memory and executed

The script launches 3 `screen` sessions:
* `fsim0` - UART console and simulator output
* `switch0` - Software switch log
* `bootcheck` - Checks for successful Linux boot to bring up networking interface

The `fsim0` screen will be attached automatically. You can exit it while keeping the sim running using `Ctrl-a` followed by `d`, or `C-a d` in screen terms.

## P1 32-bit Binaries

Three FreeRTOS examples have been provided. Only the UART and IceNet ethernet drivers are included at this time.

```
cd ~/sw/sim/
./run_sim.sh ~/cloudgfe_binaries/freertos_32bit/freertos_peekpoke.img ~/cloudgfe_binaries/freertos_32bit/freertos_peekpoke.dwarf  ~/cloudgfe_binaries/freertos_32bit/freertos_peekpoke.elf
```

The `peekpoke` example will start a webserver at `http://172.16.0.2` that can peek and poke memory locations on the FPGA. See the original GFE documentation for how to use this webserver.

The bare-metal `helloworld_32bit` example will print "Hello World!" and immediately exit. If it is too quick to see the output, check `uartlog`.

## Boot Linux on P2

There are two flavors of Linux provided. The first, `busyboxlinux_64bit` is a Busybox-based Linux OS built using buildroot. It uses the block device to provide a persistent filesystem.
The second, `debianlinux_64bit`, is a Debian-based Linux OS. The kernel and ramdisk image are combined into the single ELF file. While this OS includes block device drivers, only an empty image is provided.

To boot Debian Linux:
```
cd ~/sw/sim
./run_sim.sh ~/cloudgfe_binaries/debianlinux_64bit/debian.img ~/cloudgfe_binaries/debianlinux_64bit/debian.dwarf ~/cloudgfe_binaries/debianlinux_64bit/debian.elf
```
The login for Debian is `root` and password `riscv`. The login for Busybox is `root` and password `firesim`.

Busybox linux will boot with full network / internet access. You can SSH into it from the F1 instance using:
```
TERM=Linux ssh root@172.16.0.2
```

Running `poweroff -f` within the target OS will automatically stop the simulator cleanly. If it becomes stuck or unresponsive, you can also use the `./kill_sim.sh` script.

## Boot FreeBSD on P2

The current FreeBSD build does not include Ethernet or Block device drivers, so SSH will not work. `freebsd.img` is also just an empty file. The filesystem is stored within the ELF.

```
./run_sim.sh ~/cloudgfe_binaries/freebsd_64bit/freebsd.img ~/cloudgfe_binaries/freebsd_64bit/freebsd.dwarf ~/cloudgfe_binaries/freebsd_64bit/freebsd.elf
```

## Networking Notes
* The target OS has full internet access by default, but it is NAT'd behind the host OS.
* The Busybox Linux image starts a simple Dropbear SSH server and Apache HTTP server. On the host OS you can run:
```
curl http://172.16.0.2
<html><body><h1>Hello!</h1>

This webpage is hosted by apache, running on Linux, running on a FireSim simulation
of RISC-V RocketChip on the FPGA of an EC2 F1 instance.

</body></html>
```

## Known Issues
* If the tap0 interface is already `up` when loading the simulator, Linux will get stuck when starting networking for an unknown reason. Keeping the interface `down` until fully booted fixes this issue.
* Packets sent via SSH are generating a `Invalid checksum` message in the UART output. These don't seem to affect the actual connection very much. And using other networking tools, like `wget` operate normally without any messages.
