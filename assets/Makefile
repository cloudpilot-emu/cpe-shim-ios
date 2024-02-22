WIDTH_1X = 240
WIDTH_2X = 480
WIDTH_3X = 620

INKSCAPE = /Applications/Inkscape.app/Contents/MacOS/inkscape

DERIVED = \
	launch_1x.png \
	launch_2x.png \
	launch_3x.png \
	launch_dark_1x.png \
	launch_dark_2x.png \
	launch_dark_3x.png

all: $(DERIVED)

%_1x.png: %.svg Makefile
	$(INKSCAPE) -w $(WIDTH_1X) -h $(WIDTH_1X) $< -o $@

%_2x.png: %.svg Makefile
	$(INKSCAPE) -w $(WIDTH_2X) -h $(WIDTH_2X) $< -o $@

%_3x.png: %.svg Makefile
	$(INKSCAPE) -w $(WIDTH_3X) -h $(WIDTH_3X) $< -o $@

clean:
	-rm -f $(DERIVED)