// Copyright (c) 2021 Bluespec, Inc. All Rights Reserved
// Author: Rishiyur S. Nikhil

package Interrupt_Defs;

// ================================================================
// This module defines the number of external interrupt sources
// coming into AWSteria_Core.

// ================================================================
// Imports

// None

// ================================================================

typedef  5  N_External_Interrupt_Sources;
Integer  n_external_interrupt_sources_I = valueOf (N_External_Interrupt_Sources);

// Interrupt request numbers

Integer irq_num_uart16550_0   = 0;

Integer irq_num_host_to_hw_1  = 1;
Integer irq_num_host_to_hw_2  = 2;
Integer irq_num_host_to_hw_3  = 3;
Integer irq_num_host_to_hw_4  = 4;

Integer irq_num_max           = 4;

// ================================================================

endpackage
