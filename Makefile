source=cv-sv.md cv-en.md cv-full-sv.md cv-full-en.md cv-it-sv.md
html=$(patsubst %.md, %.html, $(source))
pdf=$(patsubst %.md, %.pdf, $(source))
css=templates/pandoc-cv.css
context_style=templates/context.tex
latex_template=templates/latex-template.tex
latex_header=templates/latex-header.tex
pandoc_yaml=templates/pandoc.yaml

#tmp_default: $(source)

all: $(pdf) $(html)

cv-sv.md: cv.json
	perl scripts/json2cv.pl --lang=sv --type=recent --json=$< > $@

cv-en.md: cv.json
	perl scripts/json2cv.pl --lang=en --type=recent --json=$< > $@

cv-full-sv.md: cv.json
	perl scripts/json2cv.pl --lang=sv --type=full --json=$< > $@

cv-full-en.md: cv.json
	perl scripts/json2cv.pl --lang=en --type=full --json=$< > $@

cv-it-sv.md: cv.json
	perl scripts/json2cv.pl --lang=sv --type=it --json=$< > $@


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
