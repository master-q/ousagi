PROG = pusagi

all: $(PROG)

$(PROG):
	cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build && cp build/pusagi $(PROG)

clean:
	cmake --build build --target clean 2>/dev/null || true
	rm -rf build $(PROG)

.PHONY: all clean
