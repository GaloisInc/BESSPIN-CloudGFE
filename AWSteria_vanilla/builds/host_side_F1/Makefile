###  -*-Makefile-*-

# Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved

#================================================================

ifndef AWSTERIA_REPO
  $(error ERROR: please define AWSTERIA_REPO (path to AWSteria repo))
endif

ifndef SDK_DIR
  $(error ERROR: please define SDK_DIR (path to aws-fpga repo))
endif

$(info INFO: Making executable for F1)
$(info INFO: Using SDK_DIR=$(SDK_DIR))

INCLUDES = -I$(SDK_DIR)/userspace/include
CFLAGS  += -DCONFIG_LOGLEVEL=4 $(INCLUDES)  -DIN_F1
LDLIBS   = -lfpga_mgmt
EXE      = exe_host_side_F1

#================================================================
# Common boilerplate rules

include $(AWSTERIA_REPO)/builds/Resources/Include_Common_host_side.mk

# ================================================================
