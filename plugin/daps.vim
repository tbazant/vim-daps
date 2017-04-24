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
" set default DC-* file for current buffer
if !exists(":DapsSetDCfile")
  command -complete=custom,s:ListDCfiles -nargs=1 DapsSetDCfile :call s:DapsSetDCfile(<f-args>)
endif
" daps validate
if !exists(":DapsValidate")
  command -complete=custom,s:ListDCfiles -nargs=0 DapsValidate :call s:DapsValidate(<f-args>)
endif
" daps xmlformat
if !exists(":DapsXmlFormat")
  command -complete=custom,s:ListDCfiles -nargs=0 DapsXmlFormat :call s:DapsXmlFormat(<f-args>)
endif
" daps html
if !exists(":DapsHtml")
  command -complete=custom,s:ListDCfiles -nargs=0 DapsHtml :call s:DapsBuild('html')
endif
" daps pdf
if !exists(":DapsPdf")
  command -complete=custom,s:ListDCfiles -nargs=0 DapsPdf :call s:DapsBuild('pdf')
endif

" ------------- command definitions end ------------ "

" lists all DC files in the current directory
function s:ListDCfiles(A,L,P)
  return system("ls -1 DC-*")
endfunction

" set current buffer's DC-* file
function s:DapsSetDCfile(dc_file)
  let b:dc_file = a:dc_file
  echom 'DC file set to ' . b:dc_file
endfunction

" check if DC file was previously set via DapsSetDCfile()
function s:IsDCfileSet() abort
  if exists("b:dc_file")
    return b:dc_file
  else
    echoerr "No DC file specified, use :DapsSetDCfile to specify it!"
  endif
endfunction

" validates the document based on the DC file with tab completion
function s:DapsValidate()
  if s:IsDCfileSet() != ''
    let l:cmd = 'daps -d ' . b:dc_file . ' validate'
    execute '!' . l:cmd
  endif
endfunction

" builds the current chapter or --rootid
function s:DapsBuild(target)
  if s:IsDCfileSet() != ''
    "let l:rootidcmd = "xmlstarlet sel -T -N db='http://docbook.org/ns/docbook' -t -v '//db:chapter/@xml:id' " . expand('%')
    "let l:rootid = system(l:rootidcmd)
    let l:cbuffer = join(getline(1,'$'))
    let l:rootid = matchstr(l:cbuffer, '\c xml:id=\([''"]\)\zs.\{-}\ze\1')
    "echo l:rootid
    let l:dapscmd = 'daps -d ' . b:dc_file . ' ' . a:target . ' --rootid=' . l:rootid
    "echo l:dapscmd
    let l:target_dir = systemlist(l:dapscmd)[0]
    "echo l:target_dir
    if a:target == 'html'
      let l:target_file = join([l:target_dir, 'index.html'], '')
    else
      let l:target_file = l:target_dir
    endif
    execute '!xdg-open ' . l:target_file
  endif
endfunction

" restore the value of cpoptions
let &cpo = s:save_cpo
