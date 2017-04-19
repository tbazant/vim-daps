" daps validate DC-file
command -complete=custom,ListDCfiles -nargs=1 DapsValidate :call DapsValidate(<f-args>)
command -complete=custom,ListDCfiles -nargs=1 DapsHtml :call DapsHtml(<f-args>)




" lists all DC files in the current directory 
function ListDCfiles(A,L,P)
  return system("ls -1 DC-*")
endfunction

" validates the dicument based on the DC file with tab completion
function DapsValidate(dc_file)
  let l:cmd = 'daps -d ' . a:dc_file . ' validate'
  execute '!' . l:cmd
endfunction

" builds HTML version of the current chapter
function DapsHtml(dc_file)
  "let l:chapter_id = matchstr(test, '\ca <chapter.*xml:id=\([''"]\)\zs.\{-}\ze\1')
  let l:rootidcmd = "xmlstarlet sel -T -N db='http://docbook.org/ns/docbook' -t -v '//db:chapter/@xml:id' " . expand('%')
  let l:rootid = system(l:rootidcmd)
  let l:target_dir = systemlist('daps -d ' . a:dc_file . ' html --rootid=' . l:rootid)[0]
  let l:target_file = join([l:target_dir, 'index.html'], '') 
  execute '!xdg-open ' . l:target_file
endfunction
