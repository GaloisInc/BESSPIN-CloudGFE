// This file is generated automatically from the file 'HS_msg.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "HS_msg_protos.h"
// You may also want to create/maintain a file 'HS_msg.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
void *HS_msg_initialize (void);

extern
int HS_msg_finalize (void *comms_state);

extern
int HS_msg_hw_to_host_chan_get (void *comms_state, uint32_t chan_id, uint32_t *p_data);

extern
int HS_msg_hw_to_host_chan_get_nb (void *comms_state, uint32_t chan_id,
				   uint32_t *p_data, bool *p_valid);

extern
int HS_msg_host_to_hw_chan_put (void *comms_state, uint32_t chan_id, uint32_t data);

extern
int HS_msg_host_to_hw_chan_put_nb (void *comms_state, uint32_t chan_id,
				   uint32_t data, bool *p_valid);
