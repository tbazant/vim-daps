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

" define actions triggered by events
" read g:daps_* variables from .vimrc and set defaults
autocmd FileType docbk :call s:Init()

" - - - - - - - - - - - - -  c o m m a n d   d e f i n i t i o n s   - - - - - - - - - - - - "
" dummy command and function for testing purposes
if !exists(":DapsDummy")
  command -nargs=* DapsDummy :call s:DapsDummy(<f-args>)
endif

" set default DC-* file for current buffer
if !exists(":DapsSetDCfile")
  command -complete=custom,s:ListDCfiles -nargs=1 DapsSetDCfile :call s:DapsSetDCfile(<f-args>)
endif

" set default build target for current buffer
if !exists(":DapsSetBuildTarget")
  command -complete=customlist,s:ListBuildTargets -nargs=1 DapsSetBuildTarget :call s:DapsSetBuildTarget(<f-args>)
endif

"build doc by specified target
if !exists(":DapsBuild")
  command -complete=customlist,s:ListBuildTargets -nargs=? DapsBuild :call s:DapsBuild(<f-args>)
endif

" set --rootid for the current buffer
if !exists(":DapsSetRootId")
  command -nargs=1 DapsSetRootId :call s:DapsSetRootId(<f-args>)
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

" daps -m xml_file html --single --norefcheck
if !exists(":DapsBuildXmlFile")
  command -nargs=? DapsBuildXmlFile :call s:DapsBuildXmlFile(<f-args>)
endif

" daps list-file
if !exists(":DapsOpenTarget")
  command -nargs=? -complete=custom,s:ListXrefTargets DapsOpenTarget :call s:DapsOpenTarget(<f-args>)
endif

" opens files that refers to the provided XML:ID
if !exists(":DapsOpenReferers")
  command -nargs=? -complete=custom,s:ListXmlIds DapsOpenReferers :call s:DapsOpenReferers(<f-args>)
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
        \'https://github.com/openSUSE/geekodoc/raw/main/geekodoc/rng/geekodoc5-flat.rng': 'geekodoc5',
        \'http://www.oasis-open.org/docbook/xml/5.0/rng/docbook.rng': 'docbook50',
        \'http://www.oasis-open.org/docbook/xml/5.1/rng/docbook.rng': 'docbook51',
        \'http://www.oasis-open.org/docbook/xml/5.2/rng/docbook.rng': 'docbook52',
        \}

  "   L   O   G   G   I   N   G
  let b:daps_debug = get(g:, 'daps_debug', 0)
  if b:daps_debug == 1
    let b:daps_log_file = get(g:, 'daps_log_file')
    " check if file exists and is writable, or try to create an empty one
    try
      call writefile(["Start of a new round", "********************"], b:daps_log_file, 'a')
    catch
      echoerr "Error creating the file: " . v:exception
    endtry
  endif

  "   O  P  T  I  O  N  S'    D  E  F  A  U  L  T     V  A  L  U  E  S
  let b:daps_executable = get(g:, 'daps_executable', '/usr/bin/daps')
  let b:daps_dapsroot = get(g:, 'daps_dapsroot')
  let b:daps_verbosity_level = get(g:, 'daps_verbosity_level', 2)
  let b:daps_dcfile_glob_pattern = get(g:, 'daps_dcfile_glob_pattern', "DC-")
  let b:daps_entfile_glob_pattern = get(g:, 'daps_entfile_glob_pattern', "*")
  let b:daps_stylecheck_on_save = get(g:, 'daps_stylecheck_on_save', 0)
  let b:daps_stylecheck_qfwindow = get(g:, 'daps_stylecheck_qfwindow', 1)
  let b:daps_builddir = get(g:, 'daps_builddir', getcwd() . '/build/')
  let b:daps_styleroot = get(g:, 'daps_styleroot')
  let b:daps_auto_import_xmlids = get(g:, 'daps_auto_import_xmlids', 1)
  let b:daps_xmlformat_script = get(g:, 'daps_xmlformat_script', 'xmlformat.pl')
  let b:daps_xmlformat_conf = get(g:, 'daps_xmlformat_conf', '/etc/daps/docbook-xmlformat.conf')
  let b:daps_dc_file = get(g:, 'daps_dc_file')
  let b:daps_root_id = get(g:, 'daps_root_id')
  let b:daps_build_target = get(g:, 'daps_build_target')
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

endfunction

function s:dbg(msg)
  if b:daps_debug == 1
    let msg = "DEBUG: " . a:msg
    if exists("b:daps_log_file") && !empty(b:daps_log_file)
      call writefile([msg], b:daps_log_file, 'a')
    else
      echom msg
    endif
  endif
endfunction

" lists all DC files in the current directory
function s:ListDCfiles(A,L,P)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  return system("ls -1 " . g:daps_dcfile_glob_pattern)
endfunction
"
" lists all DC files in the current directory
function s:ListBuildTargets(A,L,P)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  return ['html', 'pdf']
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
  let cmd = 'xsltproc ' . s:plugindir . '/tools/get-all-xrefsids.xsl ' . expand('%') . ' | sort -u'
  return system(cmd)
endfunction

" import all XML IDs given a DC-file
function s:DapsImportXmlIds()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  let dc_file = s:getDCfile()
  if !empty(dc_file)
    " grep MAIN file out of the DC-file
    let main_file = matchstr(system('grep "^\s*MAIN=" ' . dc_file), '"\zs[^"]\+\ze"')
    call s:dbg('main file -> ' . main_file)
    let dapsroot = exists(b:daps_dapsroot) ? b:daps_dapsroot : '/usr/share/daps'
    let xsltproc_cmd = 'xsltproc --xinclude ' . dapsroot . '/daps-xslt/common/get-all-xmlids.xsl xml/' . main_file
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

" ask for build target
function s:AskForBuildTarget()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  call inputsave()
  let build_target = input("Enter build target: ", "", "custom,s:ListBuildTargets")
  call inputrestore()
  redrawstatus
  return s:DapsSetBuildTarget(build_target)
endfunction

" set current buffer's DC-* file
function s:DapsSetDCfile(dc_file)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  if filereadable(a:dc_file)
    "set dc_file for current buffer
    let b:daps_dc_file = a:dc_file
    "if not already specified, set DC file globally so that new buffers inherit it
    if !exists("g:daps_dc_file")
      let g:daps_dc_file = b:daps_dc_file
    endif
    if g:daps_auto_import_xmlids == 1
      call s:DapsImportXmlIds()
    endif
    return b:daps_dc_file
  else
    echoerr "The specified DC file is not readable."
  endif
endfunction

" set current buffer's build target
function s:DapsSetBuildTarget(build_target)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  "set build target for the current buffer
  let b:daps_build_target = a:build_target
  "define script-wide variable for detached terminal
  let s:daps_build_target = a:build_target
  "if not already specified, set build target globally so that new buffers inherit it
  if !exists("g:daps_build_target")
    let g:daps_build_target = b:daps_build_target
    call s:dbg('g:daps_build_target -> ' . g:daps_build_target)
  endif
  return b:daps_build_target
endfunction

"set --rootid for the current buffer
function s:DapsSetRootId(root_id)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  let b:daps_root_id = a:root_id
  call s:dbg('b:daps_root_id -> ' . b:daps_root_id)
  return b:daps_root_id
endfunction

" implement `daps list-file`
function s:DapsOpenTarget(...)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  "check if XML ID was provided via cmdline
  if a:0 > 0
    "xml_id was provided via cmdline
    let xml_id = a:1
    call s:dbg("xml_id from cmdline -> " . xml_id)
  else
    " check if cursor is on '<xref linkend=""' line and use as a --rootid
    let xml_id = matchstr(getline("."), '\c linkend=\([''"]\)\zs.\{-}\ze\1')
    call s:dbg('xml_id from <xref/> line -> ' . xml_id)
  endif
  if !empty(xml_id)
    let cmd = 'grep -n xml:id=\"' . xml_id . '\" */*.xml'
    call s:dbg('cmd => ' . cmd)
    let output = systemlist(cmd)
    if len(output) == 0
      echom "No file contains the refered xml:id '" . xml_id . "'"
    else
      for line in output
        let line_arr = split(line,":")
        execute 'tabnew ' . line_arr[0] | execute 'normal ' . line_arr[1] . 'G'
      endfor
    endif
  else
    echom "No linkend xml:id specified"
  endif
endfunction

" list all XML IDs
function s:ListXmlIds(A,L,P)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  " get list of XML IDs in the current file
  let dapsroot = exists(b:daps_dapsroot) ? b:daps_dapsroot : '/usr/share/daps'
  let xmlids = system('xsltproc ' . dapsroot . '/daps-xslt/common/get-all-xmlids.xsl ' . expand('%'))
  call s:dbg('Num of XML IDs -> ' . len(xmlids))
  return xmlids
endfunction

" find pages which refer to provided xml:id via <xref linkend>
function s:DapsOpenReferers(...)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  " check if XML ID was provided via cmdline
  if a:0 > 0
    let xml_id = a:1
    call s:dbg("xml_id from cmdline -> " . xml_id)
  else
    " check if cursor is on 'id=""' line and grep the XML ID from there
    let xml_id = matchstr(getline("."), '\c xml:id=\([''"]\)\zs.\{-}\ze\1')
    call s:dbg('xml_id from <xref/> line -> ' . xml_id)
  endif
  if !empty(xml_id)
    let cmd = 'grep -n linkend=\"' . xml_id . '\" */*.xml'
    call s:dbg('cmd => ' . cmd)
    let output = systemlist(cmd)
    if len(output) == 0
      echom "No file refers to xml:id '" . xml_id . "'"
    else
      for line in output
        let line_arr = split(line,":")
        execute 'tabnew ' . line_arr[0] | execute 'normal ' . line_arr[1] . 'G'
      endfor
    endif
  else
    echom "No xml:id specified"
  endif
endfunction

" set doctype for DB documents
function s:DapsSetDoctype(...)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  if a:0 == 0
    call s:dbg("doctype is not specified, trying .vimrc or taking default")
    let b:doctype = get(g:, 'daps_doctype', 'docbook52')
  else
    call s:dbg("doctype specified on the cmdline, taking that")
    let b:doctype = a:1
  endif
  call s:dbg("doctype -> " . b:doctype)
  call xmlcomplete#CreateConnection(b:doctype)
  call s:DapsImportEntities()
endfunction

" discover DC file
function s:getDCfile()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  if exists("b:daps_dc_file") && !empty(b:daps_dc_file)
    call s:dbg('Buffer DC file -> ' . b:daps_dc_file)
    return b:daps_dc_file
  else
    call s:dbg('Asking the user for DC file')
    return s:AskForDCFile()
  endif
endfunction

" discover build target file
function s:getBuildTarget()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  if exists("b:daps_build_target")
    call s:dbg('Buffer build target -> ' . b:daps_build_target)
    return b:daps_build_target
  else
    call s:dbg('Asking the user for build target')
    return s:AskForBuildTarget()
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
  let dc_file = s:getDCfile()
  if !empty(dc_file)
    let params = { 'dc_file': dc_file, 'cmd': 'validate' }
    let cmd = s:getDapsCmd(params)
    " let the command run in vim terminal
    let term_buf_no = s:RunCmdTerm(cmd, 'daps', 'ValidateQuickfix_cb')
  endif
endfunction

" callback for creating quickfix list with validation errors
function ValidateQuickfix_cb(job, exit_status)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  let job = a:job
  call s:dbg('job -> ' . job)
  " erase all signs and underlinings
  call clearmatches()
  execute 'cclose'
  execute 'sign unplace *'
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
  execute 'cclose'
  execute 'sign unplace *'
  " check for 'vale' binary
  if !executable('vale')
    echoe "Command 'vale' was not found"
    return 1
  endif
  "save the current  buffer to disk
  write
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
  " sort the output so that ERRORS are first and SUGGESTIONS last
  let sorted_output = sort(output, 's:CompareStylePriority')
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

" general build command
function s:DapsBuild(build_target='')
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  call s:dbg('a:build_target -> ' . a:build_target)
  "if target is specified, set it as default for this buffer
  if !empty(a:build_target)
    call s:DapsSetBuildTarget(a:build_target)
  endif
  let dc_file = s:getDCfile()
  if !empty(dc_file)
    " assemble daps cmdline
    let cmd = s:getDapsCmd({ 'dc_file': dc_file, 'build_target': s:getBuildTarget() })
    call s:dbg('daps cmdline -> ' . cmd)
    " run dapscmd in a terminal window
    let term_buf_no = s:RunCmdTerm(cmd, 'daps', 'BuildTarget_cb')
  endif
endfunction

" builds HTML from the specified XML file (or the current buffer's file by
" default)
function s:DapsBuildXmlFile()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  let xml_file = expand('%')
  " save the active buffer to disk
  silent write
  let cmd = s:getDapsCmd({ 'xml_file': xml_file, 'build_target': 'html', 'options': [ '--single', '--norefcheck']})
  let s:daps_build_target = 'html'
  let term_buf_no = s:RunCmdTerm(cmd, 'daps', 'BuildTarget_cb')
endfunction

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
  if s:daps_build_target == 'html'
    let target_file = target_dir . 'index.html'
  else
    let target_file = target_dir
  endif
  call s:dbg('target_file -> ' . target_file)
  if exists("g:daps_" . s:daps_build_target . "_viewer")
    let doc_viewer = g:daps_{s:daps_build_target}_viewer
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
  " clear all error windows and signs
  execute 'cclose'
  call clearmatches()
  execute 'sign unplace *'
  let xml_file = expand('%')
  call s:dbg('xml_file -> ' . xml_file)
  " ask to save the current buffer to disk if modified
  if &modified
    let input = input('Buffer is dirty, save before formatting? ', 'yes')
    if input == 'yes'
      silent write
    else
      silent echon 'Cannot format dirty buffer'
      return 0
    endif
  endif
  let cmd = b:daps_xmlformat_script . ' -i -f ' . b:daps_xmlformat_conf . ' ' . xml_file
  call s:dbg('xmlformat cmd -> ' . cmd)
  " Save the current cursor position
  let save_cursor = getpos(".")
  " remove questions to re-load the file from disk
  if &autoread
    let autoread_was_before=1
  else
    let autoread_was_before=0
    set autoread
  endif
  " run xmlformat
  let result = systemlist(cmd)
  " see if there were errors; empty result means no  errors
  if len(result) > 0
    " define signs for quickfix list
    let qflist = []
    let id = 1
    sign define error text=E
    let pattern = 'Error near line'
    for line in result
      if strpart(line, 0, len(pattern)) ==# pattern
        call s:dbg('item -> ' . line)
        "create qflist and signs
        let lnum = matchstr(line, 'line \zs\d\+')
        let tag = matchstr(line, '(\zs[^(]\+\ze)')
        let err_msg = matchstr(line, ':\zs.*')
        let item = { 'bufnr': bufnr('%'), 'lnum': lnum, 'type': 'error', 'text': tag . ':' .err_msg }
        call add (qflist, item)
        let sign_cmd = 'sign place ' . id . ' line=' . lnum . ' name=error file=' . bufname('%')
        call s:dbg('sign_cmd -> ' . sign_cmd)
        execute sign_cmd
        let id += 1
      endif
    endfor
    call setqflist(qflist)
    execute 'copen'
    return 0
  else
    " reload the file from disk
    edit! %
    " re-eanble questions to re-load the file from disk
    if autoread_was_before == 0
      set noautoread
    endif
    " Restore the cursor position
    call setpos('.', save_cursor)
    redraw | echo 'XML document is formatted'
    return 1
  endif
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
    let dapsroot = exists(b:daps_dapsroot) ? b:daps_dapsroot : '/usr/share/daps'
    let getentityname = dapsroot . '/libexec/getentityname.py'
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
    call s:dbg('xquery result -> ' . x_result)
    if filereadable(x_result)
      return x_result
    endif
  endif
endfunction

" compares priority of style check results
function s:CompareStylePriority(a, b)
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

function s:getDapsCmd(params)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  let daps_cmd = []
  call add(daps_cmd, b:daps_executable)
  if !empty(b:daps_dapsroot)
    call add(daps_cmd, '--dapsroot ' . b:daps_dapsroot)
  endif
  if !empty(b:daps_verbosity_level)
    call add(daps_cmd, '-v' . b:daps_verbosity_level)
  endif
  if !empty(b:daps_styleroot)
    call add(daps_cmd, '--styleroot ' . b:daps_styleroot)
  endif
  if exists("a:params['dc_file']") && !empty(a:params['dc_file'])
    call add(daps_cmd, '-d ' . a:params['dc_file'])
  elseif exists("a:params['xml_file']") && !empty(a:params['xml_file'])
    call add(daps_cmd, '-m ' . a:params['xml_file'])
  endif
  if exists("a:params['cmd']") && !empty(a:params['cmd'])
    call add(daps_cmd, a:params['cmd'])
    if exists("a:params['rootid']") && !empty(a:params['rootid'])
      call add(daps_cmd, '--rootid ' . a:params['rootid'])
    endif
  elseif exists("a:params['build_target']") && !empty(a:params['build_target'])
    call add(daps_cmd, a:params['build_target'])
    if exists("b:daps_root_id") && !empty(b:daps_root_id)
      call add(daps_cmd, '--rootid ' . b:daps_root_id)
    endif
  endif
  if exists("a:params['options']") && !empty(a:params['options'])
    call add(daps_cmd, join(a:params['options'], ' '))
  endif
  let cmd = join(daps_cmd, ' ')
  return cmd
endfunction

" - - - - - - - - - - - - -  e n d  f u n c t i o n s   - - - - - - - - - - - - "

" restore the value of cpoptions
let &cpo = s:save_cpo
