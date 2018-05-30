# Target PDF and HTML files to build.
pdf=cv-sv.pdf cv-en.pdf cv-full-sv.pdf cv-full-en.pdf cv-academic-sv.pdf cv-academic-en.pdf
html=$(patsubst %.pdf,%.html,$(pdf)) index.html

# Global options to json2cv.pl, usually --contacts or --personal.
JSON2CVOPTS=--contact

# Base directory
BASEDIR=.

# Include global definitions
include $(BASEDIR)/Makefile.defs

# Default rule
default: $(pdf_files) $(html_files)

# Implicit rule for creating markdown CV:s of different types/languages.
cv-%.md: $(data)
	perl scripts/json2cv.pl --type-lang=$* $(JSON2CVOPTS) --json=$< > $@

.PHONY: all letters umu markdown cv-academic cleanall

all: default letters umu cv-academic

letters:
	make -C letters

umu:
	make -C cv-academic/umu

cv-academic:
	make -C cv-academic

cleanall:
	make -C . clean
	make -C letters clean
	make -C cv-academic clean
	make -C cv-academic/umu clean

include $(BASEDIR)/Makefile.global
