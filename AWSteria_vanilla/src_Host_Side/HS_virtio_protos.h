// This file is generated automatically from the file '/home/nikhil/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria_vanilla/src_Host_Side/HS_virtio.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "/home/nikhil/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria_vanilla/src_Host_Side/HS_virtio_protos.h"
// You may also want to create/maintain a file '/home/nikhil/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria_vanilla/src_Host_Side/HS_virtio.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
HS_Virtio_State *HS_virtio_init (const char *tun_iface,
				 const int   enable_virtio_console,
				 const int   dma_enabled,
				 const int   xdma_enabled,
				 const char *block_files [],
				 const int   num_block_files);

extern
int HS_virtio_req_from_hw_notFull (HS_Virtio_State *state, bool *p_notFull);

extern
int HS_virtio_req_from_hw_data (HS_Virtio_State *state, uint32_t data);

extern
int HS_virtio_rsp_to_hw_notEmpty (HS_Virtio_State *state, bool *p_notEmpty);

extern
int HS_virtio_rsp_to_hw_data (HS_Virtio_State *state, uint32_t *p_data);

extern
int HS_virtio_irq_to_hw_notEmpty (HS_Virtio_State *state, bool *p_notEmpty);

extern
int HS_virtio_irq_to_hw_data (HS_Virtio_State *state, uint32_t *p_data);

extern
bool HS_virtio_do_some_work (HS_Virtio_State *state);

extern
int HS_virtio_shutdown (HS_Virtio_State *state);
