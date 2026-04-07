" Vim syntax file
" Language: AsciiDoc
" Maintainer: Gemini Code Assist
" Description: Add nospell regions for AsciiDoc to avoid spell checking in links, code, and attributes.

if !exists("b:current_syntax") || b:current_syntax != "asciidoc"
  finish
endif

" Do not spell check inside link:path[] and xref:path[]
syntax region asciidocLinkTarget matchgroup=asciidocLink start=/\v<(link|xref):/ end=/\[/me=s-1,he=s-1 contains=@NoSpell oneline

" Do not spell check attribute references like {attribute}
syntax match asciidocAttributeReference /\v\{[a-zA-Z0-9_-]+\}/ contains=@NoSpell

" Do not spell check attribute values for attribute entries
syntax region asciidocAttributeValue start=/^:\k\+:/ end=/$/ contains=@NoSpell oneline

" Do not spell check inside [[section_id]]
syntax region asciidocSectionIdDouble matchgroup=asciidocSectionId start=/\[\[/ end=/\]\]/ contains=@NoSpell oneline

" Do not spell check inside [#section_id]
syntax region asciidocSectionIdSingle matchgroup=asciidocSectionId start=/\[#/ end=/\]/ contains=@NoSpell oneline

" Do not spell check processing instructions like ifdef:: and endif::
syntax region asciidocProcessingInstruction start=/^\v(ifdef|ifndef|ifeval|endif)::/ end=/$/ contains=@NoSpell oneline