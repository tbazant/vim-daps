" Vim syntax file
" Language: AsciiDoc

if !exists("b:current_syntax") || b:current_syntax != "asciidoc"
  finish
endif

" --- Attributes: always no-spell, including inside headings ---
syntax match asciidocAttribute /\v\{[^}]+\}/ contains=@NoSpell containedin=ALL
highlight link asciidocAttribute PreProc

" --- Do not spell check inside link:path[] and xref:path[] ---
syntax region asciidocLinkTarget matchgroup=asciidocLink start=/\v<(link|xref):/ end=/\[/me=s-1,he=s-1 contains=@NoSpell oneline

" --- Do not spell check inside include::path[] ---
syntax region asciidocIncludeTarget matchgroup=asciidocInclude start=/\v<include::/ end=/\[/me=s-1,he=s-1 contains=@NoSpell oneline

" --- Attribute values (e.g. :foo: bar) ---
syntax region asciidocAttributeValue start=/^:\k\+:/ end=/$/ contains=@NoSpell oneline

" --- Section IDs ---
syntax region asciidocSectionIdDouble matchgroup=asciidocSectionId start=/\[\[/ end=/\]\]/ contains=@NoSpell oneline
syntax region asciidocSectionIdSingle matchgroup=asciidocSectionId start=/\[#/ end=/\]/ contains=@NoSpell oneline

" --- Processing instructions ---
syntax region asciidocProcessingInstruction start=/^\v(ifdef|ifndef|ifeval|endif)::/ end=/$/ contains=@NoSpell oneline

" --- Ensure inline cluster includes our elements ---
syntax cluster asciidocInline add=asciidocAttribute,asciidocLinkTarget,asciidocSectionIdDouble,asciidocSectionIdSingle

" --- Code blocks with attributes ([...]) ---
syntax region asciidocCodeBlock start=/^----$/ end=/^----$/ contains=@NoSpell