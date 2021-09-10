// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// See top of corresponding .c file for documentation

#pragma once

// ================================================================

#ifdef IN_F1
#include "fpga_pci.h"
#include "fpga_mgmt.h"
#include "fpga_dma.h"
#include "utils/lcd.h"
#endif

// ================================================================
// Host to hardware channels

#define HS_MSG_HOST_TO_HW_CHAN_ADDR_BASE          ((uint32_t) 0x00001000)

#define HS_MSG_HOST_TO_HW_CHAN_CONTROL            ((uint32_t) 0)
#define HS_MSG_HOST_TO_HW_CHAN_UART               ((uint32_t) 1)
#define HS_MSG_HOST_TO_HW_CHAN_VIRTIO_MMIO_RSP    ((uint32_t) 2)
#define HS_MSG_HOST_TO_HW_CHAN_DEBUG_MODULE       ((uint32_t) 3)
#define HS_MSG_HOST_TO_HW_CHAN_VIRTIO_IRQ         ((uint32_t) 4)

// ================================================================
// Hardware to host channels

#define HS_MSG_HW_TO_HOST_CHAN_ADDR_BASE          ((uint32_t) 0x00000000)

#define HS_MSG_HW_TO_HOST_CHAN_STATUS             ((uint32_t) 0)
#define HS_MSG_HW_TO_HOST_CHAN_UART               ((uint32_t) 1)
#define HS_MSG_HW_TO_HOST_CHAN_VIRTIO_MMIO_REQ    ((uint32_t) 2)
#define HS_MSG_HW_TO_HOST_CHAN_DEBUG_MODULE       ((uint32_t) 3)
#define HS_MSG_HW_TO_HOST_CHAN_PC_TRACE           ((uint32_t) 4)

// ================================================================

#include "HS_msg_protos.h"
