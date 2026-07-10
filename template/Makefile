TARGET := slide
SRC    := $(TARGET).md
HDR    := header.tex
PDF    := $(TARGET).pdf

.PHONY: all show watch clean

all: $(PDF)

$(PDF): $(HDR) $(SRC)
	pandoc --include-in-header=$(HDR) --pdf-engine=lualatex -t beamer $(SRC) -o $@

show: $(PDF)
	evince $(PDF)

watch:
	@echo "$(HDR)" > .watch_list
	@echo "$(SRC)" >> .watch_list
	@cat .watch_list | entr make

clean:
	rm -f $(PDF) .watch_list
