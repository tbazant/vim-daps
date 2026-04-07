" Vim syntax file
" Language: DocBook

if !exists("b:current_syntax") || b:current_syntax != "docbk"
  finish
endif

syntax spell toplevel

for tag in ['command', 'filename', 'option', 'literal', 'replaceable', 'screen', 'systemitem']
  execute 'syntax region docbkNoSpell_' . tag .
        \ ' matchgroup=xmlTag start=+<' . tag . '>+ end=+</' . tag . '>+' .
        \ ' contains=@NoSpell,@Spell,xmlAttrib,xmlEntity,xmlString,xmlComment,xmlCdata keepend'
endfor

" Define xmlString region again but without spellchecking
syntax region xmlString matchgroup=xmlString start=/"/ skip=/\\"/ end=/"/ contains=xmlEntity,@NoSpell keepend

" Disable spellchecking also for attribute names (xmlAttrib)
syntax match xmlAttribNoSpell /\w\+==/ contains=@NoSpell

" XML comments <!-- ... -->
syntax region xmlNoSpellComment start=/<!--/ end=/-->/ contains=@NoSpell keepend
