PROG = pusagi
CFLAGS = -Wno-discarded-qualifiers
RESOURCE_XML = pusagi.gresource.xml
RESOURCE_C = pusagi-resources.c
TEMPLATE_FILES = \
	../template/Makefile \
	../template/header.tex \
	../template/img/takibi-icon-v3.jpg \
	../template/slide.md

all: $(PROG)

$(PROG): $(PROG).vala $(RESOURCE_C)
	valac $(PROG).vala $(RESOURCE_C) --pkg gtk4 --pkg poppler-glib --pkg pangocairo -X $(CFLAGS)

$(RESOURCE_C): $(RESOURCE_XML) $(TEMPLATE_FILES)
	glib-compile-resources --target=$@ --sourcedir=.. --generate-source $(RESOURCE_XML)

format:
	uncrustify -c .uncrustify.cfg --replace --no-backup *.vala

clean:
	rm -f $(PROG) $(RESOURCE_C)

.PHONY: all clean format
