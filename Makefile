source=cv-sv.md cv-academic-sv.md
html=$(patsubst %.md, %.html, $(source))
pdf=$(patsubst %.md, %.pdf, $(source))
css=templates/style.css
context_style=templates/context.tex

all: $(html) $(pdf)

%.tex: %.md $(context_style)
	pandoc --standalone --template $(context_style) \
	--from markdown --to context \
	-V papersize=A4 \
	-o $@ $<

%.pdf: %.tex
	context --nonstopmode $<

%.html: %.md $(css)
	pandoc --standalone --self-contained --smart --css=$(css) \
        --from markdown --to html \
        -o $@ $<

clean:
	rm -f $(pdf) $(html)
	rm -f $(patsubst %.pdf, %.log, $(pdf))
	rm -f $(patsubst %.pdf, %.tuc, $(pdf))
