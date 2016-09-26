source=cv-sv.md cv-academic-sv.md
html=$(patsubst %.md, %.html, $(source))
pdf=$(patsubst %.md, %.pdf, $(source)) $(patsubst %.md, %-pandoc.pdf, $(source))
css=templates/style.css
context_style=templates/context.tex
pandoc_opts=-V papersize=A4 \
	        -V geometry=hmargin=25mm -V geometry=top=25mm \
	        -V fontsize=12pt \
            -V mainfont="Minion Pro" -V mainfontoptions="Numbers=OldStyle"


all: $(html) $(pdf)

%.tex: %.md $(context_style)
	pandoc --standalone --template $(context_style) \
	--from markdown --to context \
	$(pandoc_opts) \
	-o $@ $<

%.pdf: %.tex
	context --nonstopmode $<

%-pandoc.pdf: %.md
	pandoc --from=markdown --to=latex --output=$@ --smart --latex-engine=xelatex \
 		   --template=templates/latex-template.tex \
 		   --number-sections \
 		   $(pandoc_opts) \
 		   $<

%.html: %.md $(css)
	pandoc --standalone --self-contained --smart --css=$(css) \
        --from markdown --to html \
        -o $@ $<

clean:
	rm -f $(pdf) $(html)
	rm -f $(patsubst %.pdf, %.log, $(pdf))
	rm -f $(patsubst %.pdf, %.tuc, $(pdf))
