" We define the root directory as the one that contains the git folder
function! s:find_root()
  if globpath('.', '.git') ==# './.git'
    let l:gitdir = getcwd()
    " Return working directory to the original value
    execute 'cd' fnameescape(b:file_path)
    return l:gitdir
  elseif getcwd() ==# '/'
    execute 'cd' fnameescape(b:file_path)
    return 'Reached filesystem boundary'
  else
    execute 'cd' fnameescape('..')
    return s:find_root()
  endif
endfunction

" Find local environmental configuration and overwrite the system-wide
" configuration, if any
function! s:source_local_configuration()
  if filereadable('./.axe.vim')
    execute 'source .axe.vim'
  else
    let l:root = s:find_root()
    if filereadable(l:root . '/.axe.vim')
      execute 'source ' . l:root . '/.axe.vim'
    endif
  endif
endfunction

function! s:new_split()
  let l:split_directions = {
        \ 'up': 'topleft split',
        \ 'down':  'botright split',
        \ 'right': 'botright vsplit',
        \ 'left': 'topleft vsplit',
        \ }
  if has_key(l:split_directions, g:axe#split_direction)
    " ' Execute' creates a new buffer for the execution to take place,
    " otherwise the current buffer will be replaced by the terminal
    execute l:split_directions[g:axe#split_direction] . ' Execute'
    if g:axe#split_direction ==# 'up' || g:axe#split_direction ==# 'down'
      execute 'resize ' . g:axe#term_height
    elseif g:axe#split_direction ==# 'left' || g:axe#split_direction ==# 'right'
      execute 'vertical resize ' . g:axe#term_width
    endif
  endif

  setlocal nonumber
  setlocal nospell
endfunction

function! s:name_buffer(filename, with_filename)
    let l:bufnr = 0
    let l:bufname = a:with_filename ? 'Axe: ' . a:filename : 'Axe'

    while bufname(l:bufname) ==# l:bufname
      let l:bufnr = l:bufnr + 1
      if a:with_filename
        let l:bufname = 'Axe: ' . a:filename . ' (' . l:bufnr . ')'
      else
        let l:bufname = 'Axe (' . l:bufnr . ')'
      endif
    endwhile

    execute "file " . l:bufname
endfunction

function! s:job_stdout(job_id, data, event) dict
  let l:self.stdout = l:self.stdout + a:data
endfunction

function! s:job_stderr(job_id, data, event) dict
  let l:self.stderr = l:self.stderr + a:data
endfunction

function! s:term_job_exit(job_id, data, event) dict
  let l:bufnr = g:axe#terminal_jobs[a:job_id][1]
  unlet g:axe#terminal_jobs[a:job_id]
  if g:axe#remove_term_buffer_when_done
    execute 'bd! ' . l:bufnr
  else
    close
  endif
endfunction

function! s:bg_job_exit(job_id, data, event) dict
  unlet g:axe#background_jobs[a:job_id]
endfunction

function! s:new_job(term)
  let exit_func = a:term ? 's:term_job_exit' : 's:bg_job_exit'
  return {
        \ 'stdout': [],
        \ 'stderr': [],
        \ 'on_stdout': function('s:job_stdout'),
        \ 'on_stderr': function('s:job_stderr'),
        \ 'on_exit': function(exit_func)
        \ }
endfunction

function! s:create_term_cmd(cmd)
  let l:subcmd = a:cmd . ';'
  " This is basically a shell script.
  "   trap : INT catches Ctrl-C and enables to the command to exit gracefully
  let l:cmd = '/bin/bash -c "' .
        \ 'trap : INT;' .
        \ l:subcmd .
        \ 'printf \"' . g:axe#exit_message . '\"' .
        \ ';read -p \"\""'
  return l:cmd
endfunction

function! s:extract_cmd_opt(filetype, subcmd)
  " file type specific commands trump catch-all commands
  if has_key(g:axe#cmds, a:filetype) && has_key(g:axe#cmds, '*')
    let l:extcmds = extend(deepcopy(g:axe#cmds['*']),
                           g:axe#cmds[l:filetype])
  elseif has_key(g:axe#cmds, a:filetype)
    let l:extcmds = g:axe#cmds[a:filetype]
  elseif has_key(g:axe#cmds, '*')
    let l:extcmds = g:axe#cmds['*']
  else
    let l:extcmds = {}
  endif

  if has_key(l:extcmds, a:subcmd)
    let l:cmdstr = l:extcmds[a:subcmd]['cmd']
    let l:with_filename = l:extcmds[a:subcmd]['with_filename']
    let l:in_term = l:extcmds[a:subcmd]['in_term']
  endif

  return [l:cmdstr, l:with_filename, l:in_term]
endfunction

function! axe#call(subcmd)
  let b:file_path = getcwd()
  let l:filename = expand('%:f')
  let l:filetype = &filetype

  call s:source_local_configuration()

  try
    let l:cmd_opts = s:extract_cmd_opt(l:filetype, a:subcmd)
    let l:cmdstr = l:cmd_opts[0]
    let l:with_filename = l:cmd_opts[1]
    let l:in_term = l:cmd_opts[2]

    let l:cmd = l:with_filename ? l:cmdstr . ' ' . l:filename : l:cmdstr
    let l:cmd = l:in_term ? s:create_term_cmd(l:cmd) : l:cmd

    let l:job = s:new_job(l:in_term)
    if l:in_term
      call s:new_split()
      let l:job_id = termopen(l:cmd, l:job)
      call s:name_buffer(l:filename, l:with_filename)
      let l:bufnr = bufnr('%')
      let g:axe#terminal_jobs[l:job_id] = [l:job, l:bufnr]
    else
      let l:job_id = jobstart(l:cmd, l:job)
      let g:axe#background_jobs[l:job_id] = [a:subcmd, l:job]
    endif
  catch /l:cmdstr/
    echohl ErrorMsg
    echom 'Command not defined.'
    echohl NONE
  endtry
endfunction

" returns a list of defined commands
function! s:list_commands()
  let l:filetype = &filetype
  if has_key(g:axe#cmds, l:filetype) && has_key(g:axe#cmds, '*')
    let l:cmd_dicts = extend(deepcopy(g:axe#cmds['*']),
                             g:axe#cmds[l:filetype])
    let l:cmd = keys(l:cmd_dicts)
  elseif has_key(g:axe#cmds, l:filetype)
    let l:cmds = keys(g:axe#cmds[l:filetype])
  elseif has_key(g:axe#cmds, '*')
    let l:cmds = keys(g:axe#cmds['*'])
  else
    let l:cmds = []
  endif
  return l:cmds
endfunction

" List all currently defined commands for this file type
function! axe#list_commands()
  echom ':ExtCmdListCmds'
  for cmd in s:list_commands()
    echom '  ' . cmd
  endfor
endfunction

" completion function for Axe
function! axe#complete_commands(ArgLead, CmdLine, CursorPos)
  return join(s:list_commands(), "\n")
endfunction

" TODO: Make output adapt to job-id length
function! axe#list_background_processes()
  if g:axe#background_jobs !=# {}
    echom ':ExtCmdListProcs'
    echom '  #   Command'
    for l:proc in items(g:axe#background_jobs)
      let l:job_id = l:proc[0]
      let l:cmd = l:proc[1][0]
      echom '  ' . l:job_id . '   ' . l:cmd
    endfor
  else
    echom 'Nothing to show'
  endif
endfunction

function! axe#stop_process(job_id)
  if has_key(g:axe#background_jobs, a:job_id)
    call jobstop(str2nr(a:job_id))
  else
    echom 'No matching process found'
  endif
endfunction