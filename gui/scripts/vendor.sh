#!/bin/sh
set -e
cd "$(dirname "$0")/../vendor"

[ -d tree-sitter ] || git clone --depth 1 --branch v0.25.3 \
  https://github.com/tree-sitter/tree-sitter
[ -d ts-c3 ] || git clone --depth 1 https://github.com/c3lang/tree-sitter-c3 ts-c3
[ -f stb_truetype.h ] || curl -sLO \
  https://raw.githubusercontent.com/nothings/stb/master/stb_truetype.h

printf '#define STB_TRUETYPE_IMPLEMENTATION\n#include "stb_truetype.h"\n' > stb_impl.c
cc -O2 -c stb_impl.c -o stb_impl.o && ar rcs libstb.a stb_impl.o

cc -O2 -Itree-sitter/lib/include -Itree-sitter/lib/src \
   -c tree-sitter/lib/src/lib.c -o ts.o
ar rcs libtreesitter.a ts.o

cc -O2 -Its-c3/src -c ts-c3/src/parser.c  -o ts-c3-parser.o
cc -O2 -Its-c3/src -c ts-c3/src/scanner.c -o ts-c3-scanner.o
ar rcs libtsc3.a ts-c3-parser.o ts-c3-scanner.o
