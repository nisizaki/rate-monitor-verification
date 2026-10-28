# Document build

`model.md` is the editable source, `references.bib` is its bibliography,
and `research-note.md` is a readable version with citations expanded. Pandoc
generates `main.tex` with citations and the reference list already expanded.
The PDF uses LuaLaTeX and LuaTeX-ja.

```sh
pandoc model.md --standalone --citeproc --bibliography=references.bib -V documentclass=ltjsarticle -V geometry:margin=25mm -o main.tex
pandoc model.md --citeproc --bibliography=references.bib -t gfm -o research-note.md
latexmk -lualatex -interaction=nonstopmode -halt-on-error main.tex
```

The Codex built-in compiler uses XeTeX and does not support this LuaLaTeX
document; the WSL LuaLaTeX build was used to generate `main.pdf`.
