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
int HS_syscontrol_to_hw_notEmpty (HS_SysControl_State *state, bool *p_notEmpty);

extern
int HS_syscontrol_to_hw_data (HS_SysControl_State *state, uint32_t *p_data);

extern
int HS_syscontrol_from_hw_notFull (HS_SysControl_State *state, bool *p_notFull);

extern
int HS_syscontrol_from_hw_data (HS_SysControl_State *state, uint32_t data);

extern
bool HS_syscontrol_terminating ();

extern
bool HS_syscontrol_do_some_work (HS_SysControl_State *state);
