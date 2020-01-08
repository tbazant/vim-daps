" Vim plugin that implements some features of daps (https://opensuse.github.io/daps)
" Maintainer:   Tomáš Bažant <tomas.bazant@yahoo.com>
" License:      This file is placed in the public domain.


" - - - - - - - - - - - - - - i n i t i a l   s e t u p - - - - - - - - - - "
" save the value of cpoptions
let s:save_cpo = &cpo
set cpo&vim

" do not load the plugin if it's already loaded
if exists("g:loaded_daps")
  finish
endif
let g:loaded_daps = 1

" remember the script's directory
let s:plugindir = resolve(expand('<sfile>:p:h:h'))

" fill the  DB schema resolving hash
let g:daps_db_schema = {
      \'https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rng': 'geekodoc5',
      \'https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc': 'geekodoc5',
      \'http://www.oasis-open.org/docbook/xml/5.0/rng/docbook.rng': 'docbook50',
      \'http://www.oasis-open.org/docbook/xml/5.0/rng/docbook.rnc': 'docbook50',
      \}

" - - - - - - - - - - - - - - c o m m o n   f u n c t i o n s - - - - - - - - - - "
function s:dbg(msg)
  if g:daps_debug == 1
    echo "\nDEBUG: " . a:msg
  endif
endfunction
" - - - - - - - - - - - - -  c o m m a n d   d e f i n i t i o n s   - - - - - - - - - - - - "
" dummy command and function for testing purposes
if !exists(":DapsDummy")
  command -nargs=* DapsDummy :call s:DapsDummy(<f-args>)
endif

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

" daps list-file
if !exists(":DapsOpenTarget")
  command -nargs=? -complete=custom,s:ListXrefTargets DapsOpenTarget :call s:DapsOpenTarget(<f-args>)
endif

" --builddir
if !exists(":DapsSetBuilddir")
  command -nargs=1 -complete=file DapsSetBuilddir :call s:DapsSetBuilddir(<f-args>)
endif

" import all XML IDs given a DC-file
if !exists(":DapsImportXmlIds")
  command -nargs=0 DapsImportXmlIds :call s:DapsImportXmlIds()
endif

" shift DocBook sections' level up/down the tree
if !exists(":DapsShiftSectUp")
  command -nargs=0 -range DapsShiftSectUp <line1>,<line2>s/sect\(\d\)\(.*\)>/\="sect" . (submatch(1) - 1) . submatch(2) . ">"/g
endif
if !exists(":DapsShiftSectDown")
  command -nargs=0 -range DapsShiftSectDown <line1>,<line2>s/sect\(\d\)\(.*\)>/\="sect" . (submatch(1) + 1) . submatch(2) . ">"/g
endif

" - - - - - - - - - - - -  e n d   c o m m a n d   d e f i n i t i o n s   - - - - - - - - - - - "
" - - - - - - - - - - - - -   f u n c t i o n s   - - - - - - - - - - - - "

" lists all DC files in the current directory
function s:ListDCfiles(A,L,P)
  return system("ls -1 " . g:dcfile_glob_pattern . "*")
endfunction

" lists XML dictionaries from vim-daps plugin
function s:ListXMLdictionaries(A,L,P)
  " make sure the dict list is unique
  let dict_list = filter(values(g:daps_db_schema),'index(values(g:daps_db_schema), v:val, v:key+1)==-1')
  let result = map(copy(dict_list), 'fnamemodify(v:val, ":t:r")')
  return join(result, "\n")
endfunction

" list all <xref>s' IDs from the current buffer
function s:ListXrefTargets(A,L,P)
  "let cmd = 'xsltproc --xinclude ' . g:daps_dapsroot . '/daps-xslt/common/get-all-xmlids.xsl xml/admin_gui_oa.xml | sort -u'
  let cmd = 'xsltproc ' . s:plugindir . '/tools/get-all-xrefsids.xsl ' . expand('%') . ' | sort -u'
  return system(cmd)
endfunction

" import all XML IDs given a DC-file
function s:DapsImportXmlIds()
  if !empty(s:IsDCfileSet())
    " grep MAIN file out of the DC-file
    let main_file = matchstr(system('grep "^\s*MAIN=" ' . b:dc_file), '"\zs[^"]\+\ze"')
    let xsltproc_cmd = 'xsltproc --xinclude ' . g:daps_dapsroot . '/daps-xslt/common/get-all-xmlids.xsl xml/' . main_file
    let g:xmldata_geekodoc5.xref[1].linkend = sort(systemlist(xsltproc_cmd))
  endif
endfunction

" ask for DC file
function s:AskForDCFile()
  call inputsave()
  let dc_file = input("Enter DC file: ", g:dcfile_glob_pattern, "file")
  call inputrestore()
  redrawstatus
  return s:DapsSetDCfile(dc_file)
endfunction

" set current buffer's DC-* file
function s:DapsSetDCfile(dc_file)
  if filereadable(a:dc_file)
    "set dc_file for current buffer
    let b:dc_file = a:dc_file
    "set dc_file globally so that new buffers get it from the previous ones
    let g:daps_dc_file = b:dc_file
    if g:daps_auto_import_xmlids == 1
      call s:DapsImportXmlIds()
    endif
    return b:dc_file
  else
    echoerr "The specified DC file is not readable."
  endif
endfunction

" implement `daps list-file`
function s:DapsOpenTarget(...)
  if a:0 > 0
    " ID was supplied :-)
    let rootid = a:1
  else
    " check if cursor is on '<xref linkend=""' line and use as a --rootid
    let rootid = matchstr(getline("."), '\c linkend=\([''"]\)\zs.\{-}\ze\1')
    " check if cursor is on '<link xlink:href=""' line
    let href = matchstr(getline("."), '\c xlink:href=\([''"]\)\zs.\{-}\ze\1')
    if empty(rootid)
    endif
    if !empty(href)
      if exists("g:daps_html_viewer")
        silent execute '!' . g:daps_html_viewer . ' ' . href . ' > /dev/null 2>&1'
      else
        silent execute '!xdg-open ' . href . ' > /dev/null 2>&1'
      endif
      execute 'redraw!'
    endif
  endif
  if !empty(rootid)
    if !empty(s:IsDCfileSet())
      let file_cmd = g:daps_dapscmd . ' -d ' . b:dc_file . ' list-file --rootid=' . rootid . ' 2> /dev/null'
      let file = systemlist(file_cmd)[0]
      if filereadable(file)
        " open the file in a new tab and point cursor on the correct line
        execute 'tabnew ' .file
        call search('id=[''"]' . rootid . '[''"]','w')
      else
        echoerr rootid . ' not found in any file.'
      endif
    endif
  endif
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
  call xmlcomplete#CreateConnection(b:doctype)
  call s:DapsImportEntites()
endfunction

" check if DC file was previously set via DapsSetDCfile()
function s:IsDCfileSet()
  if exists("b:dc_file")
    return b:dc_file
  elseif exists("g:daps_dc_file")
    let b:dc_file = g:daps_dc_file
    return b:dc_file
  else
    return s:AskForDCFile()
  endif
endfunction

" validates the document based on the DC file with tab completion
function s:DapsValidate()
  if !empty(s:IsDCfileSet())
    " check whether to run DaspValidateFile first
    if g:daps_auto_validate_file == 1 && s:DapsValidateFile() == 1
      return 1
    endif
    let result = system(g:daps_dapscmd . ' -d ' . b:dc_file . ' validate' . ' 2> /dev/null')
    if v:shell_error == 0
      echom 'All files are valid.'
      return 0
    else
      echoe "Validation failed.\n" . result
    endif
  endif
endfunction

" daps style check
function s:DapsStylecheck()
  if !empty(s:IsDCfileSet())
    " find out the location of the style result XML file
    let style_xml = system(g:daps_dapscmd . ' -d ' . b:dc_file . ' stylecheck --file ' . expand('%') . ' 2> /dev/null')
    let style_result = systemlist('xsltproc ' . s:plugindir . '/tools/vim_stylecheck.xsl ' . style_xml)
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
          let lnum = sl[1] + 6
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
  " get the schema URI
  for [key, value] in items(g:daps_db_schema)
    if value == b:doctype
      let l:schema_uri = key
      break
    endif
  endfor
  call s:dbg('l:schema_uri -> ' . l:schema_uri)
  if exists('l:schema_uri')
    " get the schema file
    let l:schema_file = systemlist('xmlcatalog /etc/xml/catalog ' . l:schema_uri)[0]
    " if the result starts with 'No entry', then schema is missing in catalogue
    if strpart(l:schema_file, 0, 8) == 'No entry'
      echoe 'Schema uri ' . l:schema_uri . ' is missing in XML catalog'
      return 1
    endif
    call s:dbg('l:schema_file -> ' . l:schema_file)
    " run jing to check the current file's structure
    let l:jing_cmd = 'jing -i ' . l:schema_file . ' ' . expand('%')
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
      return 1
    else
      execute 'cclose'
      execute 'sign unplace *'
      echom 'The current buffer is valid.'
      return 0
    endif
  else
    echoe 'Cannot extract schema URI for ' . b:doctype
    return 1
  endif
endfunction

" builds the current chapter or --rootid
function s:DapsBuild(target)
  if !empty(s:IsDCfileSet())
    if s:DapsValidate() == 0
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
      let l:dapscmd = g:daps_dapscmd . ' -d ' . b:dc_file . ' --builddir=' . b:builddir . ' ' . a:target . ' --rootid=' . l:rootid . ' 2> /dev/null'
      let l:target_dir = systemlist(l:dapscmd)[0]
      if a:target == 'html'
        let l:target_file = join([l:target_dir, 'index.html'], '')
      else
        let l:target_file = l:target_dir
      endif
      if exists("g:daps_" . a:target . "_viewer")
        let l:doc_viewer = g:daps_{a:target}_viewer
        silent execute '!' . l:doc_viewer . ' ' . l:target_file . ' > /dev/null 2>&1'
      else
        silent execute '!xdg-open ' . l:target_file . ' > /dev/null 2>&1'
      endif
      execute 'redraw!'
    endif
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
    let getentityname = g:daps_dapsroot . '/libexec/getentityname.py'
    let ent_str = substitute(system(getentityname . ' ' . expand('%:p')), '\n\+$', '', '')
    let ent_files = split(ent_str, ' ')
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
    " assing docbk_entity vriable with new content
    let g:xmldata_{b:doctype}['vimxmlentities'] += list
  endfor
  let sorted = sort(copy(g:xmldata_{b:doctype}['vimxmlentities']))
  let g:xmldata_{b:doctype}['vimxmlentities'] = copy(sorted)
  unlet sorted
  unlet line
endfunction

" lookup doctyp info from xml/schemas.xml file
function s:DapsLookupSchemasXML()
  " test for the xml/schemas.xml file
  if filereadable('xml/schemas.xml')
    let l:x_query = '/t:locatingRules/t:uri/@uri'
    let l:x_cmd = "xmlstarlet sel -T -N t='http://thaiopensource.com/ns/locating-rules/1.0' -t -v '" . l:x_query . "' xml/schemas.xml"
    let l:x_result = systemlist(l:x_cmd)[0]
    if filereadable(l:x_result)
      return l:x_result
    endif
  endif
endfunction

" set --buildroot for the current buffer
function s:DapsSetBuilddir(builddir)
  " check if builddir exists and if it is a writable directory
  if filewritable(a:builddir) == 2
    let b:builddir = a:builddir
  elseif mkdir(a:builddir, "p")
    let b:builddir = a:builddir
  else
    echoerr a:builddir . ' is not a writable directory'
  endif
endfunction


" - - - - - - - - - - - - -  e n d  f u n c t i o n s   - - - - - - - - - - - - "


" - - - - - - - - - - - - - o p t i o n s   f o r   ~/.vimrc - - - - - - - - - - - - "


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

" decide whether run :DapsValidateFile before :DapsValidate
if exists("g:daps_auto_validate_file")
  let b:daps_auto_validate_file = g:daps_auto_validate_file
else
  let b:daps_auto_validate_file = 0
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

" decide whether to read the xml/schemas.xml file for DocType
if exists("g:daps_xmlschemas_autostart")
  if g:daps_xmlschemas_autostart == 1
    let x_schema = s:DapsLookupSchemasXML()
    if !empty(x_schema)
      " find the right doctype accross URI
      for [key, value] in items(g:daps_db_schema)
        let schema_file = systemlist('xmlcatalog /etc/xml/catalog ' . key)[0]
        if schema_file == x_schema
          call s:DapsSetDoctype(value)
          break
        endif
      endfor
    endif
  endif
endif

" check if 'g:daps_builddir' exists and trigger setting it in current buffer
if !exists("g:daps_builddir")
  let g:daps_builddir = getcwd() . '/build/'
endif
call s:DapsSetBuilddir(g:daps_builddir)

" check if 'g:daps_auto_import_xmlids' exists and set default value
if !exists("g:daps_auto_import_xmlids")
  let g:daps_auto_import_xmlids = 1
endif

" remember daps installation base dir
let s:dapsdir = system('which daps')[:-11]
" check if 'g:daps_dapsroot' is set and guess if not
if !exists("g:daps_dapsroot")
  let g:daps_dapsroot = '/usr/share/daps'
  let g:daps_dapscmd = '/usr/bin/daps'
else
  let g:daps_dapscmd = g:daps_dapsroot . '/bin/daps --dapsroot=' . g:daps_dapsroot
endif

" - - - - - - - - - - - - - e n d   o p t i o n s   f o r   ~/.vimrc - - - - - - - - - - - - "

" restore the value of cpoptions
let &cpo = s:save_cpo
