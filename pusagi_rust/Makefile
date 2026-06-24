.PHONY: all build release clean

all: release

release:
	cargo build --release
	cp target/release/pusagi pusagi

build:
	cargo build

clean:
	cargo clean
	rm -f pusagi
