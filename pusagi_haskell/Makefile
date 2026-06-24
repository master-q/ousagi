.PHONY: all build clean run install check-deps

BINUTILS_OK := $(shell which ld 2>/dev/null)
GTK3_OK     := $(shell pkg-config --exists gtk+-3.0 2>/dev/null && echo yes)
POPPLER_OK  := $(shell pkg-config --exists poppler-glib 2>/dev/null && echo yes)

all: check-deps build

check-deps:
ifndef BINUTILS_OK
	$(error "'ld' not found. Install binutils: sudo apt-get install -y binutils")
endif
ifndef GTK3_OK
	$(error "GTK3 not found. Install: sudo apt-get install -y libgtk-3-dev")
endif
ifndef POPPLER_OK
	$(error "Poppler not found. Install: sudo apt-get install -y libpoppler-glib-dev")
endif

build:
	cabal build
	cp $$(cabal list-bin pusagi) pusagi

clean:
	cabal clean
	rm -f pusagi

run:
	cabal run pusagi -- $(PDF)

install:
	cabal install --overwrite-policy=always
