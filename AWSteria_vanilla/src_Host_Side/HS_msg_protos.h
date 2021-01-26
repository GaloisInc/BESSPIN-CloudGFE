// This file is generated automatically from the file 'HS_msg.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "HS_msg_protos.h"
// You may also want to create/maintain a file 'HS_msg.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
int HS_msg_initialize (void);

extern
int HS_msg_finalize (void);

extern
int HS_msg_hw_to_host_STATUS_notEmpty (bool *p_notEmpty);

extern
int HS_msg_hw_to_host_STATUS_data (uint32_t *p_data);

extern
int HS_msg_host_to_hw_CONTROL_notFull (bool *p_notFull);

extern
int HS_msg_host_to_hw_CONTROL_data (uint32_t data);

extern
int HS_msg_hw_to_host_UART_notEmpty (bool *p_notEmpty);

extern
int HS_msg_hw_to_host_UART_data (uint32_t *p_data);

extern
int HS_msg_host_to_hw_UART_notFull (bool *p_notFull);

extern
int HS_msg_host_to_hw_UART_data (uint32_t data);

extern
int HS_msg_hw_to_host_DEBUG_MODULE_notEmpty (bool *p_notEmpty);

extern
int HS_msg_hw_to_host_DEBUG_MODULE_data (uint32_t *p_data);

extern
int HS_msg_host_to_hw_DEBUG_MODULE_notFull (bool *p_notFull);

extern
int HS_msg_host_to_hw_DEBUG_MODULE_data (uint32_t data);

extern
int HS_msg_hw_to_host_VIRTIO_MMIO_REQ_notEmpty (bool *p_notEmpty);

extern
int HS_msg_hw_to_host_VIRTIO_MMIO_REQ_data (uint32_t *p_data);

extern
int HS_msg_host_to_hw_VIRTIO_MMIO_RSP_notFull (bool *p_notFull);

extern
int HS_msg_host_to_hw_VIRTIO_MMIO_RSP_data (uint32_t data);

extern
int HS_msg_host_to_hw_VIRTIO_IRQ_notFull (bool *p_notFull);

extern
int HS_msg_host_to_hw_VIRTIO_IRQ_data (uint32_t data);
