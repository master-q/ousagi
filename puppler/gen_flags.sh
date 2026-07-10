#!/bin/sh
set -eu

case "$1" in
  cflags)
    flags=$(pkg-config --cflags poppler-glib cairo)
    ;;
  lflags)
    flags=$(pkg-config --libs poppler-glib cairo)
    ;;
  *)
    echo "()"
    exit 0
    ;;
esac

printf "("
for flag in $flags; do
  printf '"%s" ' "$flag"
done
printf ")"
