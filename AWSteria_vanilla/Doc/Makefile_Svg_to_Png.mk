Figs = \
	Fig_1_Build_Run_AWS_Example.png \
	Fig_2_AWS_BSV_XSim_Test.png \
	Fig_3_AWS_BSV_XSim_WindSoC.png \
	Fig_3_Detail.png \
	Fig_4_Debugger.png \
	Fig_4_System_Arch.png \
	Fig_5_Host_Side.png \
	Fig_6_AWS_BSV_Top_IFC.png \
	Fig_7_AWS_BSV_Top.png \
	Fig_8_AWS_SoC_Top.png \
	Fig_9_Core.png \


all: $(Figs)

$(Figs): %.png: %.svg
	inkscape --export-filename=$@  --export-area-drawing  -d 300 -y 0.0 $<

AWSteria_architecture.html: AWSteria_architecture.adoc  $(Figs)
	asciidoctor  AWSteria_architecture.adoc

# ================================================================

.PHONY: clean
clean:
	rm -r -f *~

.PHONY: full_clean
full_clean:
	rm -r -f *~  AWSteria_architecture.html  Fig*.png

# ================
# OLD STUFF

.PHONY: all_svg_to_png
all_svg_to_png:
	make  -f Makefile_Svg_to_Png.mk  svg_to_png  FIG=Fig_1_Build_Run_AWS_Example
	make  -f Makefile_Svg_to_Png.mk  svg_to_png  FIG=Fig_2_AWS_BSV_XSim_Test
	make  -f Makefile_Svg_to_Png.mk  svg_to_png  FIG=Fig_3_AWS_BSV_XSim_WindSoC
	make  -f Makefile_Svg_to_Png.mk  svg_to_png  FIG=Fig_3_Detail
	make  -f Makefile_Svg_to_Png.mk  svg_to_png  FIG=Fig_4_Debugger
	make  -f Makefile_Svg_to_Png.mk  svg_to_png  FIG=Fig_5_Host_Side

.PHONY: svg_to_png
svg_to_png:
	inkscape --export-filename=$(FIG).png \
	--export-area-drawing \
	-d 300 -y 0.0  $(FIG).svg
