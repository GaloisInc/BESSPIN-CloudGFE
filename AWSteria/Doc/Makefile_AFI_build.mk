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

AWS_FPGA_REPO_DIR ?= $(HOME)/git_clones/AWS/aws-fpga
EMAIL             ?= nikhil@acm.org
CL_DIR            ?= $(AWS_FPGA_REPO_DIR)/hdk/cl/developer_designs/cl_BSV_WindSoC
REGION            ?= us-west-2

# Pick a name for a bucket to be created which will hold the DCP
DCP_BUCKET        ?= rsnbucket1
# Pick a sub-name inside the bucket to hold the DCP
DCP_FOLDER        ?= AWSteria
# DCP_FOLDER        ?= example-cl-dram-dma
# DCP_FOLDER        ?= HelloWorld

# standard test_dram_dma example
# DCP_TARFILE       ?= 20_05_16-210151.Developer_CL.tar
# AWSteria
# DCP_TARFILE       ?= 20_05_14-225622.Developer_CL.tar

# Pick a name for a bucket to be created which will hold the DCP
LOGS_BUCKET       ?= $(DCP_BUCKET)
# Pick a sub-name inside the bucket to hold AFI creation logs
LOGS_FOLDER       ?= $(DCP_FOLDER)-logs

# Pick a name for the AFI Image to be produced
# AFI_NAME          ?= RSN-example-cl-dram-dma
AFI_NAME          ?= RSNAwsteriaTest3

# Write a description for the AFI Image to be produced
# AFI_DESCRIPTION   ?= "RSN-example-cl-dram-dma"
AFI_DESCRIPTION   ?= "AWSteria take 3"

# There are additional vars described below close to where they're
# used, which you should edit for your use-case:
#     BUILD_DCP_FLAGS = ...
#     CREATE_FPGA_IMAGE_FLAGS = ...
# and the following will only be known after Step_2b_Build_DCP:
#     DCP_TARFILE = ...
# and the following will only be known after Step_3f_Start_AFI_Creation:
#     AFI_ID = ...
#     AGFI_ID = ...

# ================================================================
# Note: These steps are all required if starting from a blank slate.

# Some are one-time steps (e.g., merely setting up environment
# variables, git-cloning necessary repos, installing tools, etc.) that
# are not necessary when you repeat a build.  These are noted below.

# ================================================================
# Set up Vivado.
# Defines various Vivado and Xilinx environment variables.

.PHONY: Step_0a_Setup_Vivado
Step_0a_Setup_Vivado:
	@echo "Setting up Vivado; per process one-time step"
	source  /tools/Xilinx/Vivado/2019.1/settings64.sh

.PHONY: Step_0b_Vivado_check
Step_0b_Vivado_check:    # three different ways of checking
	@echo "Checking installation of Vivado"
	which vivado
	vivado  -version
	vivado  -mode batch

# ================================================================
# git clone the AWS-FPGA repository:

.PHONY: Step_0c_Clone_aws-fpga
Step_0c_Clone_aws-fpga:
	@echo "Cloning aws-fpga; one-time step into F1 instance"
	git clone  https://github.com/aws/aws-fpga.git  $(AWS_FPGA_REPO_DIR)

# ================================================================
# Install the AWS CLI (Command Line Interface) tool

.PHONY: Step_0d_Install_AWS_CLI
Step_0d_Install_AWS_CLI:
	@echo "Installing AWS CLI"
	sudo apt-get install awscli    # or  sudo yum install awscli  or ... (various package managers)
	@echo "Checking installation of AWS CLI"
	which aws
	aws  --version

# ================================================================
# Set up the Amazon AWS HDK (Hardware Design Kit).
# Defines HDK_DIR and other environment variables.
# The very first time you do this after downloading the aws-fpga repo,
# this can take several minutes, since it invokes Vivado to build ddr4
# models.

.PHONY: Step_0e_Setup_AWS_HDK
Step_0e_Setup_AWS_HDK:
	@echo "Setting up AWS-FPGA HDK; per process one-time step"
	cd  $(AWS_FPGA_REPO_DIR)
	source hdk_setup.sh

# ================================================================
# Move to design directory and define CL_DIR

.PHONY: Step_1a_Move_to_Design_Dir
Step_1a_Move_to_Design_Dir:
	@echo "cd'ing to design directory: $(CL_DIR)"
	cd $(CL_DIR)

# ================================================================
# Set up email address where long-running steps can notify you of completion
# May need 'pip install boto3' for python package 'boto3'
# When you run notify_via_sns.py, it will send you an email asking for
# you to click for confirmation, and pause waiting until you do so.
# Note: email confirmations go through sns.amazonaws.com

.PHONY: Step_2a_Setup_Email
Step_2a_Setup_Email:
	@echo "Setting up email addr '$(EMAIL)' for notifications; one-time step"
	$(AWS_FPGA_REPO_DIR)/shared/bin/scripts/notify_via_sns.py

# Note: This failed with a Python error: missing python package 'boto3'
#    Install that Python package, using:
#        pip install boto3        Python 2.x
#        pip3 install boto3       Python 3.x

# ****************************************************************
# ****************************************************************
# Build a design checkpoint (DCP file).

# This step can take a long time (does Vivado synthesis of your design)
# So, it runs in the background, in a 'nohup' environment, so that
#     continues even if your terminal goes away.
# Meanwhile, follow this log file to watch progress: yy_mm_dd-hhmmss.nohup.out
# The -notify flag sets up notification of completion by email.

# The following are options to script 'aws_build_dcp_from_cl.sh'
# Adjust them per your requirements

BUILD_DCP_FLAGS =                                # Default Clock Group A Recipe A0 (125 MHz)
BUILD_DCP_FLAGS += -notify                       # Notify completion by email
BUILD_DCP_FLAGS += -ignore_memory_requirement    # avoid ERROR: your instance has less mem than is necessary

# Other optional flags
# BUILD_DCP_FLAGS += -clock_recipe_a A1            # Clock Group A Recipe A1 (250 MHz)

# On an Amazon AMI, for resizing AMI to have more memory, see:
#     http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-resize.html
# During the build, there may be warnings.
#    For the standard given examples, known warnings are in: $(CL_DIR)/builds/scripts/warnings.txt

# When finished, it produces the following:
#        $(CL_DIR)/build/checkpoints/to_aws/YY_MM_DD-hhmm.Developer_CL.tar
#    comprising a DCP file, and other log/manifest files.
#    In a later step, the DCP file will be submitted to AWS to create an AFI.

# Checklist before running $CL_DIR/build/scripts/aws_build_dcp_from_cl.sh
# - Environment variables $HDK_SHELL_DIR and $CL_DIR are set
# - $CL_DIR directory has a /build sub-directory
# - the build/ directory has AWS recommended subdirectories:
#        constraints/
#        scripts/
#        src_post_encryption/
#   (I think the following are created by the script)
#        reports/
#        checkpoints/to_aws/
#
# - Update the following files for design-specific options:
#     - build/scripts/encrypt.tcl
#           list of all source files including header files (.inc, .h, .vh)
#               These will be copied to src_post_encryption/
#               and encrypted there (if you are re doing encryption)
#           and any other design-specifics.
#           Comment-out the last few 'encrypt' commands if you're not doing encryption
#     - build/scripts/create_dcp_from_cl.tcl
#           for your design specifics, specifically around IP sources
#           and xdc files, and your specific design xdc files.
#     - build/constraints/*.xdc
#           for timing and placement constraints

.PHONY: Step_2b_Build_DCP
Step_2b_Build_DCP:
	@echo "Doing synthesis of CL and creating DCP tarfile."
	@echo "This can take awhile."
	@echo "(for standard example Hello World, took 93 minutes on a t2.2xlarge AMI)."
	cd $(CL_DIR)/build/scripts
	./aws_build_dcp_from_cl.sh  $(BUILD_DCP_FLAGS)

.PHONY: Step_2c_Def_DCP_tarfile
Step_2c_Def_DCP_tarfile:
	ls  $(CL_DIR)/build/checkpoints/to_aws/*.Developer_CL.tar
	@echo "Please export DCP_TARFILE=<the DCP tarfile that was just created>."

# ****************************************************************
# ****************************************************************
# Upload the DCP for the AFI build

# ================================================================
# Create an S3 bucket to contain what you submit for an AFI build
# S3 is Amazon AWS' 'storage system'.
# Buckets are Amazon AWS 'storage units' in the cloud; they have
# globally unique names.
# NOTE: Amazon's rules for bucket names:
#    - 3 to 63 chars long
#    - lowercase letters, digits, hyphens
#          (in particular no underscores; dots allowed but nor recommended)
#    - must start and end with a letter or digit, not hyphen

.PHONY: Step_3a_Create_Buckets
Step_3a_Create_Buckets:
	aws s3 mb s3://$(DCP_BUCKET) --region $(REGION)

# You can list the buckets visible to you:
.PHONY: Step_3b_Show_Buckets
Step_3b_Show_Buckets:
	aws s3 ls

# Note: 3.0 When running on an Amazon AWS in an the AMI instance:
# 'FPGA Developer AMI-1.8.1', which has 'awscli' pre-installed, and
# where you think everything should work out-of-the-box, this failed
# with Python errors.  In fact all 'aws s3' commands failed.
# One suggestion, stealing some commands from FireSim:
#    sudo yum -y install python-pip
#    sudo pip install boto3
# But this did not fix it.  Then I did:
#    sudo pip install awscli
# to upgrade AWS CLI: it reported:
#     uninstalled botocore-1.16.7  and installed 1.8.32
#     uninstalled s2transfer-0.3.3 and installed s3transfer-0.1.13.
# and 'aws s3' commands started working.

# ----------------
# Create a 'folder' for the DCP (design checkpoint tarball)

# Note 3.1: it seems there are no actual folders on S3. Each bucket is
# a unique storage unit with a globally unique name but, for a
# convenient 'folder view', common prefixes ending in '/' are
# interpreted by AWS software and web interface as 'the same
# hierarchical directory/folder'.  This is why the 'create folder'
# command looks just like the 'create bucket' command (they're
# actually the same thing).

.PHONY: Step_3c_Create_Folder_for_DCP
Step_3c_Create_Folder_for_DCP:
	aws s3 mb s3://$(DCP_BUCKET)/$(DCP_FOLDER)/

# Note 3.2: This step did not work for me (and still does not)
# I always get this error:
#
#    make_bucket failed: s3://$(DCP_BUCKET)/$(DCP_FOLDER)/ An error occurred (BucketAlreadyOwnedByYou)
#        when calling the CreateBucket operation: Your previous request to create the named bucket
#        succeeded and you already own it.
#
#    But 'aws s3 ls' shows that it does not exist,
#    and viewing it from the S3 dashboard on the web also shows it does not exist.
#    The S3 dashboard on the web does have a button to create a
#        folder, and that worked.

# ----------------
# Upload the DCP file to S3 folder just created
# NOTE: the trailing '/' is necessary!

.PHONY: Step_3d_Upload_DCP
Step_3d_Upload_DCP:
	aws s3 cp  $(DCP_TARFILE)  s3://$(DCP_BUCKET)/$(DCP_FOLDER)/

# ----------------
# Create a folder for log files that will be generated during the AFI build,
# and move a temporary, empty file LOGS_FILES_GO_HERE.txt there.
# NOTE: the training '/' in the 3rd command is necessary!

.PHONY: Step_3e_Create_Folder_for_Logs
Step_3e_Create_Folder_for_Logs:
	touch LOGS_FILES_GO_HERE.txt
	aws s3 cp LOGS_FILES_GO_HERE.txt s3://$(DCP_BUCKET)/$(LOGS_FOLDER)/

# This example creates the LOGS_FOLDER 'inside' the DCP_BUCKET, but I
# think that is not necessary; the 'create-fpga-image' step below
# allows you to specify the bucket and folder for logs.
# aws s3 mb s3://$(DCP_BUCKET)/$(LOGS_FOLDER)/

# Note 3.3: As in Note 3.2, the first command (folder-creation) failed
#     for me, in the same way ('BucketAlreadyOwnedByYou').
#     I ignored it: the next two commands worked.
#     See note 6.1 above about there not actually being any folders,
#         if so, it makes sense that the latter two commands just work.

# ================================================================
# Submit the DCP to AWS so it can create the AFI from your DCP

CREATE_FPGA_IMAGE_FLAGS  = --region $(REGION)
CREATE_FPGA_IMAGE_FLAGS += --name $(AFI_NAME)
CREATE_FPGA_IMAGE_FLAGS += --description $(AFI_DESCRIPTION)
CREATE_FPGA_IMAGE_FLAGS += --input-storage-location Bucket=$(DCP_BUCKET),Key=$(DCP_FOLDER)/$(DCP_TARFILE)
CREATE_FPGA_IMAGE_FLAGS += --logs-storage-location Bucket=$(LOGS_BUCKET),Key=$(LOGS_FOLDER)

# Other flags of interest:
# CREATE_FPGA_IMAGE_FLAGS += --client-token <value>    # No idea what this does
# CREATE_FPGA_IMAGE_FLAGS += --dry-run
# CREATE_FPGA_IMAGE_FLAGS += --no-dry-run

.PHONY: Step_3f_Start_AFI_Creation
Step_3f_Start_AFI_Creation:
	@echo "Submitting DCP for AFI creation"
	aws ec2 create-fpga-image  $(CREATE_FPGA_IMAGE_FLAGS)
	@echo "Logs will be found in s3://$(LOGS_BUCKET)/$(LOGS_FOLDER)"

# aws ec2 create-fpga-image --region us-west-2 --name RSNAWSteriaTest --description "RSN AWSteria Test" --input-storage-location Bucket=rsnbucket1,Key=AWSteria/20_05_14-120442.Developer_CL.tar --logs-storage-location Bucket=rsnbucket1,Key=AWSteriaLogs

# The command will submit it to the cloud, and immediately print
# output that looks like this:
#    {
#        "FpgaImageId": "afi-0fced9721a34d8d99",
#        "FpgaImageGlobalId": "agfi-0cb465a4e98968670"
#    }
#
# You might want to save these somewhere, for reference.
#
#    AFI ID: FPGA Image Identifier: main ID used to manage the AFI
#        through AWS EC2 CLI commands and AWS SDK APIs. This ID is
#        regional, i.e., if an AFI is copied across multiple regions,
#        it will have a different unique AFI ID in each region. An
#        example AFI ID is afi-06d0ffc989feeea2a.
#
#    AGFI ID: Global FPGA Image Identifier: global ID to refer to an
#        AFI from within an F1 instance. E.g.,, to load or clear an AFI
#        from an FPGA slot, you use the AGFI ID. Since the AGFI IDs is
#        global (by design), it allows you to copy a combination of
#        AFI/AMI to multiple regions, and they will work without
#        requiring any extra setup. An example AGFI ID is
#        agfi-0f0e045f919413242

# Please define these based on the output of the command

# cl_test_dram_dma
# AFI_ID  = "afi-02231cb270e406e39"
# AFGI_ID = "agfi-043aaf12af3a36f89"

# AWSteria
# AFI_ID  = "afi-0d31f0d4cb999bf13"
# AGFI_ID = "agfi-083e63670297bf487"

# AWSteria Take 2
AFI_ID  = "afi-04ba5d8bc26c8815c"
AFGI_ID = "agfi-0c9627f3ac5f90023"


# ================================================================
# Wait for completion of AFI creation

# Study logs for success/failure
# Logs are in:    s3://$(LOGS_BUCKET)/$(LOGS_FOLDER)

.PHONY: Step_3g_AFI_Check_Status
Step_3g_AFI_Check_Status:
	aws ec2 describe-fpga-images --fpga-image-ids  $(AFI_ID)

# This will show a JSON/YAML output; look for
#    "State": { "Code" : "pending" or "available" or "failed" }

# ----------------
# Set up email notification of AFI build completion

# Your Step2 hdk_setup.sh will have set your PATH so you can directly
# execute this:
#     /home/nikhil/git_clones/AWS/aws-fpga/shared/bin/scripts/wait_for_afi.py

.PHONY: Step_3h_AFI_Notification
Step_3h_AFI_Notification:
	wait_for_afi.py --afi $(AFI_ID) --notify --email $(EMAIL)

# ================================================================
