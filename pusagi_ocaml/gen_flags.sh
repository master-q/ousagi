#!/bin/sh
# Usage: gen_flags.sh cflags|lflags
case "$1" in
  cflags)
    flags=$(pkg-config --cflags poppler-glib)
    ;;
  lflags)
    flags=$(pkg-config --libs poppler-glib | sed 's/-l/-cclib -l/g')
    ;;
  *)
    echo "()" ; exit 0 ;;
esac
printf "("
for f in $flags; do
  printf '"%s" ' "$f"
done
printf ")"
