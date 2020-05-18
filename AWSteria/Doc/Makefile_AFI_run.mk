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
# ONE-TIME STEP PER AMI: Remove the XOCL driver, and install the XDMA
# driver, if your software and AFI communicate via DMA over the
# DMA_PCIS port.
#
# cf.   https://github.com/aws/aws-fpga/blob/master/sdk/linux_kernel_drivers/xdma/xdma_install.md
#

# CAVEAT: the following steps worked when attempted on the "FPGA
# Developers AMI", which runs CentOS.  I recommend staying with this.

# It did not work when I tried it on an Ubuntu 18.04 AMI.
# The web page cited above says do the following instead of
# Step_6a_1_yum_installs:
#    $ sudo apt-get install make
#    $ sudo apt-get install gcc
# and proceeed, but there were complaints about a function 'mmiowb()'
# (which has recently been removed from the Linux kernel), number of
# arguments to some macro (which has recently changed in the Linux
# kernel), etc..

.PHONY: Step 6a_1_yum_installs
Step 6a_1_yum_installs:
	sudo yum groupinstall "Development tools"
	sudo yum install kernel kernel-devel

# Reboot the kernel, if necessary: The 'yum install kernel' above will
# say, in its messages, which version of the kernel it
# installed. Typing 'uname -a' will tell you which version of the
# kernel you're running.  These two should be the same.  If not,
# reboot your instance.  This will disconnect your ssh connection
# (although your instance will continuously show as 'running' in the
# AWS dashboard); reconnect after a minute or so, when it allows you.

.PHONY: Step 6a_2_Reboot
Step 6a_2_Reboot:
	@echo "Rebooting! This may break your terminal connection; please reconnect!"
	sudo shutdown -r now

# Build the XDMA driver (see caveat above about FPGA Developers AMI/CentOS vs Ubuntu):
.PHONY: Step 6a_3_Build_XDMA
Step 6a_3_Build_XDMA:
	@echo "If you have not yet dones Step_0c_Clone_aws-fpga please do so."
	cd  $(AWS_FPGA_REPO_DIR)/sdk/linux_kernel_drivers/xdma
	make

# The HDK README says the install of the XDMA driver (used by
# host-side software) may fail on Development AMI versions 1.5.x or
# later, which come with a preinstalled Xilinx Runtime Environment
# (XRT), which contains a pre-installed XOCL driver. This prevents
# installation of the XDMA driver. Please first remove the XOCL driver
# module.

.PHONY: Step_6b_1_remove_XOCL
Step_6b_0_check_XOCL:
	@echo "Checking if XOCL driver is running"
	lsmod | grep xocl
	@echo "If XOCL is present, it should in the listing"

.PHONY: Step_6b_2_remove_XOCL
Step_6b_1_remove_XOCL:
	@echo "Removing XOCL driver"
	sudo rmmod xocl

# Install the XDMA driver (will fail if XOCL driver is still in the kernel).

.PHONY: Step_6c_Install_XDMA_driver
Step_6c_Install_XDMA_driver:
	@echo "Installing XDMA driver"
	sudo make install
	sudo modprobe xdma
	@echo "Verify that xdma driver is present"
	lsmod | grep xdma
	@echo "You should see a line like:    xdma                   72503  0"

# ================================================================
# Build host-side software that interacts with the FPGA

.PHONY: Step_6d_build_SW
Step_6d_build_SW:
	@echo "Building host-side software"
	cd  $(CL_DIR)/software/runtime/
	make all

# ================================================================
# Run host-side software that interacts with the FPGA

.PHONY: Step_6e_run_SW
Step_6e_run_SW:
	@echo "Running host-side software, interacting with FPGA"
	@echo "Make sure you have the XDMA driver installed in the kernel"
	cd  $(CL_DIR)/software/runtime/
	sudo ./$(SW_EXE)

# ================================================================
