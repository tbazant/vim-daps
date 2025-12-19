syntax spell toplevel
" Disable spellchecking in selected DocBook tags
" but keep syntax highlighting from the base docbk syntax

for tag in ['command', 'filename', 'option', 'literal', 'replaceable', 'screen', 'systemitem']
  execute 'syntax region docbkNoSpell_' . tag .
        \ ' matchgroup=xmlTag start=+<' . tag . '>+ end=+</' . tag . '>+' .
        \ ' contains=@NoSpell,@Spell,xmlAttrib,xmlEntity,xmlString,xmlComment,xmlCdata keepend'
endfor
" ------------------------------------------------------------------
" Disable spellchecking inside XML attribute values
" (e.g. xml:id="something", href="https://...")
" ------------------------------------------------------------------

" Define xmlString region again but without spellchecking
syntax region xmlString matchgroup=xmlString start=/"/ skip=/\\"/ end=/"/ contains=xmlEntity,@NoSpell keepend

" Disable spellchecking also for attribute names (xmlAttrib)
syntax match xmlAttribNoSpell /\w\+==/ contains=@NoSpell

" XML comments <!-- ... -->
syntax region xmlNoSpellComment start=/<!--/ end=/-->/ contains=@NoSpell keepend
