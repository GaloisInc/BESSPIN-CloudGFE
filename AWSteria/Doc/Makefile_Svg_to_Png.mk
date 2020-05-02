.PHONY: all_svg_to_png
all_svg_to_png:
	make  -f Makefile_Svg_to_Png.mk  FIG=Fig_1_Build_Run_AWS_Example  svg_to_png
	make  -f Makefile_Svg_to_Png.mk  FIG=Fig_2_AWS_BSV_XSim_Test      svg_to_png
	make  -f Makefile_Svg_to_Png.mk  FIG=Fig_3_AWS_BSV_XSim_WindSoC   svg_to_png
	make  -f Makefile_Svg_to_Png.mk  FIG=Fig_3_Detail                 svg_to_png
	make  -f Makefile_Svg_to_Png.mk  FIG=Fig_4_Debugger               svg_to_png

.PHONY: svg_to_png
svg_to_png:
	inkscape --file=$(FIG).svg \
		--export-png=$(FIG).png \
		--export-area-drawing \
		-d 300 -y 0.0
