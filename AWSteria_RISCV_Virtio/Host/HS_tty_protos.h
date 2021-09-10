// This file is generated automatically from the file 'HS_tty.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "HS_tty_protos.h"
// You may also want to create/maintain a file 'HS_tty.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
HS_tty_State *HS_tty_init (void);

extern
bool HS_tty_do_some_work_from_HW (void *comms_state, HS_tty_State *state);

extern
bool HS_tty_do_some_work_towards_HW (void *comms_state, HS_tty_State *state);
