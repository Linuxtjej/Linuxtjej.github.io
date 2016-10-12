source=$(wildcard *.md)
html=$(patsubst %.md, %.html, $(source))
pdf=$(patsubst %.md, %.pdf, $(source))
css=templates/pandoc-cv.css
context_style=templates/context.tex
latex_template=templates/latex-template.tex
latex_header=templates/latex-header.tex

all: $(html) $(pdf)

%.pdf: %.md $(latex_header)
	pandoc --from=markdown --to=latex --output=$@ \
		--latex-engine=xelatex \
		--include-in-header=$(latex_header) --smart \
		-V papersize=A4 -V fontsize=12pt \
		-V geometry=hmargin=25mm -V geometry=top=25mm \
		-V mainfont="Minion Pro" -V mainfontoptions="Numbers=OldStyle" \
		$<

%.tex: %.md $(latex_header)
	pandoc --from=markdown --to=latex --output=$@ \
		--latex-engine=xelatex \
		--include-in-header=$(latex_header) --smart \
		-V papersize=A4 -V fontsize=12pt \
		-V geometry=hmargin=25mm -V geometry=top=25mm \
		-V mainfont="Minion Pro" -V mainfontoptions="Numbers=OldStyle" \
		$<

%.html: %.md $(css)
	pandoc --standalone --smart --css=$(css) \
		--from markdown --to html \
		--include-in-header=templates/header.html \
		-o $@ $<

clean:
	rm -f $(pdf) $(html)
	rm -f $(patsubst %.pdf, %.log, $(pdf))
	rm -f $(patsubst %.pdf, %.tuc, $(pdf))
