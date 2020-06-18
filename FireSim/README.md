# BESSIN-CloudGFE - FireSim

This is the FireSim-based platform for CloudGFE.

**Currently Supported Processors**:
| Processor   | AGFI                     | SW Package                                                          |
|-------------|--------------------------|---------------------------------------------------------------------|
| Chisel P1   | `agfi-0d5538eb0d5b9be22` | `s3://firesim-localuser/swpkgs/firesim-cloudgfe-chisel-p1-sw.tgz`   |
| Chisel P2   | `agfi-0e7e40739f4984c3e` | `s3://firesim-localuser/swpkgs/firesim-cloudgfe-chisel-p2-sw.tgz`   |
| Bluespec P2 | `agfi-0dcad3a3f079d247e` | `s3://firesim-localuser/swpkgs/firesim-cloudgfe-bluespec-p2-sw.tgz` |

**Note** The Bluespec P2 has not been updated to include RNG or GDB support.

The SW packages are pre-configured to use the appropriate AGFI. 

These can be used to run arbitrary ELF files. A package of sample software binaries is also available:
`s3://firesim-localuser/swpkgs/cloudgfe_binaries.tgz`

The binaries package includes FreeRTOS for 32-bit processors and Linux + FreeBSD for 64-bit processors.

## Quick Setup

There is a [quick-setup guide](minimal_cloudgfe.md) for running FireSim-based AFIs on an F1 instance.

