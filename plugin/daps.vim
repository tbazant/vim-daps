" Vim plugin that implements some features of daps (https://opensuse.github.io/daps)
" Maintainer:   Tomáš Bažant <tomik.bazik@seznam.cz>
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

" read g:daps_* variables from .vimrc and set defaults
autocmd FileType docbk :call s:Init()

" define actions triggered by events
augroup vim_daps
  " clear exisitng autocommands in the group
  autocmd!
  " run style check on each saving the buffer
  autocmd BufWritePost *.xml call s:DapsStylecheck()
augroup END

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
if !exists(":DapsImportEntities")
  command -complete=file -nargs=* DapsImportEntities :call s:DapsImportEntities(<f-args>)
endif

" daps validate
if !exists(":DapsValidate")
  command -nargs=0 DapsValidate :call s:DapsValidate(<f-args>)
endif

" daps validate file
if !exists(":DapsValidateFile")
  command -nargs=0 DapsValidateFile :call s:DapsValidateFile(<f-args>)
endif

" daps stylecheck
if !exists(":DapsStylecheck")
  command -nargs=0 DapsStylecheck :call s:DapsStylecheck(<f-args>)
endif

" daps xmlformat
if !exists(":DapsXmlFormat")
  command -nargs=0 DapsXmlFormat call s:DapsXmlFormat(<f-args>)
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

" opens files that refers to the provided XML:ID
if !exists(":DapsOpenReferers")
  command -nargs=? -complete=custom,s:ListXmlIds DapsOpenReferers :call s:DapsOpenReferers(<f-args>)
endif

" --builddir
if !exists(":DapsSetBuilddir")
  command -nargs=1 -complete=file DapsSetBuilddir :call s:DapsSetBuilddir(<f-args>)
endif
" --styleroot
if !exists(":DapsSetStyleroot")
  command -nargs=1 -complete=file DapsSetStyleroot :call s:DapsSetStyleroot(<f-args>)
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


" - - - - - - - - - - - - -   f u n c t i o n s   - - - - - - - - - - - - "

" read g:daps_* variables from ~/.vimrc and set buffer-wide defaults
function s:Init()
  " fill the  DB schema resolving hash
  let g:daps_db_schema = {
        \'https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rng': 'geekodoc5',
        \'http://www.oasis-open.org/docbook/xml/5.0/rng/docbook.rng': 'docbook50',
        \}

  " check if g:daps_debug is set
  if !exists("b:daps_debug")
    if exists("g:daps_debug")
      let b:daps_debug = g:daps_debug
    else
      let b:daps_debug = 0
    endif
  endif

  " check if g:daps_log_file is set
  if !exists("b:daps_log_file")
    if exists("g:daps_log_file")
      if(writefile(["Start of a new round", "********************"], g:daps_log_file, 'a') == 0)
        let b:daps_log_file = g:daps_log_file
      else
        echoe g:daps_log_file . ' is not writable'
      endif
    endif
  endif

  " determine daps root and daps cmd
  if !exists("b:daps_dapsroot")
    if !exists("g:daps_dapsroot")
      let b:daps_dapsroot = '/usr/share/daps'
      let b:daps_dapscmd = '/usr/bin/daps'
      let b:daps_dapscfgdir = '/etc/daps/'
    else
      let b:daps_dapsroot = g:daps_dapsroot
      let b:daps_dapscmd = b:daps_dapsroot . '/bin/daps --dapsroot=' . b:dapsroot
      let b:daps_dapscfgdir = b:daps_dapsroot . '/etc/'
    endif
    call s:dbg('dapsroot -> ' . b:daps_dapsroot)
    call s:dbg('dapscmd -> ' . b:daps_dapscmd)
    call s:dbg('dapscfgdir -> ' . b:daps_dapscfgdir)
  endif

  " set default pattern for DC file completion
  let g:daps_dcfile_glob_pattern = get(g:, 'daps_dcfile_glob_pattern', "DC-*")

  " set default pattern for entity file completion
  let g:daps_entfile_glob_pattern = get(g:, 'daps_entfile_glob_pattern', "*")

  " set default value for stylecheck after save
  let g:daps_stylecheck_on_save = get(g:, 'daps_stylecheck_on_save', 0)

  " set default value for opening qf window after stylecheck
  let g:daps_stylecheck_qfwindow = get(g:, 'daps_stylecheck_qfwindow', 1)

  " decide whether run :DapsValidateFile before :DapsValidate
  if empty("g:daps_auto_validate_file")
    let g:daps_auto_validate_file = 0
  endif

  " set doctype preventively
  call s:DapsSetDoctype()

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


  " decide whether run entity, set doctype, and import on new file open
  let b:daps_entity_import_autostart = get(g:, 'daps_entity_import_autostart', 0)
  if b:daps_entity_import_autostart == 1
    autocmd BufReadPost,FileType docbk call s:DapsImportEntities()
  endif

  " check if 'g:daps_builddir' exists and trigger setting it in current buffer
  let g:daps_builddir = get(g:, 'daps_builddir', getcwd() . '/build/')
  call s:DapsSetBuilddir(g:daps_builddir)
  if exists("g:daps_styleroot")
    call s:DapsSetStyleroot(g:daps_styleroot)
  endif

  " check if 'g:daps_auto_import_xmlids' exists and set default value
  let g:daps_auto_import_xmlids = get(g:, 'daps_auto_import_xmlids', 1)

  " check if 'g:daps_optipng_before_build' exists and set default value
  if !exists("g:daps_optipng_before_build")
    let g:daps_optipng_before_build = 0
  endif

  " check for xmlformat options
  let b:daps_xmlformat_script = get(g:, 'daps_xmlformat_script', 'xmlformat.pl')

  " check for xmlformat config file
  let b:daps_xmlformat_conf = get(g:, 'daps_xmlformat_conf', b:daps_dapscfgdir . 'docbook-xmlformat.conf')
endfunction

function s:dbg(msg)
  if b:daps_debug == 1
    let msg = "DEBUG: " . a:msg
    if exists("b:daps_log_file")
      call writefile([msg], b:daps_log_file, 'a')
    else
      echo msg
    endif
  endif
endfunction

" lists all DC files in the current directory
function s:ListDCfiles(A,L,P)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  return system("ls -1 " . g:daps_dcfile_glob_pattern)
endfunction

" lists XML dictionaries from vim-daps plugin
function s:ListXMLdictionaries(A,L,P)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  " make sure the dict list is unique
  let dict_list = filter(values(g:daps_db_schema),'index(values(g:daps_db_schema), v:val, v:key+1)==-1')
  call s:dbg('dict_list -> ' . dic_list)
  let result = map(copy(dict_list), 'fnamemodify(v:val, ":t:r")')
  call s:dbg('result -> ' . result)
  return join(result, "\n")
endfunction

" list all <xref>s' IDs from the current buffer
function s:ListXrefTargets(A,L,P)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  let cmd = 'xsltproc ' . b:daps_dapsroot . '/tools/get-all-xrefsids.xsl ' . expand('%') . ' | sort -u'
  return system(cmd)
endfunction

" import all XML IDs given a DC-file
function s:DapsImportXmlIds()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  if !empty(s:IsDCfileSet())
    " grep MAIN file out of the DC-file
    let main_file = matchstr(system('grep "^\s*MAIN=" ' . b:dc_file), '"\zs[^"]\+\ze"')
    call s:dbg('main file -> ' . main_file)
    let xsltproc_cmd = 'xsltproc --xinclude ' . b:daps_dapsroot . '/daps-xslt/common/get-all-xmlids.xsl xml/' . main_file
    call s:dbg('xsltproc_cmd -> ' . xsltproc_cmd)
    let g:xmldata_{b:doctype}.xref[1].linkend = sort(systemlist(xsltproc_cmd))
  endif
endfunction

" ask for DC file
function s:AskForDCFile()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  call inputsave()
  let dc_file = input("Enter DC file: ", g:daps_dcfile_glob_pattern, "file")
  call inputrestore()
  redrawstatus
  return s:DapsSetDCfile(dc_file)
endfunction

" set current buffer's DC-* file
function s:DapsSetDCfile(dc_file)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
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
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  if a:0 > 0
    " check if XML ID was provided via cmdline
    call s:dbg("XML ID supplied on the command line -> " . a:1)
    let rootid = a:1
  else
    " check if cursor is on '<xref linkend=""' line and use as a --rootid
    let rootid = matchstr(getline("."), '\c linkend=\([''"]\)\zs.\{-}\ze\1')
    call s:dbg('rootid -> ' . rootid)
    " check if cursor is on '<link xlink:href=""' line
    let href = matchstr(getline("."), '\c xlink:href=\([''"]\)\zs.\{-}\ze\1')
    call s:dbg('href -> ' . href)
    if !empty(href)
      if exists("g:daps_html_viewer")
        execute '! (' . g:daps_html_viewer . ' ' . href . ')'
      else
        execute '! (xdg-open ' . href . ')'
      endif
      redraw!
    endif
  endif
  if !empty(rootid)
    if !empty(s:IsDCfileSet())
      let file_cmd = b:daps_dapscmd . ' -d ' . b:dc_file . ' list-file --rootid=' . rootid . ' 2> /dev/null'
      call s:dbg('file_cmd => ' . file_cmd)
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

" list all XML IDs
function s:ListXmlIds(A,L,P)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  " get list of XML IDs in the current file
  let xmlids = system('xsltproc ' . b:daps_dapsroot . '/daps-xslt/common/get-all-xmlids.xsl ' . expand('%'))
  call s:dbg('Num of XML IDs -> ' . len(xmlids))
  return xmlids
endfunction

" find pages which refer to provided xml:id via <xref linkend>
function s:DapsOpenReferers(...)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  if a:0 > 0
    " check if XML ID was provided via cmdline
    call s:dbg("XML ID supplied on the command line -> " . a:1)
    let xmlid = a:1
  else
    " check if cursor is on 'id=""' line and grep the XML ID from there
    let xmlid = matchstr(getline("."), '\c xml:id=\([''"]\)\zs.\{-}\ze\1')
    call s:dbg("XML ID read from the current line -> " . xmlid)
    if empty(xmlid)
      echoerr "No XML ID specified"
      return 1
    endif
  endif

  if !empty(s:IsDCfileSet())
    " get list of XML files for a given DC file
    let cmd = b:daps_dapscmd . " -d " . b:dc_file . " list-srcfiles --xmlonly"
    call s:dbg("ListXMLfiles cmd -> " . cmd)
    let files = join(systemlist(cmd), ' ')
    call s:dbg("Num of XML files -> " . len(split(files, '\s')))
    let cmd = "grep -in 'linkend=\"" . xmlid . "\"' " . files
    call s:dbg("grepXMLids cmd -> " . cmd)
    let result = systemlist(cmd)
    call s:dbg("Num of occurences -> " . len(result))
    " create a quickfixlist from grep results
    if !empty(result)
      let qflist = []
      let id = 1
      for line in result
        let sl = split(line, ':')
        call add(qflist, {
              \ 'filename': sl[0],
              \ 'lnum': sl[1],
              \ 'text': sl[2],
              \})
        let id += 1
      endfor
      call setqflist(qflist)
      execute 'copen'
    else
      echom "No '" . xmlid . "' occurence found in XML files"
      execute 'cclose'
    endif
  endif
endfunction

" set doctype for DB documents
function s:DapsSetDoctype(...)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  if a:0 == 0
    call s:dbg('No doctype specified on the cmdline, trying .vimrc')
    if exists("g:daps_doctype")
      call s:dbg("'g:daps_doctype' is '" . g:daps_doctype . "', taking that")
      let b:doctype = g:daps_doctype
    else
      let b:doctype = "docbook50"
      call s:dbg("No 'g:daps_doctype' is set, defaulting to '" . b:doctype . "'")
    endif
  else
    let b:doctype = a:1
    call s:dbg("doctype '" . b:doctype . "' was specified on the cmdline, taking that")
  endif
  call xmlcomplete#CreateConnection(b:doctype)
  call s:DapsImportEntities()
endfunction

" get DC file
function s:IsDCfileSet()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  if exists("b:dc_file")
    call s:dbg('DC file was set with DapsSetDCfile() -> ' . b:dc_file)
    return b:dc_file
  elseif exists("g:daps_dc_file")
    let b:dc_file = g:daps_dc_file
    call s:dbg('DC file was set in (per project) .vimrc -> ' . b:dc_file)
    return b:dc_file
  else
    call s:dbg('Asking the user for DC file')
    return s:AskForDCFile()
  endif
endfunction

" run command 'cmd' in a terminal buffer named 'name' with exit callback
" 'exit_cb'
function s:RunCmdTerm(cmd, name, exit_cb)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  let cmd = a:cmd
  let name = a:name
  let exit_cb = a:exit_cb
  call s:dbg('name of terminal buffer -> ' . name)
  call s:dbg('command for terminal buffer -> ' . cmd)
  call s:dbg('function for exit callback -> ' . exit_cb)
  " close existing terminal buffer with the same name
  let ex_term_buf_no = bufnr(name)
  call s:dbg('ex_term_buf_no -> ' . ex_term_buf_no)
  if ex_term_buf_no > -1
    execute 'bwipeout! ' . ex_term_buf_no
  endif
  " start the command itself
  let term_buf_no = term_start(cmd, {'term_name': name, 'term_rows': 10, 'exit_cb': exit_cb})
  " return to the editing buffer
  wincmd p
  return term_buf_no
endfunction

" validates the document based on the DC file with tab completion
function s:DapsValidate()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  if !empty(s:IsDCfileSet())
    " check whether to run DapsValidateFile first and return 1 on error
    if g:daps_auto_validate_file == 1 && s:DapsValidateFile() == 1
      return 1
    endif
    let validate_cmd = b:daps_dapscmd . ' -vv -d ' . b:dc_file
    if exists('b:styleroot')
      let validate_cmd .= ' --styleroot=' . b:styleroot
    endif
    let validate_cmd .= ' validate'
    call s:dbg('validate_cmd -> ' . validate_cmd)
    " let the command run in vim terminal
    let term_buf_no = s:RunCmdTerm(validate_cmd, 'daps', 'ValidateQuickfix_cb')
  endif
endfunction

" callback for creating quickfix list with validation errors
function ValidateQuickfix_cb(job, exit_status)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  let job = a:job
  call s:dbg('job -> ' . job)
  let term_buf_no = ch_getbufnr(job, 'out')
  call s:dbg('term_buf_no -> ' . term_buf_no)
  " wait some time til terminal buffer synchronizes
  call term_wait(term_buf_no, 150)
  " go thru the terminal output and find errors if any
  let result = getbufline(term_buf_no, 1, '$')
  " remove lines without ":"
  call filter(result, "v:val =~ '^/.*:\\d\\+:'")
  let qflist = []
  for line in result
    let sl = split(line, ':')
    call add(qflist, {
          \ 'filename': 'xml/' . split(sl[0], '/')[-1],
          \ 'lnum': sl[1] + 5,
          \ 'type': 'error',
          \ 'text': sl[4],
          \})
  endfor
  call setqflist(qflist)
  execute 'cwindow'
endfunction

" daps style check
function s:DapsStylecheck()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  " erase all signs and underlinings
  call clearmatches()
  execute 'sign unplace *'
  " check for 'vale' binary
  if !executable('vale')
    echoe "Command 'vale' was not found"
    return 1
  endif
  " remember current path, find the path of the active file and cd to that dir
  let cwd = getcwd()
  let current_file_dir = expand('%:h')
  exe "lcd " . current_file_dir
  let current_file_path = expand('%:t')
  " compile vale command and run it
  let vale_cmd = "vale --output " . s:plugindir . "/tools/vale_template --no-wrap --config " . s:plugindir . "/.vale.ini " . current_file_path
  call s:dbg('vale_cmd -> ' . vale_cmd)
  silent let output = systemlist(vale_cmd)
  " remove empty lines from the output
  call filter(output, 'v:val != ""')
  call s:dbg('output -> ' . string(output))
  " sort the output so that ERRORS are first and SUGGESTIONS last
  let sorted_output = sort(output, 'CompareStylePriority')
  call s:dbg('output -> ' . string(sorted_output))
  " cd back to cwd
  exe "lcd " . cwd
  " define signs for quickfix list
  let qflist = []
  let id = 1
  sign define error text=E
  sign define warning text=W
  sign define suggestion text=S
  if len(sorted_output) > 0
    for line in sorted_output
      call s:dbg('line -> ' . string(line))
      if !empty(line)
        " get the line array
        let la = split(trim(line), ':')
        let item = { 'bufnr': bufnr('%'), 'lnum': la[1], 'col': la[2], 'type': la[3], 'text': la[5] }
        call add (qflist, item)
        execute 'sign place ' . id . ' line=' . la[1] . ' name=' . la[3] . ' file=' . bufname('%')
        call matchadd('Underlined', '\%' . la[1] . 'l\%' . la[2] . 'c\k\+')
        let id += 1
      endif
    endfor
    call setqflist(qflist)
    if g:daps_stylecheck_qfwindow == 1
      execute 'copen'
    endif
  else
    execute 'cclose'
    execute 'sign unplace *'
    echow 'No style mistakes found'
  endif
endfunction

" validates the current file only
function s:DapsValidateFile()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  " get the schema URI
  call s:dbg('g:daps_db_schema size -> ' . len(g:daps_db_schema))
  for [key, value] in items(g:daps_db_schema)
    if value == b:doctype
      let schema_uri = key
      break
    endif
  endfor
  call s:dbg('schema_uri -> ' . schema_uri)
  if exists('schema_uri')
    " get the schema file
    let schema_file = systemlist('xmlcatalog /etc/xml/catalog ' . schema_uri)[0]
    " if the result starts with 'No entry', then schema is missing in catalogue
    if strpart(schema_file, 0, 8) == 'No entry'
      echoe 'Schema uri ' . schema_uri . ' is missing in XML catalog'
      return 1
    endif
    call s:dbg('schema_file -> ' . schema_file)
    " run jing to check the current file's structure
    let jing_cmd = 'jing -i ' . schema_file . ' ' . expand('%')
    call s:dbg('jing_cmd -> ' . jing_cmd)
    let jing_result = systemlist(jing_cmd)
    call s:dbg('jing_result size -> ' . len(jing_result))
    if !empty(jing_result)
      " define signs
      sign define error text=E
      sign define warning text=W
      sign define fatal text=F
      let qflist = []
      let id = 1
      for line in jing_result
        let sl = split(line, ':')
        call add(qflist, {
              \ 'filename': sl[0],
              \ 'lnum': sl[1],
              \ 'col': sl[2],
              \ 'type': substitute(sl[3], ' ', '', ''),
              \ 'text': strpart(sl[4], 0, 70) . '...',
              \})
        execute 'sign place ' . id . ' line=' . sl[1] . ' name=' . substitute(sl[3], ' ', '', '') . ' file=' . sl[0]
        let id += 1
      endfor
      call setqflist(qflist)
      execute 'copen' len(qflist) + 4
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

" builds the current chapter
function s:DapsBuild(target)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  if !empty(s:IsDCfileSet())
    " save the build target across buffers
    let s:DapsBuildTarget = a:target
    call s:dbg('DapsBuildTarget -> ' . s:DapsBuildTarget)
    " assemble daps cmdline
    let dapscmd = b:daps_dapscmd . ' -vv -d ' . b:dc_file
    if exists('b:styleroot')
      let dapscmd .= ' --styleroot=' . b:styleroot
    endif
    if exists('b:builddir')
      let dapscmd .= ' --builddir=' . b:builddir
    endif
    let dapscmd .= ' ' . a:target
    let dapscmd .= ' 2> /dev/null'
    call s:dbg('dapscmd -> ' . dapscmd)
    " run dapscmd in a terminal window
    let term_buf_no = s:RunCmdTerm(dapscmd, 'daps', 'BuildTarget_cb')
  endif
endfunc

" callback to run build inside a trminal winow
function BuildTarget_cb(job, exit_status)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  let job = a:job
  call s:dbg('job -> ' . job)
  let term_buf_no = ch_getbufnr(job, 'out')
  " wait some time til terminal buffer synchronizes
  call term_wait(term_buf_no, 150)
  call s:dbg('term_buf_no -> ' . term_buf_no)
  " read the last line of the terminal
  let target_dir = getbufoneline(term_buf_no, '$')
  call s:dbg('term_last_line -> ' . target_dir)
  if s:DapsBuildTarget == 'html'
    let target_file = target_dir . 'index.html'
  else
    let target_file = target_dir
  endif
  call s:dbg('target_file -> ' . target_file)
  if exists("g:daps_" . s:DapsBuildTarget . "_viewer")
    let doc_viewer = g:daps_{s:DapsBuildTarget}_viewer
    let cmd = doc_viewer . ' ' . target_file
  else
    let cmd = 'xdg-open ' . target_file
  endif
  call s:dbg('viewer cmd -> ' . cmd)
  call job_start(cmd)
endfunction

" formats the XML source of the active buffer
function s:DapsXmlFormat()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  let buffer_content = getline(1, '$')
  let xml_format_cmd = b:daps_xmlformat_script . ' -f ' . b:daps_xmlformat_conf
  call s:dbg('xmlformat cmd -> ' . xml_format_cmd)
  try
    " Save the current cursor position
    let save_cursor = getpos(".")
    let command_output = systemlist(xml_format_cmd, buffer_content)
    if strpart(command_output[0],0,5) == 'Error'
      throw 'XML document is invalid'
    endif
    silent %delete
    " put the formatted buffer at zeroth line
    silent :0put =command_output
    " Restore the cursor position
    call setpos('.', save_cursor)
    echo 'XML document formatted'
  catch
    echo "An error occurred: " . v:exception
  endtry
endfunction

" imports Entities from a file to a DTD file
" 1) look if arguments are a list of entity files and try to extract Entities;
" 2) if no argument is given, run getentityname.py to get the list of files
function s:DapsImportEntities(...)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  if a:0 == 0
    " return for fugitive:// paths
    if expand('%:p') =~ '^fugitive'
      return
    endif
    " no arg given, try daps' getentityname.py
    let getentityname = b:daps_dapsroot . '/libexec/getentityname.py'
    call s:dbg('getentityname -> ' . getentityname)
    let ent_str = substitute(system(getentityname . ' ' . expand('%:p')), '\n\+$', '', '')
    call s:dbg('ent_str -> ' . ent_str)
    let ent_files = split(ent_str, ' ')
    if len(ent_files) == 0
      " no ent files provided or found
      call s:dbg('No entity file(s) could be extracted, specify them on the command line')
      return
    endif
  else
    let ent_files = a:000
  endif
  call s:dbg('Num of ent_str -> ' . len(ent_files))

  for ent_file in ent_files
    " check if file exists
    let ent_file = expand(ent_file)
    call s:dbg('ent_file -> ' . ent_file)
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
    call s:dbg('b:doctype -> ' . b:doctype)
    let g:xmldata_{b:doctype}['vimxmlentities'] += list
  endfor
  let sorted = sort(copy(g:xmldata_{b:doctype}['vimxmlentities']))
  let g:xmldata_{b:doctype}['vimxmlentities'] = copy(sorted)
  unlet sorted
  unlet line
endfunction

" lookup doctype info from xml/schemas.xml file
function s:DapsLookupSchemasXML()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  " test for the xml/schemas.xml file
  if filereadable('xml/schemas.xml')
    let x_query = '/t:locatingRules/t:uri/@uri'
    let x_cmd = "xmlstarlet sel -T -N t='http://thaiopensource.com/ns/locating-rules/1.0' -t -v '" . x_query . "' xml/schemas.xml"
    let x_result = systemlist(x_cmd)[0]
    if filereadable(x_result)
      return x_result
    endif
  endif
endfunction

" set --buildroot for the current buffer
function s:DapsSetBuilddir(builddir)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  " check if builddir exists and if it is a writable directory
  if filewritable(a:builddir) == 2
    let b:builddir = a:builddir
  elseif mkdir(a:builddir, "p")
    let b:builddir = a:builddir
  else
    echoerr a:builddir . ' is not a writable directory'
  endif
endfunction

" set --styleroot for customstylesheets (overriding DC-* file setting)
function s:DapsSetStyleroot(styleroot)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  " check if styleroot is writable
  if isdirectory(a:styleroot)
    let b:styleroot = a:styleroot
  else
    echoerr a:styleroot . ' is not a directory'
  endif
endfunction

" compares priority of style check results
function CompareStylePriority(a, b)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  let a_priority = -1
  let b_priority = -1
  if a:a =~# 'error'
    let a_priority = 0
  elseif a:a =~# 'warning'
    let a_priority = 1
  elseif a:a =~# 'suggestion'
    let a_priority = 2
  endif
  if a:b =~# 'error'
    let b_priority = 0
  elseif a:b =~# 'warning'
    let b_priority = 1
  elseif a:b =~# 'suggestion'
    let b_priority = 2
  endif
  return (a_priority - b_priority)
endfunction

" - - - - - - - - - - - - -  e n d  f u n c t i o n s   - - - - - - - - - - - - "

" restore the value of cpoptions
let &cpo = s:save_cpo
