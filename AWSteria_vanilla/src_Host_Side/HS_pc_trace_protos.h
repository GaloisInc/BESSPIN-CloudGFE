// This file is generated automatically from the file '/home/nikhil/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria_vanilla/src_Host_Side/HS_pc_trace.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "/home/nikhil/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria_vanilla/src_Host_Side/HS_pc_trace_protos.h"
// You may also want to create/maintain a file '/home/nikhil/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria_vanilla/src_Host_Side/HS_pc_trace.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
HS_pc_trace_State *HS_pc_trace_init (void);

extern
int HS_pc_trace_from_hw_notFull (HS_pc_trace_State *state, bool *p_notFull);

extern
int HS_pc_trace_from_hw_data (HS_pc_trace_State *state, uint32_t data);

extern
bool HS_pc_trace_do_some_work (HS_pc_trace_State *state);
