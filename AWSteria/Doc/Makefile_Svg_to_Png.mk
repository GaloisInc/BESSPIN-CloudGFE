Figs = \
	Fig_1_Build_Run_AWS_Example.png \
	Fig_2_AWS_BSV_XSim_Test.png \
	Fig_3_AWS_BSV_XSim_WindSoC.png \
	Fig_3_Detail.png \
	Fig_4_Debugger.png \


all: $(Figs)

$(Figs): %.png: %.svg
	inkscape --export-filename=$@  --export-area-drawing  -d 300 -y 0.0 $<
