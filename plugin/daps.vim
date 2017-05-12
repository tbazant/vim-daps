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
" set aspell language
if !exists(":DapsSetSpellLang")
  command -nargs=1 DapsSetSpellLang :call s:DapsSetSpellLang(<f-args>)
endif
" daps validate
if !exists(":DapsValidate")
  command -nargs=0 DapsValidate :call s:DapsValidate(<f-args>)
endif
" daps xmlformat
if !exists(":DapsXmlFormat")
  command -nargs=0 DapsXmlFormat :call s:DapsXmlFormat(<f-args>)
endif
" daps html
if !exists(":DapsHtml")
  command -nargs=0 DapsHtml :call s:DapsBuild('html')
endif
" daps pdf
if !exists(":DapsPdf")
  command -nargs=0 DapsPdf :call s:DapsBuild('pdf')
endif
" import daps-aspell into vim spell checker
if !exists(":DapsImportSpellDict")
  command -nargs=0 DapsImportSpellDict :call s:DapsImportSpellDict()
endif
" ------------- command definitions end ------------ "
"
" ------------- options for ~/.vimrc ------------ "
" set the default language for the aspell dictionary
if exists("g:daps_spell_dict_lang")
  let b:spell_dict_lang = g:daps_spell_dict_lang
else
  let b:spell_dict_lang = "en_US"
endif
" decide whether ask for DC file on startup and do so if yes
if exists("g:daps_dcfile_autostart")
  let b:dcfile_autostart = g:daps_dcfile_autostart
else
  let b:dcfile_autostart = 0
endif
if b:dcfile_autostart == 1
  autocmd BufReadPost,FileType docbk call s:AskForDCFile()
endif
" set default patter for DC file completion
if exists("g:daps_dcfile_glob_pattern")
  let g:dcfile_glob_pattern = g:daps_dcfile_glob_pattern
else
  let g:dcfile_glob_pattern = ""
endif
" ------------- functions ------------ "

" lists all DC files in the current directory
function s:ListDCfiles(A,L,P)
  return system("ls -1 " . g:dcfile_glob_pattern . "*")
endfunction

" autoask for DC file
function s:AskForDCFile()
  call inputsave()
  let b:dc_file = input("Enter DC file: ", g:dcfile_glob_pattern, "file")
  call s:DapsSetDCfile(b:dc_file)
  call inputrestore()
endfunction

" set current buffer's DC-* file
function s:DapsSetDCfile(dc_file)
  let b:dc_file = a:dc_file
endfunction

" set aspell dict for import
function s:DapsSetSpellLang(lang)
  let b:spell_dict_lang = a:lang
  let b:spell_dict = b:spell_dict_lang . "-suse-addendum.rws"
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
  if !empty(s:IsDCfileSet())
    let l:cmd = 'daps -d ' . b:dc_file . ' validate'
    execute '!' . l:cmd
  endif
endfunction

" builds the current chapter or --rootid
function s:DapsBuild(target)
  if !empty(s:IsDCfileSet())
    " check if cursor is on 'id=""' line and use a --rootid
    let l:rootid = matchstr(getline("."), '\c xml:id=\([''"]\)\zs.\{-}\ze\1')
    if !empty(l:rootid)
      " --rootid is limited to the following elements
      let l:rootids = ['appendix', 'article', 'bibliography', 'book', 'chapter', 'glossary',
            \ 'index', 'part', 'preface', 'sect1', 'section']
      let l:element = matchstr(getline("."), '<\w\+')
      if match(l:rootids, l:element[1:]) == -1
        let l:rootid = ''
      endif
    endif
    if empty(l:rootid)
      let l:rootid = matchstr(join(getline(1,'$')), '\c xml:id=\([''"]\)\zs.\{-}\ze\1')
    endif
    " assemble daps cmdline
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

" formats the XML source
function s:DapsXmlFormat()
  " check if xmlformat script is installed
  if executable('xmlformat')
    let l:xmlformat = 'xmlformat'
  elseif executable('xmlformat.pl')
    let l:xmlformat = 'xmlformat.pl'
  else
    echoerr("'xmlformat' not found in your path")
    return
  endif
  " save the current cursor position
  let l:clin = line(".")
  let l:ccol = col(".")
  execute('%!' . l:xmlformat . ' -f /etc/daps/docbook-xmlformat.conf')
  " go back to the saved cursor position
  call cursor(l:clin, l:ccol)
endfunction

"imports daps aspell into vim's spellchecker
function s:DapsImportSpellDict()
  execute '!aspell dump master -l ' . b:spell_dict . ' --dict-dir=/usr/share/suse-xsl-stylesheets/aspell > ~/.vim/spell/suse.utf-8.add'
endfunction

" restore the value of cpoptions
let &cpo = s:save_cpo

" O L D   S T U F F
" find toplevel chapter ID:
"let l:rootidcmd = "xmlstarlet sel -T -N db='http://docbook.org/ns/docbook' -t -v '//db:chapter/@xml:id' " . expand('%')
