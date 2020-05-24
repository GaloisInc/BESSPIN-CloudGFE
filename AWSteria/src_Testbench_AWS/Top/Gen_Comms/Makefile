COMMS_FILES = Comms.bsv  Comms.c  Comms.h

HELP_GEN     = "Generate files {$(COMMS_FILES)} locally"
HELP_INSTALL = "Move {$(COMMS_FILES)} files up to parent dir"

GEN_PY      = Gen.py

# Edit this for your environment
GEN_PY_PATH = $(HOME)/Apps/Python/BSV_C_Communication/Gen

.PHONY: help
help:
	@echo  "Usage:"
	@echo  "    make gen        $(HELP_GEN)    (Needs tool $(GEN_PY))"
	@echo  "    make install    $(HELP_INSTALL)"

.PHONY: gen
gen:
	@echo "---- $(HELP_GEN)    (Needs tool $(GEN_PY))"
	$(GEN_PY_PATH)/$(GEN_PY)  AWS_FPGA_Spec.py

.PHONY: install
install:
	@echo "---- $(HELP_INSTALL)"
	mv  $(COMMS_FILES)  ..

.PHONY: clean
clean:
	rm -f  *~

.PHONY: full_clean
full_clean:
	rm -f  *~  $(COMMS_FILES)
