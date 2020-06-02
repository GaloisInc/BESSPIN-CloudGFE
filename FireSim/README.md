# BESSIN-CloudGFE - FireSim

This is the FireSim-based platform for CloudGFE.

**Currently Supported Processors**:
| Processor   | AGFI                     | SW Package                                                          |
|-------------|--------------------------|---------------------------------------------------------------------|
| Chisel P1   | `agfi-01c6bf6f90700bec2` | `s3://firesim-localuser/swpkgs/firesim-cloudgfe-chisel-p1-sw.tgz`   |
| Chisel P2   | `agfi-0640a58e5553a75bd` | `s3://firesim-localuser/swpkgs/firesim-cloudgfe-chisel-p2-sw.tgz`   |
| Bluespec P2 | `agfi-0eb2fa447870a5426` | `s3://firesim-localuser/swpkgs/firesim-cloudgfe-bluespec-p2-sw.tgz` |

The SW packages are pre-configured to use the appropriate AGFI. 

These can be used to run arbitrary ELF files. A package of sample software binaries is also available:
`s3://firesim-localuser/swpkgs/cloudgfe_binaries.tgz`

The binaries package includes FreeRTOS for 32-bit processors and Linux + FreeBSD for 64-bit processors.

## Quick Setup

There is a [quick-setup guide](minimal_cloudgfe.md) for running FireSim-based AFIs on an F1 instance.

