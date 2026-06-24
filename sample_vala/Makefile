PROG = pusagi
CFLAGS = -Wno-discarded-qualifiers

all: $(PROG)

$(PROG): $(PROG).vala
	valac $< --pkg gtk4 --pkg poppler-glib --pkg pangocairo -X $(CFLAGS)

format:
	uncrustify -c .uncrustify.cfg --replace --no-backup *.vala

clean:
	rm -f $(PROG)

.PHONY: all clean format
