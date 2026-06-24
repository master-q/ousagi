PROG = pusagi

all: $(PROG)

$(PROG):
	eval $$(opam env) && dune build && cp _build/default/pusagi.exe $(PROG)

clean:
	eval $$(opam env) && dune clean
	rm -f $(PROG)

.PHONY: all clean
