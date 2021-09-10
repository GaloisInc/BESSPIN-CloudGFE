// This file is generated automatically from the file 'HS_gdbstub.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "HS_gdbstub_protos.h"
// You may also want to create/maintain a file 'HS_gdbstub.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
HS_Gdbstub_State *HS_gdbstub_init (void *comms_state, unsigned short port);

extern
bool HS_gdbstub_do_some_work (void *comms_state, HS_Gdbstub_State *p_state);

extern
void HS_gdbstub_finish (void *comms_state, HS_Gdbstub_State *p_state);

// ****************************************************************
// ****************************************************************
// ****************************************************************
// The following are used from inside the gdbstub code to interact
// with the Debug Module.

extern
void dmi_write (FILE *logfile_fp, uint16_t addr, uint32_t data);

extern
uint32_t  dmi_read  (FILE *logfile_fp, uint16_t addr);

// ================================================================
