// This file is generated automatically from the file '/home/nikhil/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria_vanilla/src_Host_Side/HS_gdbstub.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "/home/nikhil/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria_vanilla/src_Host_Side/HS_gdbstub_protos.h"
// You may also want to create/maintain a file '/home/nikhil/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria_vanilla/src_Host_Side/HS_gdbstub.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
HS_Gdbstub_State *HS_gdbstub_init (void);

extern
int HS_gdbstub_req_to_hw_notEmpty (HS_Gdbstub_State *state, bool *p_notEmpty);

extern
int HS_gdbstub_req_to_hw_data (HS_Gdbstub_State *state, uint32_t *p_data);

extern
int HS_gdbstub_rsp_from_hw_notFull (HS_Gdbstub_State *state, bool *p_notFull);

extern
int HS_gdbstub_rsp_from_hw_data (HS_Gdbstub_State *state, uint32_t data);

extern
bool HS_gdbstub_do_some_work (HS_Gdbstub_State *state);
