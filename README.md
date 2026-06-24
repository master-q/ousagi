# Other ports of pusagi — multi-language PDF presentation tool

Pusagi is a small PDF presentation viewer with two animated progress markers:

- A **turtle** 🐢 shows how far through the planned presentation time you are.
- A **rabbit** 🐇 shows how far through the slides you are.

While you present, you can glance at the bottom of the screen and see at a
glance whether your page progress is ahead of or behind your planned talk
duration.

## Implementations

The same application is implemented in six languages as a comparison study:

| Directory | Language / Toolkit | Source lines |
|---|---|---|
| `pusagi_vala/` | Vala + GTK4 + Poppler | 317 |
| `pusagi_ocaml/` | OCaml + GTK3 + Poppler (C stubs) | 306 (98 C + 208 ML) |
| `pusagi_qt6/` | C++ + Qt6 (QtPdf built-in) | 218 |
| `pusagi_qml6/` | C++ + QML + Qt6 (QtPdf built-in) | 221 (123 C++ + 98 QML) |
| `pusagi_rust/` | Rust + GTK4 + Poppler (inline FFI) | 496 |
| `pusagi_haskell/` | Haskell + GTK3 + gi-poppler | 334 |

## Features

- Opens and renders PDF files via Poppler or QtPdf.
- Centers each page within the window.
- Displays turtle and rabbit emoji progress markers at the bottom of the window.
- Starts with the presentation timer paused.
- Toggles the timer with the Space key; the turtle shows 🐢💤 while paused.
- Accepts a custom presentation duration from the command line.
- Animates marker movement with a lerp smoothing function.

## Dependencies

### Vala (`pusagi_vala/`)

```sh
sudo apt-get install valac libgtk-4-dev libpoppler-glib-dev
```

### OCaml (`pusagi_ocaml/`)

```sh
sudo apt-get install libpoppler-glib-dev
opam install dune lablgtk3 cairo2
```

### C++ / Qt6 (`pusagi_qt6/`)

```sh
sudo apt-get install cmake qt6-base-dev libqt6pdf6-dev fonts-noto-color-emoji
```

### QML / Qt6 (`pusagi_qml6/`)

```sh
sudo apt-get install cmake qt6-base-dev qt6-declarative-dev libqt6pdf6-dev fonts-noto-color-emoji
```

### Rust (`pusagi_rust/`)

```sh
sudo apt-get install libgtk-4-dev libpoppler-glib-dev
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Haskell (`pusagi_haskell/`)

```sh
sudo apt-get install libgtk-3-dev libpoppler-glib-dev
curl --proto '=https' --tlsv1.2 -sSf https://get-haskellstack.org | sh
# or via ghcup (GHC 9.6 or later required on Debian 13+):
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
```

For emoji display, install `fonts-noto-color-emoji` on all platforms.

## Build

Build all implementations at once from the repository root:

```sh
make
```

Or build a single implementation:

```sh
make pusagi_vala
make pusagi_ocaml
make pusagi_qt6
make pusagi_qml6
make pusagi_rust
make pusagi_haskell
```

Clean everything:

```sh
make clean
```

Each sub-directory also has its own `Makefile` that can be used independently.

## Usage

All implementations share the same interface:

```sh
./pusagi [OPTIONS] PDF_FILE
```

Examples:

```sh
./pusagi slides.pdf
./pusagi -t 15 slides.pdf
```

Options:

```
  -t MINUTES      Set presentation duration in minutes (default: 5)
  -h, --help      Show help and exit
```

Running `pusagi` without arguments prints the help message.

## Keyboard Controls

```
  Space           Start or pause the presentation timer
  Left / Right    Move to the previous or next page
  Home / End      Move to the first or last page
  Esc             Quit
```

Page navigation works while the timer is paused.

## Acknowledgements

Pusagi was inspired by [Rabbit](https://rabbit-shocker.org/ja/), a presentation
tool for Ruby programmers that features a distinctive rabbit-and-turtle progress
display.

The implementations were written with assistance from Claude Code.

## License

MIT License. See `LICENSE` for details.
