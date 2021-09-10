// This file is generated automatically from the file 'HS_syscontrol.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "HS_syscontrol_protos.h"
// You may also want to create/maintain a file 'HS_syscontrol.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
HS_SysControl_State *HS_syscontrol_init (void);

extern
bool HS_syscontrol_do_some_work (void *comms_state, HS_SysControl_State *state);

extern
int HS_syscontrol_finish (void *comms_state, HS_SysControl_State *state);
