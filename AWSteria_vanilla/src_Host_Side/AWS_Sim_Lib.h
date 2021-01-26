// Copyright (c) 2020-2021 Bluspec, Inc.  All Rights Reserved.
// Author: Rishiyur S. Nikhil

// Please see AWS_Sim_Lib.c for documentation

#pragma once

// Dummy declaration of this type (only relevant for F1 PCIe)
typedef int  pci_bar_handle_t;

// Default host is localhost
#define DEFAULT_HOSTNAME  "127.0.0.1"

#define DEFAULT_PORT 30000

#include "AWS_Sim_Lib_protos.h"
