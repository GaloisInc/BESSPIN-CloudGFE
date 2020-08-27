FreeBSD without virtio, creating filestore in RAM
    32331912 Jun  4 12:05 bbl-riscv64.GFE    (ELF file)
    72107830 Jun  4 12:05 bbl.hex
    72107830 Jun  4 12:05 miniFreeBSD.hex

A version of busybox. Joe: used it only for initial debugging
    19200205 Jun  4 12:05 busybox.hex

64-bit FreeRTOS
     2075468 Jun 20 15:18 freertos1000.dump
      626824 Jun 20 15:18 freertos1000.elf
     1866250 Jun 20 15:18 freertos1000.hex

'cat', echoing tty input to tty output
       51976 Jun 20 20:04 rv64-cat*
       64151 Jun 20 20:04 rv64-cat.map
      175218 Jun 20 20:04 rv64-cat.text

Hello World:
           54344 Jun 19 09:34 rv64-hello*
           70312 Jun 19 09:34 rv64-hello.map
          211606 Jun 19 09:34 rv64-hello.text
           53110 Aug 14 12:25 rv64-hello.Mem.hex

Test MMIO reads/writes for virtio addrs
           54888 Jun 19 16:54 rv64-test*
           70310 Jun 19 16:54 rv64-test.map
          213676 Jun 19 16:54 rv64-test.text

ISA test
           18442 Jun  4 12:05 rv64ui-p-add.hex

Copy of one of the above .hex files
       18442 Jun  4 12:05 Mem.hex


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
