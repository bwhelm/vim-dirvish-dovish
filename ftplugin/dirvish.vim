" Only do this when not done yet for this buffer
if exists("b:dovish_ftplugin")
  finish
endif
let b:dovish_ftplugin = 1

if !exists('g:DovishCopyFile')
  function! g:DovishCopyFile(target, destination) abort
    return 'cp ' . shellescape(a:target) . ' ' . shellescape(a:destination)
  endfunction
end

if !exists('g:DovishCopyDirectory')
  function! g:DovishCopyDirectory(target, destination) abort
    return 'cp -r ' . shellescape(a:target) . ' ' . shellescape(a:destination)
  endfunction
end

if !exists('g:DovishMove')
  function! g:DovishMove(target, destination) abort
    return 'mv ' . shellescape(a:target) . ' ' . shellescape(a:destination)
  endfunction
end

if !exists('g:DovishDelete')
  function! g:DovishDelete(target) abort
      if exists('g:device') && g:device =~ "mac"
          return 'mv ' . shellescape(a:target) . ' ~/.Trash/'
      else
          return 'rm ' . shellescape(a:target)
      endif
  endfunction
end

if !exists('g:DovishRename')
  function! g:DovishRename(target, destination) abort
    return 'mv ' . shellescape(a:target) . ' ' . shellescape(a:destination)
  endfunction
end

function! s:moveCursorTo(target)
  call search('\V'.escape(a:target, '\\').'\$')
endfunction

function! s:getVisualSelection()
  if mode()=="v"
    let line_start = getpos("v")[1]
    let line_end = getpos(".")[1]
  else
    let line_start = getpos("'<")[1]
    let line_end = getpos("'>")[1]
  end
  if line_start > line_end
      let [line_start, line_end] = [line_end, line_start]
  endif
  let lines = getline(line_start, line_end)
  if len(lines) == 0
    return ''
  endif
  return lines
endfunction

" function! s:createFile() abort
"   " Prompt for new filename
"   let filename = input('File name: ')
"   if trim(filename) == ''
"     return
"   endif
"   " Append filename to the path of the current buffer
"   let filepath = expand("%") . filename
"
"   let output = system("touch " . shellescape(filepath))
"   if v:shell_error
"     call s:logError(cmd)
"   endif
"
"   " Reload the buffer
"   Dirvish %
"   call s:moveCursorTo(filename)
" endf
"
" function! s:createDirectory() abort
"   let dirname = input('Directory name: ')
"   if trim(dirname) == ''
"     return
"   endif
"   let dirpath = expand("%") . dirname
"   if isdirectory(dirpath)
"     redraw
"     echomsg printf('"%s" already exists.', dirpath)
"     return
"   endif
"
"   let output = system("mkdir " . shellescape(dirpath))
"   if v:shell_error
"     call s:logError(output)
"   endif
"
"   " Reload the buffer
"   Dirvish %
"   call s:moveCursorTo(dirname . '/')
" endf

function! s:deleteItemUnderCursor() abort
  " Grab the line under the cursor. Each line is a filepath
  let target = trim(getline('.'))
  " Feed the filepath to a delete command like, rm or trash
  let check = confirm("Delete ".target, "&Yes\n&No", 2)
  if check != 1
    echo 'Cancelled.'
    return
  endif
  let output = system(g:DovishDelete(target))
  if v:shell_error
    call s:logError(output)
  endif

  " Reload the buffer
  Dirvish %
endfunction

function! s:deleteSelectedItems() abort
  let lines = s:getVisualSelection()
  " Confirm selection
  echo join(map(copy(lines), 'fnamemodify(v:val, ":t")'), "\n") .. "\n"
  let check = confirm("Delete the above?", "&Yes\n&No", 2)
  if check !=1
      echo "Cancelled."
      return
  endif

  " Delete each item
  for item in lines
      let output = system(g:DovishDelete(item))
      if v:shell_error
          call s:logError(output)
      endif
  endfor

  "Reload the buffer
  Dirvish %
endfunction

function! s:renameItemUnderCursor() abort
  let target = trim(getline('.'))
  let filename = fnamemodify(target, ':t')
  let newname = input('Rename: ', filename)
  if empty(newname) || newname ==# filename
    return
  endif
  let cmd = g:DovishRename(target, expand("%") . newname)
  let output = system(cmd)
  if v:shell_error
    call s:logError(output)
  endif

  " Reload the buffer
  Dirvish %
endfunction

function! s:isPreviouslyYankedItemValid() abort
  if len(s:yanked) < 1
    return 0
  endif

  for target in s:yanked
    if target == ''
      return 0
    endif
  endfor

  return 1
endfunction

function! s:promptUserForRenameOrSkip(filename) abort
  let renameOrSkip = confirm(a:filename." already exists.", "&Rename\n&Abort", 2)
  if renameOrSkip != 1
    return ''
  endif
  return input('Rename to: ', a:filename)
endfunction

function! s:moveYankedItemToCurrentDirectory() abort
  if !s:isPreviouslyYankedItemValid()
    echomsg 'Select a path first!'
    return
  endif

  let cwd = getcwd()
  let destinationDir = expand("%")
  for i in s:yanked
    let item = i
    let filename = fnamemodify(item, ':t')
    let directoryName = split(fnamemodify(item, ':p:h'), '/')[-1]

    if isdirectory(item)
      if (isdirectory(destinationDir . directoryName))
        let directoryName = s:promptUserForRenameOrSkip(directoryName)
        redraw
        if directoryName == ''
          return
        endif
      endif
      let cmd = g:DovishMove(item, destinationDir . directoryName)
    else
      if (!empty(glob(destinationDir . filename)))
        let filename = s:promptUserForRenameOrSkip(filename)
        redraw
        if filename == ''
          return
        endif
      endif
      let cmd = g:DovishMove(item, destinationDir . filename)
    endif

    let output = system(cmd)
    if v:shell_error
      call s:logError(output)
    endif
  endfor

  " Reload the buffer
  Dirvish %
  call s:moveCursorTo(filename)
endfunction

function! s:copyYankedItemToCurrentDirectory() abort
  if !s:isPreviouslyYankedItemValid()
    echomsg 'Select a path first!'
    return
  endif

  let cwd = getcwd()
  let destinationDir = expand("%")

  for i in s:yanked
    let item = i
    let filename = fnamemodify(item, ':t')
    let directoryName = split(fnamemodify(item, ':p:h'), '/')[-1]

    if isdirectory(item)
      if (isdirectory(destinationDir . directoryName))
        let directoryName = s:promptUserForRenameOrSkip(directoryName)
        redraw
        if directoryName == ''
          return
        endif
      endif
      let cmd = g:DovishCopyDirectory(item, destinationDir . directoryName)
    else
      if (!empty(glob(destinationDir . filename)))
        let filename = s:promptUserForRenameOrSkip(filename)
        redraw
        if filename == ''
          return
        endif
      endif

      let cmd = g:DovishCopyFile(item, destinationDir . filename)
    endif

    let output = system(cmd)
    if v:shell_error
      call s:logError(output)
    endif
  endfor

  " Reload the buffer
  Dirvish %
  call s:moveCursorTo(filename)
endfunction

function! s:copyFilePathUnderCursor() abort
  let s:yanked = [trim(getline('.'))]
  echo 'Selected '.s:yanked[0]
endfunction

function! s:copyVisualSelection() abort
  let lines = s:getVisualSelection()
  let s:yanked = lines

  let msg = 'Selected:'
  for file in lines
    " Print a nicely formatted message:
    "
    " @example:
    " Selected:
    " - file/path
    " - another/file/path
    let msg = msg."\n- ".file
  endfor
  echo msg
endfunction

function! s:logError(error) abort
  " clear any current cmdline msg
  redraw
  echohl WarningMsg | echomsg a:error | echohl None
endfunction

" nnoremap <silent><buffer> <Plug>(dovish_create_file) :<C-U> call <SID>createFile()<CR>
" nnoremap <silent><buffer> <Plug>(dovish_create_directory) :<C-U> call <SID>createDirectory()<CR>
nnoremap <silent><buffer> <Plug>(dovish_rename) :<C-U> call <SID>renameItemUnderCursor()<CR>
nnoremap <silent><buffer> <Plug>(dovish_delete) :<C-U> call <SID>deleteItemUnderCursor()<CR>
xnoremap <buffer> <Plug>(dovish_delete_selection) :<C-U> call <SID>deleteSelectedItems()<CR>
nnoremap <silent><buffer> <Plug>(dovish_yank) :<C-U> call <SID>copyFilePathUnderCursor()<CR>
xnoremap <silent><buffer> <Plug>(dovish_yank) :<C-U> call <SID>copyVisualSelection()<CR>
nnoremap <silent><buffer> <Plug>(dovish_copy) :<C-U> call <SID>copyYankedItemToCurrentDirectory()<CR>
nnoremap <silent><buffer> <Plug>(dovish_move) :<C-U> call <SID>moveYankedItemToCurrentDirectory()<CR>

if !exists("g:dirvish_dovish_map_keys")
  let g:dirvish_dovish_map_keys = 1
endif

if g:dirvish_dovish_map_keys
  " if !hasmapto('<Plug>(dovish_create_file)', 'n')
  "   execute 'nmap <silent><buffer> a <Plug>(dovish_create_file)'
  " endif
  " if !hasmapto('<Plug>(dovish_create_directory)', 'n')
  "   execute 'nmap <silent><buffer> A <Plug>(dovish_create_directory)'
  " endif
  if !hasmapto('<Plug>(dovish_delete)', 'n')
    execute 'nmap <silent><buffer> dd <Plug>(dovish_delete)'
  endif
  if !hasmapto('<Plug>(dovish_delete_selection)', 'n')
    execute 'xmap <silent><buffer> dd <Plug>(dovish_delete_selection)'
  endif
  if !hasmapto('<Plug>(dovish_rename)', 'n')
    execute 'nmap <silent><buffer> cw <Plug>(dovish_rename)'
  endif
  if !hasmapto('<Plug>(dovish_yank)', 'n')
    execute 'nmap <silent><buffer> yy <Plug>(dovish_yank)'
  endif
  if !hasmapto('<Plug>(dovish_yank)', 'v')
    execute 'xmap <silent><buffer> yy <Plug>(dovish_yank)'
  endif
  if !hasmapto('<Plug>(dovish_copy)', 'n')
    execute 'nmap <silent><buffer> pp <Plug>(dovish_copy)'
  endif
  if !hasmapto('<Plug>(dovish_move)', 'n')
    execute 'nmap <silent><buffer> PP <Plug>(dovish_move)'
  endif
endif
