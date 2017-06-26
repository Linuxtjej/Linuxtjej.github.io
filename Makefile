BASEDIR=.
include $(BASEDIR)/Makefile.defs

all: $(markdown) $(pdf) $(html) letters umu

.PHONY: letters umu markdown

letters:
	make -C letters

umu:
	make -C cv-academic/umu

markdown: $(markdown)

cv-sv.md: $(data)
	perl scripts/json2cv.pl --lang=sv --type=recent --contact --json=$< > $@

cv-en.md: $(data)
	perl scripts/json2cv.pl --lang=en --type=recent --contact --json=$< > $@

cv-full-sv.md: $(data)
	perl scripts/json2cv.pl --lang=sv --type=full --contact --json=$< > $@

cv-full-en.md: $(data)
	perl scripts/json2cv.pl --lang=en --type=full --contact --json=$< > $@

cv-academic-sv.md: $(data)
	perl scripts/json2cv.pl --lang=sv --type=academic --json=$< > $@

cv-academic-en.md: $(data)
	perl scripts/json2cv.pl --lang=en --type=academic --json=$< > $@

cleanall:
	make -C . clean
	make -C letters clean
	make -C cv-academic/umu clean

include $(BASEDIR)/Makefile.global
