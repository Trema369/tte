#!/bin/sh
cc -O2 -c vendor/stb_impl.c -o vendor/stb_impl.o
ar rcs vendor/libstb.a vendor/stb_impl.o
