// This file is generated automatically from the file 'TCP_Client_Lib.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "TCP_Client_Lib_protos.h"
// You may also want to create/maintain a file 'TCP_Client_Lib.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
uint32_t  tcp_client_open (const char *server_host, const uint16_t server_port);

extern
uint32_t  tcp_client_close (uint32_t dummy);

extern
uint32_t  tcp_client_send (const uint32_t data_size, const uint8_t *data);

extern
uint32_t  tcp_client_recv (bool do_poll, const uint32_t data_size, uint8_t *data);
