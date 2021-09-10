// This file is generated automatically from the file 'HS_pc_trace.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "HS_pc_trace_protos.h"
// You may also want to create/maintain a file 'HS_pc_trace.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
HS_pc_trace_State *HS_pc_trace_init (FILE *fp);

extern
bool HS_pc_trace_do_some_work (void *comms_state, HS_pc_trace_State *state);
