// This file is generated automatically from the file '/home/nikhil/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria_vanilla/src_Host_Side/HS_tty.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "/home/nikhil/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria_vanilla/src_Host_Side/HS_tty_protos.h"
// You may also want to create/maintain a file '/home/nikhil/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria_vanilla/src_Host_Side/HS_tty.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
HS_tty_State *HS_tty_init (void);

extern
int HS_tty_to_hw_notEmpty (HS_tty_State *state, bool *p_notEmpty);

extern
int HS_tty_to_hw_data (HS_tty_State *state, uint32_t *p_data);

extern
int HS_tty_from_hw_notFull (HS_tty_State *state, bool *p_notFull);

extern
int HS_tty_from_hw_data (HS_tty_State *state, uint32_t data);

extern
bool HS_tty_do_some_work (HS_tty_State *state);
