#!/usr/bin/env make
SHELL := /bin/bash
.ONESHELL:

RES_IMG := res/img/cover.png res/img/timeline.png

.PHONY: help
help:
	@echo 'Makefile for the Cynnexis cover page'
	echo
	echo 'usage: make [command]'
	echo
	echo 'Command:'
	echo "  img               - Export the SVG images to PNG."
	echo

%.png: %.svg
	res/scripts/svg2png.bash --input="$<" --output="$@" --force --verbose

.PHONY: img
img: $(RES_IMG)
