source=cv-sv.md cv-academic-sv.md
html=$(patsubst %.md, %.html, $(source))
pdf=$(patsubst %.md, %.pdf, $(source))
css=templates/style.css
context_style=templates/context.tex

all: $(html) $(pdf)

%.pdf: %.md $(context_style)
	pandoc --standalone --template $(context_style) \
	--from markdown --to context \
	-V papersize=A4 \
	-o $*.tex $<; \
	context --nonstopmode $*.tex

%.html: %.md $(css)
	pandoc --standalone --self-contained --smart --css=$(css) \
        --from markdown --to html \
        -o $@ $<

clean:
	rm -f $(pdf) $(html) $(docx) $(rtf)
	rm -f $(patsubst %.pdf, %.log, $(pdf))
	rm -f $(patsubst %.pdf, %.tuc, $(pdf))
