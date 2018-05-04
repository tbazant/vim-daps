" Vim filetype plugin that implements some features of daps (https://opensuse.github.io/daps)
" Last Change:  2017 Nov 29
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
" dummy command and function for testing purposes
"if !exists(":DapsDummy")
"  command -nargs=* DapsDummy :call s:DapsDummy(<f-args>)
"endif
"function s:DapsDummy()
"  let dict_list = systemlist("ls -1 " . s:plugindir . "/autoload/xml/*.vim")
"  let result = map(copy(dict_list), 'fnamemodify(v:val, ":t:r")')
"  echo join(result, "\n")
"endfunction

" set default DC-* file for current buffer
if !exists(":DapsSetDCfile")
  command -complete=custom,s:ListDCfiles -nargs=1 DapsSetDCfile :call s:DapsSetDCfile(<f-args>)
endif
" set DocType (version) for DocBook (and derived) documents
if !exists(":DapsSetDoctype")
  command -complete=custom,s:ListXMLdictionaries -nargs=* DapsSetDoctype :call s:DapsSetDoctype(<f-args>)
endif
" import DB entities from external file
if !exists(":DapsImportEntites")
  command -complete=file -nargs=* DapsImportEntites :call s:DapsImportEntites(<f-args>)
endif
" daps validate
if !exists(":DapsValidate")
  command -nargs=0 DapsValidate :call s:DapsValidate(<f-args>)
endif
" daps validate file
if !exists(":DapsValidateFile")
  command -nargs=0 DapsValidateFile :call s:DapsValidateFile(<f-args>)
endif
" daps style check
if !exists(":DapsStylecheck")
  command -nargs=0 DapsStylecheck :call s:DapsStylecheck(<f-args>)
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
" ------------- command definitions end ------------ "
"
" ------------- functions ------------ "

" lists all DC files in the current directory
function s:ListDCfiles(A,L,P)
  return system("ls -1 " . g:dcfile_glob_pattern . "*")
endfunction

" lists XML dictionaries from vim-daps plugin
function s:ListXMLdictionaries(A,L,P)
  let dict_list = systemlist("ls -1 " . s:plugindir . "/autoload/xml/*.vim")
  let result = map(copy(dict_list), 'fnamemodify(v:val, ":t:r")')
  return join(result, "\n")
endfunction

" autoask for DC file
function s:AskForDCFile()
  call inputsave()
  if !exists("g:daps_dc_file")
    let g:daps_dc_file = input("Enter DC file: ", g:dcfile_glob_pattern, "file")
    call s:DapsSetDCfile(g:daps_dc_file)
    call inputrestore()
  else
    call s:DapsSetDCfile(g:daps_dc_file)
  endif
endfunction

" set current buffer's DC-* file
function s:DapsSetDCfile(dc_file)
  let b:dc_file = a:dc_file
endfunction

" set doctype for DB documents
function s:DapsSetDoctype(...)
  if a:0 == 0
    if exists("g:daps_doctype")
      let b:doctype = g:daps_doctype
    else
      let b:doctype = "docbook50"
    endif
  else
    let b:doctype = a:1
  endif
  execute 'XMLns ' . b:doctype
  call s:DapsImportEntites()
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
    let result = system('daps -d ' . b:dc_file . ' validate')
    echom result
  endif
endfunction

" daps style check
function s:DapsStylecheck()
  if !empty(s:IsDCfileSet())
    " find out the location of the style result XML file
    let style_xml = system('daps -d ' . b:dc_file . ' stylecheck --file ' . expand('%'))
    let style_result = systemlist('xsltproc ~/.vim/plugged/vim-daps/tools/vim_stylecheck.xsl ' . style_xml)
    if !empty(style_result)
      " define signs
      sign define error text=E
      sign define warning text=W
      sign define fatal text=F
      let l:qflist = []
      let id = 1
      for line in style_result
        let sl = split(line, '::')
        " remove this after Stefan removes the first useless line of output
        if len(sl) > 3
          " filter out unwanted message types
          if !empty(g:daps_stylecheck_show)
            if g:daps_stylecheck_show != sl[2]
              continue
            endif
          endif
          let filename = expand('xml/' . sl[0])
          " remove this once Stefan fixes the line numbering
          let lnum = sl[1] + 5
          call add(l:qflist, {
                \ 'filename': filename,
                \ 'lnum': lnum,
                \ 'type': sl[2],
                \ 'text': sl[4],
                \})
          execute 'sign place ' . id . ' line=' . lnum . ' name=' . sl[2] . ' file=' . filename
          let id += 1
        endif
      endfor
      call setqflist(l:qflist)
      execute 'copen'
    else
      execute 'cclose'
      execute 'sign unplace *'
    endif
  endif
endfunction

" validates the current file only
function s:DapsValidateFile()
  let l:jing_cmd = 'jing -i /usr/share/xml/docbook/schema/rng/5.1/docbookxi.rng ' . expand('%')
  let l:jing_result = systemlist(l:jing_cmd)
  if !empty(l:jing_result)
    " define signs
    sign define error text=E
    sign define warning text=W
    sign define fatal text=F
    let l:qflist = []
    let id = 1
    for line in l:jing_result
      let sl = split(line, ':')
      call add(l:qflist, {
            \ 'filename': sl[0],
            \ 'lnum': sl[1],
            \ 'col': sl[2],
            \ 'type': substitute(sl[3], ' ', '', ''),
            \ 'text': strpart(sl[4], 0, 70) . '...',
            \})
      execute 'sign place ' . id . ' line=' . sl[1] . ' name=' . substitute(sl[3], ' ', '', '') . ' file=' . sl[0]
      let id += 1
    endfor
    call setqflist(l:qflist)
    execute 'copen' len(l:qflist) + 4
  else
    execute 'cclose'
    execute 'sign unplace *'
    call s:DapsValidate()
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
    let l:target_dir = systemlist(l:dapscmd)[0]
    if a:target == 'html'
      let l:target_file = join([l:target_dir, 'index.html'], '')
    else
      let l:target_file = l:target_dir
    endif
    if exists("g:daps_" . a:target . "_viewer")
      let l:doc_viewer = g:daps_{a:target}_viewer
      silent execute '!' . l:doc_viewer . ' ' . l:target_file
    else
      silent execute '!xdg-open ' . l:target_file
    endif
    "execute 'redraw!'
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

" imports entites from a file to a DTD file
" 1) look if arguments are a list of entity files and try to extract entites;
" 2) if no argument is given, run getentityname.py to get the list of files
function s:DapsImportEntites(...)
  if a:0 == 0
    " return for fugitive:// paths
    if expand('%:p') =~ '^fugitive'
      return
    endif
    " no arg given, try getentityname.py
    let ent_files = split(system('/usr/share/daps/libexec/getentityname.py ' . expand('%:p'), ' '))
    if len(ent_files) == 0
      " no ent files provided or found
      echoerr "No entity file(s) could be extracted, specify them on the command line"
      return
    else
      " add 'xml/' before each ent filename
      call map(ent_files, '"xml/" . v:val')
    endif
  else
    let ent_files = a:000
  endif

  "let g:xmldata_{b:doctype}['vimxmlentities'] = []

  for ent_file in ent_files
    " check if file exists
    let ent_file = expand(ent_file)
    if !filereadable(ent_file)
      echoerr 'File ' . ent_file . ' is not readable'
      continue
    endif
    "extract entities into @list
    let list = []
    for line in readfile(ent_file)
      let split = split(line, ' ')
      if !empty(split) && split[0] == '<!ENTITY' && split[1] != '%'
        call add(list, split[1])
      endif
    endfor
    " assig docbk_entity vriable with new content
    let g:xmldata_{b:doctype}['vimxmlentities'] += list
  endfor
  let sorted = sort(copy(g:xmldata_{b:doctype}['vimxmlentities']))
  let g:xmldata_{b:doctype}['vimxmlentities'] = copy(sorted)
  unlet sorted
  unlet line
endfunction

"remember the script's directory
let s:plugindir = expand('<sfile>:p:h:h')

" ------------- options for ~/.vimrc ------------ "
" decide whether ask for DC file on startup and do so if yes
if exists("g:daps_dcfile_autostart")
  let b:dcfile_autostart = g:daps_dcfile_autostart
else
  let b:dcfile_autostart = 0
endif
if b:dcfile_autostart == 1
  autocmd BufReadPost,FileType docbk call s:AskForDCFile()
endif
" set default pattern for DC file completion
if exists("g:daps_dcfile_glob_pattern")
  let g:dcfile_glob_pattern = g:daps_dcfile_glob_pattern
else
  let g:dcfile_glob_pattern = ""
endif
" set default pattern for entity file completion
if exists("g:daps_entfile_glob_pattern")
  let g:entfile_glob_pattern = g:daps_entfile_glob_pattern
else
  let g:entfile_glob_pattern = "*"
endif
" decide whether run entity, set doctype, and import on new file open
if exists("g:daps_entity_import_autostart")
  let b:entity_import_autostart = g:daps_entity_import_autostart
else
  let b:entity_import_autostart = 0
endif
if b:entity_import_autostart == 1
  autocmd BufReadPost,FileType docbk call s:DapsSetDoctype()
endif

" restore the value of cpoptions
let &cpo = s:save_cpo

" O L D   S T U F F
" find toplevel chapter ID:
"let l:rootidcmd = "xmlstarlet sel -T -N db='http://docbook.org/ns/docbook' -t -v '//db:chapter/@xml:id' " . expand('%')
