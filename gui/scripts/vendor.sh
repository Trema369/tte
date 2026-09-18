#!/bin/sh
set -e
cd "$(dirname "$0")/../vendor"

[ -d tree-sitter ] || git clone --depth 1 --branch v0.25.3 \
  https://github.com/tree-sitter/tree-sitter
[ -d ts-c3 ] || git clone --depth 1 https://github.com/c3lang/tree-sitter-c3 ts-c3
[ -f stb_truetype.h ] || curl -sLO \
  https://raw.githubusercontent.com/nothings/stb/master/stb_truetype.h

[ -d ts-c ] || git clone --depth 1 https://github.com/tree-sitter/tree-sitter-c ts-c
[ -d ts-py ] || git clone --depth 1 https://github.com/tree-sitter/tree-sitter-python ts-py

cc -O2 -Its-c/src -c ts-c/src/parser.c -o ts-c-parser.o
ar rcs libtsc.a ts-c-parser.o

cc -O2 -Its-py/src -c ts-py/src/parser.c  -o ts-py-parser.o
cc -O2 -Its-py/src -c ts-py/src/scanner.c -o ts-py-scanner.o
ar rcs libtspy.a ts-py-parser.o ts-py-scanner.o

printf '#define STB_TRUETYPE_IMPLEMENTATION\n#include "stb_truetype.h"\n' > stb_impl.c
cc -O2 -c stb_impl.c -o stb_impl.o && ar rcs libstb.a stb_impl.o

cc -O2 -Itree-sitter/lib/include -Itree-sitter/lib/src \
   -c tree-sitter/lib/src/lib.c -o ts.o
ar rcs libtreesitter.a ts.o

cc -O2 -Its-c3/src -c ts-c3/src/parser.c  -o ts-c3-parser.o
cc -O2 -Its-c3/src -c ts-c3/src/scanner.c -o ts-c3-scanner.o
ar rcs libtsc3.a ts-c3-parser.o ts-c3-scanner.o
