// This file is generated automatically from the file 'AWS_Sim_Lib.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "AWS_Sim_Lib_protos.h"
// You may also want to create/maintain a file 'AWS_Sim_Lib.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
void AWS_Sim_Lib_init (void);

extern
void AWS_Sim_Lib_shutdown (void);

extern
int fpga_dma_burst_read (int fd, uint8_t *buffer, size_t size, uint64_t address);

extern
int fpga_dma_burst_write (int fd, uint8_t *buffer, size_t size, uint64_t address);

extern
int fpga_pci_peek (pci_bar_handle_t handle, uint64_t ocl_addr, uint32_t *p_ocl_data);

extern
int fpga_pci_poke (pci_bar_handle_t handle, uint64_t ocl_addr, uint32_t ocl_data);
