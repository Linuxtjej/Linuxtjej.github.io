# Target PDF and HTML files to build.
pdf=cv.pdf
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
# cv-%.md: $(data)
# 	perl scripts/json2cv.pl --type-lang=$* $(JSON2CVOPTS) --json=$< > $@

.PHONY: all letters markdown cleanall

all: default letters

letters:
	make -C letters

cleanall:
	make -C . clean
	make -C letters clean

publish: $(pdf_files) $(html_files)
	mkdir -p cv
	cp -auv $(html_files) cv
	mkdir -p cv/pdf
	cp -auv $(pdf_files) cv/pdf
	mkdir -p cv/templates
	cp -auv templates/pandoc-cv.css cv/templates
	mkdir -p cv/images
	cp -auv images cv
	rsync --archive --update --delete --verbose cv skalman@hirohito.acc.umu.se:public_html 

include $(BASEDIR)/Makefile.global
