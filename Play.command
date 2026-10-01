#!/bin/zsh
cd -- "${0:A:h}" || exit 1
exec /usr/local/bin/node tools/play.mjs
