" Vim filetype plugin that implements some features of daps (https://opensuse.github.io/daps)
" Last Change:  2017 Apr 21
" Maintainer:   Tomáš Bažant <tomas.bazant@yahoo.com>
" License:      This file is placed in the public domain.

" save the value of cpoptions
let s:save_cpo = &cpo
set cpo&vim

" do not load the plugin if it's already loaded
if exists("g:loaded_daps")
  finish
endif
let g:loaded_daps = 1

" ------------- command definitions ------------ "
" daps validate
if !exists(":DapsValidate")
  command -complete=custom,s:ListDCfiles -nargs=1 DapsValidate :call s:DapsValidate(<f-args>)
endif
" daps html
if !exists(":DapsHtml")
  command -complete=custom,s:ListDCfiles -nargs=1 DapsHtml :call s:DapsBuild(<f-args>, 'html')
endif
" daps pdf
if !exists(":DapsPdf")
  command -complete=custom,s:ListDCfiles -nargs=1 DapsPdf :call s:DapsBuild(<f-args>, 'pdf')
endif
" command DapsTest :call DapsTest(<f-args>)
" ------------- command definitions end ------------ "

" testing dude's function :-)
function DapsTest()
  let l:test = join(getline(1,'$'))
  let l:toplevel_xml_id = matchstr(test, '\c xml:id=\([''"]\)\zs.\{-}\ze\1')
  echo l:toplevel_xml_id
endfunction

" lists all DC files in the current directory
function s:ListDCfiles(A,L,P)
  return system("ls -1 DC-*")
endfunction

" validates the document based on the DC file with tab completion
function s:DapsValidate(dc_file)
  let l:cmd = 'daps -d ' . a:dc_file . ' validate'
  execute '!' . l:cmd
endfunction

" builds the current chapter or --rootid
function s:DapsBuild(dc_file, target)
  "let l:rootidcmd = "xmlstarlet sel -T -N db='http://docbook.org/ns/docbook' -t -v '//db:chapter/@xml:id' " . expand('%')
  "let l:rootid = system(l:rootidcmd)
  let l:cbuffer = join(getline(1,'$'))
  let l:rootid = matchstr(l:cbuffer, '\c xml:id=\([''"]\)\zs.\{-}\ze\1')
  "echo l:rootid
  let l:dapscmd = 'daps -d ' . a:dc_file . ' ' . a:target . ' --rootid=' . l:rootid
  "echo l:dapscmd
  let l:target_dir = systemlist(l:dapscmd)[0]
  "echo l:target_dir
  if a:target == 'html'
    let l:target_file = join([l:target_dir, 'index.html'], '')
  else
    let l:target_file = l:target_dir
  endif
  execute '!xdg-open ' . l:target_file
endfunction

" restore the value of cpoptions
let &cpo = s:save_cpo
