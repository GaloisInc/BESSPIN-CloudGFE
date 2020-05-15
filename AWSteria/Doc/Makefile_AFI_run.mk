# This is one of two related Makefiles:
# 1. The first one shows the steps to create an AFI (Amazon AWS FPGA image).
# 2. The second one shows the steps to run such an AFI on an F1 AMI
#     (Amazon Machine Instance with FPGA attached)

# These are separated into two Makefiles because they can be done
# independently on entirely separate machines, and of course
# AFI-running will typically be done multiple times per AFI-creation.
# AFI-creation can be run on 'customer premises' machines. AFI-running
# must of course be done on an Amazon AWS F1 instance.

# The original reference for both is:
#    https://github.com/aws/aws-fpga/tree/master/hdk

# These Makefiles provide an executable copy of those commands, and
# documents in more detail what each command does; and describes
# issues I faced and my solutions/workarounds.  The numeric step
# numbers below correspond to step numbers in that original reference.

# Created May 12, 2020, by Rishiyur S. Nikhil

# ================================================================
# The following variables should be defined for your environment/
# use-case.

AWS_FPGA_REPO_DIR = $(HOME)/git_clones/AWS/aws-fpga
CL_DIR            = $(AWS_FPGA_DIR)/hdk/cl/examples/cl_hello_world
SW_EXE            = test_hello_world

# The following will only be known after Step_3f_Start_AFI_Creation:

AFI_ID  = "afi-0d31f0d4cb999bf13"
AGFI_ID = "agfi-083e63670297bf487"

# ================================================================
# git clone the GitHub AWS-FPGA repository into your F1 instance

.PHONY: Step_0c_Clone_aws-fpga
Step_0c_Clone_aws-fpga:
	@echo "Cloning aws-fpga; one-time step into F1 instance"
	git clone  https://github.com/aws/aws-fpga.git  $(AWS_FPGA_REPO_DIR)

# ================================================================
# Set up AWS FPGA Management tools
# Note: will prompt for password; does some sub-steps as 'root'

.PHONY: Step_4a_Setup_FPGA_Mgmt_Tools
Step_4a_Setup_FPGA_Mgmt_Tools:
	cd  $(AWS_FPGA_REPO_DIR)
	source sdk_setup.sh

# ================================================================
# Configure AWS to set your credentials, in the usual way
# Note: will prompt for password; does some sub-steps as 'root'

.PHONY: Step_4b_AWS_config
Step_4b_AWS_config:
	aws configure

# ================================================================
# Previously loaded AFIs: status and clearing

.PHONY: Step_5a_see_old_AFI
Step_5a_see_old_AFI:
	@echo "Examining status of existing AFI, if any, in Slot 0"
	sudo fpga-describe-local-image -S 0 -H

# Your output may look like this (if your instance has an FPGA device)
#
#    Type  FpgaImageSlot  FpgaImageId             StatusName    StatusCode   ErrorName    ErrorCode   ShVersion
#    AFI          0       none                    cleared           1        ok               0       <shell_version>
#    Type  FpgaImageSlot  VendorId    DeviceId    DBDF
#    AFIDEVICE    0       0x1d0f      0x1042      0000:00:0f.0

# ================================================================
# Clear any previously loaded AFI

.PHONY: Step_5b_clear_old_AFI
Step_5b_clear_old_AFI:
	@echo "Clearing existing AFI in Slot 0"
	sudo fpga-clear-local-image  -S 0

# ================================================================
# Load new AFI.
# Please define AGFI_ID for your desired AFI (given to you after Step_3f)
# Note: optional flag '-a 87' or '-a 97' will run at 87 MHz or 97 MHz.

.PHONY: Step_5c_load_AFI
Step_5c_load_AFI:
	@echo "Loading new AFI in Slot 0"
	sudo fpga-load-local-image -S 0 -I $(AGFI_ID)    # Note: AGFI_ID, not AFI_ID
	@echo "Verifying new AFI loaded in Slot 0"
	sudo fpga-describe-local-image -S 0 -R -H    # -R forces PCI to refresh AFI Vendor and Device ID

# ================================================================
# The HDK README says, the install of the XDMA driver (used by
# host-side software) may fail on Development AMI versions 1.5.x or
# later, which come with a preinstalled Xilinx Runtime Environment
# (XRT), which contains a pre-installed XOCL driver. This prevents
# installation of the XDMA driver. Please remove the XOCL driver
# module.

.PHONY: Step_6a_remove_XOCL
Step_6a_check_XOCL:
	@echo "Checking if XOCL driver is running"
	lsmod | grep xocl

.PHONY: Step_6b_remove_XOCL
Step_6b_remove_XOCL:
	@echo "Removing XOCL driver"
	sudo rmmod xocl

# ================================================================
# Build host-side software that interacts with the FPGA

.PHONY: Step_6c_build_SW
Step_6c_build_SW:
	@echo "Building host-side software"
	cd  $(CL_DIR)/software/runtime/
	make all

# ================================================================
# Run host-side software that interacts with the FPGA

.PHONY: Step_6d_run_SW
Step_6d_run_SW:
	@echo "Running host-side software, interacting with FPGA"
	cd  $(CL_DIR)/software/runtime/
	sudo ./$(SW_EXE)

# ================================================================
