" + + + C O M M A N D S + + + "
" daps validate DC-file
command -complete=custom,ListDCfiles -nargs=1 DapsValidate :call DapsValidate(<f-args>)
command -complete=custom,ListDCfiles -nargs=1 DapsHtml :call DapsHtml(<f-args>)
command DapsTest :call DapsTest(<f-args>)

" testing dude's function :-)
function DapsTest()
  let l:test = join(getline(1,'$'))
  let l:toplevel_xml_id = matchstr(test, '\c xml:id=\([''"]\)\zs.\{-}\ze\1')
  echo l:toplevel_xml_id
endfunction


" lists all DC files in the current directory
function ListDCfiles(A,L,P)
  return system("ls -1 DC-*")
endfunction

" validates the document based on the DC file with tab completion
function DapsValidate(dc_file)
  let l:cmd = 'daps -d ' . a:dc_file . ' validate'
  execute '!' . l:cmd
endfunction

" builds HTML version of the current chapter
function DapsHtml(dc_file)
  "let l:rootidcmd = "xmlstarlet sel -T -N db='http://docbook.org/ns/docbook' -t -v '//db:chapter/@xml:id' " . expand('%')
  "let l:rootid = system(l:rootidcmd)
  let l:cbuffer = join(getline(1,'$'))
  let l:rootid = matchstr(l:cbuffer, '\c xml:id=\([''"]\)\zs.\{-}\ze\1')
  "echo l:rootid
  let l:dapscmd = 'daps -d ' . a:dc_file . ' html --rootid=' . l:rootid
  "echo l:dapscmd
  let l:target_dir = systemlist('daps -d ' . a:dc_file . ' html --rootid=' . l:rootid)[0]
  "echo l:target_dir
  let l:target_file = join([l:target_dir, 'index.html'], '')
  execute '!xdg-open ' . l:target_file
endfunction
