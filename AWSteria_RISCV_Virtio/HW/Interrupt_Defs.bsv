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

typedef  16  N_External_Interrupt_Sources;
Integer  n_external_interrupt_sources_I = valueOf (N_External_Interrupt_Sources);

// Interrupt request numbers

Integer irq_num_uart16550_0 = 0;

Integer irq_num_host_to_hw  = 1;

// ================================================================

endpackage
