// Copyright (c) 2019 Bluespec, Inc.  All Rights Reserved

// ================================================================
// Client communications for DSharp

// Sends and receives bytevecs over a TCP socket to/from a remote server

// ================================================================

#define   status_err      0
#define   status_ok       1
#define   status_unavail  2

// ================================================================
// Open a TCP socket as a client connected to specified remote
// listening server socket.

extern
uint32_t  tcp_client_open (const char *server_host, const uint16_t server_port);

// ================================================================
// Close the connection to the remote server.

extern
uint32_t  tcp_client_close (uint32_t dummy);

// ================================================================
// Send a message

extern
uint32_t  tcp_client_send (const uint32_t data_size, const char *data);

// ================================================================
// Recv a message

extern
uint32_t  tcp_client_recv (bool poll, const uint32_t data_size, char *data);

// ================================================================
