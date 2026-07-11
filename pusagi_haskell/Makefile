.PHONY: all build clean run install check-deps

TEMPLATE_DATA = app/TemplateData.hs
TEMPLATE_FILES = \
	../template/Makefile \
	../template/header.tex \
	../template/img/takibi-icon-v3.jpg \
	../template/slide.md

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

build: $(TEMPLATE_DATA)
	cabal build
	rm -f pusagi
	cp $$(cabal list-bin pusagi) pusagi

$(TEMPLATE_DATA): ../scripts/generate_template_modules.py $(TEMPLATE_FILES)
	python3 ../scripts/generate_template_modules.py haskell $@ ../template

clean:
	cabal clean
	rm -f pusagi $(TEMPLATE_DATA)

run:
	cabal run pusagi -- $(PDF)

install:
	cabal install --overwrite-policy=always
