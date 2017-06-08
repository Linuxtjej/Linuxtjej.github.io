markdown=$(wildcard *.md)
html=$(patsubst %.md, %.html, $(markdown))
pdf=$(patsubst %.md, %.pdf, $(markdown))
css=templates/pandoc-cv.css
context_style=templates/context.tex
latex_template=templates/latex-template.tex
latex_header=templates/latex-header.tex
pandoc_yaml=templates/pandoc.yaml
data=data/cv.json

#tmp_default: $(markdown)

all: $(markdown) $(pdf) $(html)

markdown: $(markdown)

cv-sv.md: $(data)
	perl scripts/json2cv.pl --lang=sv --type=recent --json=$< > $@

cv-en.md: $(data)
	perl scripts/json2cv.pl --lang=en --type=recent --json=$< > $@

cv-full-sv.md: $(data)
	perl scripts/json2cv.pl --lang=sv --type=full --json=$< > $@

cv-full-en.md: $(data)
	perl scripts/json2cv.pl --lang=en --type=full --json=$< > $@

cv-academic-sv.md: $(data)
	perl scripts/json2cv.pl --lang=sv --type=academic --json=$< > $@

cv-academic-en.md: $(data)
	perl scripts/json2cv.pl --lang=en --type=academic --json=$< > $@

%.pdf: %.md $(latex_header)
	pandoc --from=markdown --to=latex --output=$@ \
		--latex-engine=xelatex \
		--include-in-header=$(latex_header) --smart \
		--filter=pandoc-citeproc \
		$< $(pandoc_yaml)

%.tex: %.md $(latex_header)
	pandoc --from=markdown --to=latex --output=$@ \
		--latex-engine=xelatex \
		--include-in-header=$(latex_header) --smart \
		$< $(pandoc_yaml)

%.html: %.md $(css)
	pandoc --standalone --smart --css=$(css) \
		--from markdown --to html \
		--include-in-header=templates/header.html \
		-o $@ $<

clean:
	rm -f $(pdf) $(html)
	rm -f $(patsubst %.pdf, %.log, $(pdf))
	rm -f $(patsubst %.pdf, %.tuc, $(pdf))
