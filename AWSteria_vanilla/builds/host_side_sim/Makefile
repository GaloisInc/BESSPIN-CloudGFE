###  -*-Makefile-*-

# Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved

#================================================================

ifndef AWSTERIA_REPO
  $(error ERROR: please define AWSTERIA_REPO (path to AWSteria repo))
endif

$(info INFO: Making executable for Bluesim/verilator sim)

CFLAGS = -DIN_SIMULATION
OBJS   = AWS_Sim_Lib.o  Bytevec.o  TCP_Client_Lib.o
EXE    = exe_host_side_SIM

#================================================================
# Common boilerplate rules

include $(AWSTERIA_REPO)/builds/Resources/Include_Common_host_side.mk

# ================================================================
