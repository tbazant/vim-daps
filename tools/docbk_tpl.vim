" This file includes common docbook snippets templates.
" It assumes that vim works in an xml/docbook mode,
" and that the xml.vim plugin is installed and active.
"
" For example, writing
"       ,,pr
" will result in
"       <procedure>
"        <step>
"         <para>
"         </para>
"        </step>
"       </procedure>

map! ,,c  <command>
map! ,,em <emphasis>
map! ,,ex <example>>,,tt
map! ,,f  <filename>
map! ,,fg <figure>>,,tt<ESC>A<CR><mediaobject>><imageobject role="fo">><imagedata fileref="" width="70%" format="PNG"/><ESC>jA<CR><imageobject role="html">><imagedata fileref="" width="70%" format="PNG"/><ESC>6k7hi
map! ,,g  <guimenu>
map! ,,id xml:id=""
map! ,,il <itemizedlist>>,,li
map! ,,im <important>>,,tt<ESC>A<CR>,,pa<ESC>2k7li
map! ,,li <listitem>>,,pa
map! ,,ll <literal>
map! ,,ln <link xlink:href=""/><ESC>2hi
map! ,,nt <note>>,,tt<ESC>A<CR>,,pa<ESC>2k7li
map! ,,op <option>
map! ,,pa <para>>
map! ,,pr <procedure>>,,st
map! ,,q  <quote>
map! ,,r  <replaceable>
map! ,,s1 <sect1 ,,id>>,,tt<ESC>A<CR>,,pa<ESC>2k7li
map! ,,s2 <sect2 ,,id>>,,tt<ESC>A<CR>,,pa<ESC>2k7li
map! ,,s3 <sect3>>,,tt<ESC>A<CR>,,pa<ESC>2k7li
map! ,,sc <screen>><ESC>kVjj:le<CR>ji
map! ,,si <systemitem>
map! ,,sid <systemitem class="daemon">
map! ,,siip <systemitem class="ipaddress">
map! ,,siu <systemitem class="username">
map! ,,sir <systemitem class="resource">
map! ,,st <step>>,,pa
map! ,,tp <tip>>,,tt<ESC>A<CR>,,pa
map! ,,tt <title>
map! ,,ve <varlistentry>>,,li<ESC>3kA<CR><term>
map! ,,vl <variablelist>>,,ve
map! ,,w <warning>>,,tt<ESC>A<CR>,,pa<ESC>2k6li
map! ,,x  <xref linkend=""/><ESC>2hi
