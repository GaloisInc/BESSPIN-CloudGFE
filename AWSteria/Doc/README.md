The figures in this directory show how the AWSteria setup evolved with
incremental and minimal changes from standard examples provided in the
aws-fpga repo.

In particular, we do not touch the Makefiles and scripts provided by
AWS, other than editing the manifests of the C and Verilog files
included in the build.

Fig 1 describes the standard `hello_world` and
`test_dram_dma_hwsw_cosim` examples in the AWS repo.


Fig 2 shows replacing the CL top-level SystemVerilog file with a
simpler version, inside which we instantiate a generic BSV module from
`AWS_BSV_Top.bsv` containing a BSV AXI4 fabric to access AWS DDR4s.


Fig 3 shows how we fit the BSV SoC (WindSoC/GFESoC) into the `AWS_BSV_Top`.

Fig 4 shows plans for supporting a GDB connection and Tandem Verification.
