These are test programs for AWSteria.

Files '*.Mem.hex32' are Mem-hex dumps of ELF files, and are intended
for loading from AWSteria's host-side.  I.e., the host-side reads the
file and uses the DMA facility to download it to the FPGA-side.  These
can be used in simulation and on AWS FPGA.

Files '*.Mem.hex512' are only for simulation.  They are conversions of
the Mem.hex32 files, and are intended for direct loading into the
simulation model of AWS 'DDR4 A' memory (this is simulation
convenience, for faster loading).

See the Makefile for how to make a Mem.hex512 from a Mem.hex32 file.

// ================================================================
FreeBSD

FreeBSD without virtio, creating filestore in RAM
    32331912 Jun  4 12:05 bbl-riscv64.GFE    (ELF file)
    72107830 Jun  4 12:05 miniFreeBSD.hex

FreeBSD with virtio
    bbl-riscv64.FETT
Filestore images for virtio:
  a minimal one, to get you started,
    cheribsd-minimal-riscv64.img
  a full one, for essentially all the FreeBSD additions
    cheribsd-riscv64.img
  These can be manipulated by the Connectial virtio hostside (you
  specify them by the -b flag, if I remember), and provide a
  persistent filestore.  I recommend copying them and supplying the
  copy to virtio -- that way, if things crash you can restart from a
  virgin system; otherwise FreeBSD will spend ages during the boot
  trying to repair the crashed system.

// ================================================================
Linux

A version of busybox. Joe: used it only for initial debugging
    19200205 Jun  4 12:05 busybox.hex

// ================================================================
FreeRTOS

64-bit FreeRTOS
     2075468 Jun 20 15:18 freertos1000.dump
      626824 Jun 20 15:18 freertos1000.elf
     1866250 Jun 20 15:18 freertos1000.hex

// ================================================================
