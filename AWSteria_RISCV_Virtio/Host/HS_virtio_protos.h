// This file is generated automatically from the file 'HS_virtio.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "HS_virtio_protos.h"
// You may also want to create/maintain a file 'HS_virtio.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
HS_Virtio_State *HS_virtio_init (void *comms_state,
				 const char *tun_iface,
				 const int   enable_virtio_console,
				 const int   xdma_enabled,
				 const char *block_files [],
				 const int   num_block_files);

extern
bool HS_virtio_do_some_work_A (void *comms_state, HS_Virtio_State *state);

extern
int HS_virtio_shutdown (HS_Virtio_State *state);
