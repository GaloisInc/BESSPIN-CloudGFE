# 3 Flute Variants on AWS F1 FPGA in Connectal Style

This directory contains the host software and hardware designs for a
SSITH RISC-V processor running on Amazon AWS F1 FPGA. The hardware
models a UART and VIRTIO console, block, network, and entropy devices.

[![Build Status](https://travis-ci.org/acceleratedtech/ssith-aws-fpga.svg?branch=master)](https://travis-ci.org/acceleratedtech/ssith-aws-fpga)

## Start F1 Instance

Launch a new `f1.2xlarge` instance with `Ubuntu 18.04`.

Once the instance launches, login as user `ubuntu`.

## Setting up development tools

```bash
sudo apt-get update
sudo apt-get install cmake device-tree-compiler build-essential libssl-dev libcurl4-openssl-dev libelf-dev git
```

## Update the Submodules

```
cd BESSPIN-CloudGFE/ConnectalStyle
git submodule update --init --recursive ssith-aws-fpga
```

## Building the Host Software

```
mkdir build
cd build
cmake -DFPGA=1 ../ssith-aws-fpga
make -j8
cd ..
```

## Building the Device Drivers

```
cd ssith-aws-fpga/drivers/pcieportal
make
```

## FPGA AFI

* Bluespec P2: TBD

* CHERI P2: TBD

* MIT P2: AGFI-TBD , 100MHz


## Running the P2 processors

Configure a network tap device named `tap0`.

Make sure the `pcieportal` driver is not loaded. It sometimes crashes while the FPGA is being loaded.

```
sudo rmmod pcieportal
```

Then load the FPGA image and drivers:

```
sudo fpga-load-local-image -S 0 -I AGFI-TBD
sudo insmod ssith-aws-fpga/hw/connectal/drivers/pcieportal/pcieportal.ko
sudo insmod ssith-aws-fpga/hw/connectal/drivers/portalmem/portalmem.ko
```

### Running the MIT P2 processor

Then load and run the software on the MIT P2 processor:
```
dtc -I dts -O dtb -o build/devicetree-mit.dtb ssith-aws-fpga/src/dts/devicetree-mit.dts
./build/ssith-aws-fpga --elf kernel-security-monitor.elf --block rootfs.elf --tun --tun tap0 --xdma=0 --dma=1 --entry=0x80003000 --dtb build/devicetree-mit.dtb
```

## Simulation

The same designs may be simulated under Verilator.

* Requires Verilator

* Requires BSV Compiler (bsc)

* Even with open source bsc, the build uses $BLUESPECDIR to find required BSV and Verilog files

### Bluespec P2

```
cd ssith-aws-fpga/hw/src_AWS_P2
make -j8 build.awsf1
```

### CHERI P2

```
cd ssith-aws-fpga/hw/src_AWS_P2_CHERI
make -j8 build.awsf1
```

### MIT P2

```
cd ssith-aws-fpga/hw/src_AWS_MIT
make -j8 build.awsf1
```


## Building the Verilator Simulator

* Requires Verilator

* Requires BSV Compiler (bsc)

* Even with open source bsc, the build uses $BLUESPECDIR to find required BSV and Verilog files

### Bluespec P2

```
cd ssith-aws-fpga/hw/src_AWS_P2
make -j8 build.verilator
```

### CHERI P2

```
cd ssith-aws-fpga/hw/src_AWS_P2_CHERI
make -j8 build.verilator
```

### MIT P2

```
cd ssith-aws-fpga/hw/src_AWS_MIT
make -j8 build.verilator
```

## Building the Host Software for Simulation

```
sudo apt install cmake build-essential 
mkdir build
cmake ../ssith-aws-fpga
make -j8
cd ..
```
