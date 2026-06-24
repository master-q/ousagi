# Pusagi

Pusagi is a small GTK PDF presentation viewer with two progress markers:

- A turtle shows elapsed presentation time.
- A rabbit shows the current page position.

The idea is simple: while you present a PDF, you can see whether your page
progress is ahead of or behind your planned talk duration.

## Features

- Opens and displays PDF files.
- Centers PDF pages in both windowed and fullscreen layouts.
- Shows turtle and rabbit progress markers at the bottom of the window.
- Starts with the presentation timer paused.
- Toggles the presentation timer with the Space key.
- Lets you set the planned presentation duration from the command line.
- Supports smooth marker movement.
- Uses Pango/Cairo text rendering so emoji can use system font fallback.

## Requirements

Pusagi is written in Vala and uses GTK 4, Poppler GLib, Cairo, and Pango/Cairo.

On a typical Linux system, install the development packages for:

- `valac`
- `gtk4`
- `poppler-glib`
- `pangocairo`

For emoji display, an emoji font such as `Noto Color Emoji` is recommended.

## Build

```sh
$ make
```

This builds the `pusagi` executable in the repository directory.

To remove the executable:

```sh
$ make clean
```

## Usage

```sh
$ ./pusagi [OPTIONS] PDF_FILE
```

Examples:

```sh
$ ./pusagi slides.pdf
$ ./pusagi -t 15 slides.pdf
```

Options:

```text
  -t MINUTES      Set presentation duration in minutes (default: 5)
  -h, --help      Show help and exit
```

Running `pusagi` without a PDF file also prints the help message.

## Keyboard Controls

```text
  Space           Start or pause the presentation timer
  Left / Right    Move to the previous or next page
  Home / End      Move to the first or last page
  Esc             Quit
```

When the timer is paused, the turtle is shown in a resting state. Page
navigation still works while the timer is paused.

## Acknowledgements

Pusagi was inspired by [Rabbit](https://rabbit-shocker.org/ja/), a presentation
tool for programmers that includes a distinctive rabbit-and-turtle time display.

Most of the initial Pusagi code was written with assistance from ChatGPT and
Codex.

## License

Pusagi is released under the MIT License. See `LICENSE` for details.
