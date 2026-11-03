#!/bin/sh
set -eu
recall_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$recall_root"
if command -v tectonic >/dev/null 2>&1; then
    recall_tex=$(command -v tectonic)
elif [ -x /Applications/ChatGPT.app/Contents/Resources/tectonic/tectonic ]; then
    recall_tex=/Applications/ChatGPT.app/Contents/Resources/tectonic/tectonic
else
    echo 'A Tectonic compiler is needed only to author diagrams, not to use the app.' >&2
    exit 1
fi
mkdir -p tmp/pdfs/unit-circle output/pdf
SOURCE_DATE_EPOCH=0 "$recall_tex" -X compile --untrusted --keep-logs --outdir tmp/pdfs/unit-circle Diagrams/unit-circle/main.tex
cp tmp/pdfs/unit-circle/main.pdf output/pdf/unit-circle.pdf
SOURCE_DATE_EPOCH=0 "$recall_tex" -X compile --untrusted --keep-logs --outdir tmp/pdfs/unit-circle Diagrams/unit-circle/dark.tex
cp tmp/pdfs/unit-circle/dark.pdf output/pdf/unit-circle-dark.pdf
printf 'Compiled output/pdf/unit-circle.pdf\n'
