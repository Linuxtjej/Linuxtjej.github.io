BASEDIR=.
include $(BASEDIR)/Makefile.defs

cv_pdf=cv-sv.pdf cv-en.pdf cv-full-sv.pdf cv-full-en.pdf cv-academic-sv.pdf cv-academic-en.pdf

all: $(markdown) $(pdf) $(cv_pdf) $(html) letters umu cv-academic

.PHONY: letters umu markdown cv-academic

letters:
	make -C letters

umu:
	make -C cv-academic/umu

cv-academic:
	make -C cv-academic

markdown: $(markdown)

cv-sv.md: $(data)
	perl scripts/json2cv.pl --lang=sv --type=recent --contact $(JSON2CVOPTS) --json=$< > $@

cv-en.md: $(data)
	perl scripts/json2cv.pl --lang=en --type=recent --contact $(JSON2CVOPTS) --json=$< > $@

cv-full-sv.md: $(data)
	perl scripts/json2cv.pl --lang=sv --type=full --contact $(JSON2CVOPTS) --json=$< > $@

cv-full-en.md: $(data)
	perl scripts/json2cv.pl --lang=en --type=full --contact $(JSON2CVOPTS) --json=$< > $@

cv-academic-sv.md: $(data)
	perl scripts/json2cv.pl --lang=sv --type=academic $(JSON2CVOPTS) --json=$< > $@

cv-academic-en.md: $(data)
	perl scripts/json2cv.pl --lang=en --type=academic $(JSON2CVOPTS) --json=$< > $@

cleanall:
	make -C . clean
	make -C letters clean
	make -C cv-academic clean
	make -C cv-academic/umu clean

applications:
	JSON2CVOPTS=--personal make

include $(BASEDIR)/Makefile.global
