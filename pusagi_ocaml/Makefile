PROG = pusagi
TEMPLATE_DATA = template_data.ml
TEMPLATE_FILES = \
	../template/Makefile \
	../template/header.tex \
	../template/img/takibi-icon-v3.jpg \
	../template/slide.md

all: $(PROG)

$(PROG): $(TEMPLATE_DATA)
	eval $$(opam env) && dune build && rm -f $(PROG) && cp _build/default/pusagi.exe $(PROG)

$(TEMPLATE_DATA): ../scripts/generate_template_modules.py $(TEMPLATE_FILES)
	python3 ../scripts/generate_template_modules.py ocaml $@ ../template

clean:
	eval $$(opam env) && dune clean
	rm -f $(PROG) $(TEMPLATE_DATA)

.PHONY: all clean
