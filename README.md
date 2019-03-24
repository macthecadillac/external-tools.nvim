# External-tools

A configurable plugin to run external commands in the built-in terminal based on
file type.

## Requirements

Neovim >= 0.2

## Installation

[vim-plug](https://github.com/junegunn/vim-plug)

Add the following line to your `init.vim`

```vim
Plug 'macthecadillac/external-tools.nvim'
```

## Features

- Command structure
  - [ ] Default command
  - [x] Composite commands
  - [x] File type based commands
  - [x] Non file type based commands
  - [x] Terminal based commands
  - [x] Background commands

- File type based commands
  - [ ] Open documentation from the file type command (if the language supports
    offline reading of such)

- Other TODOs
  - [ ] Terminate non-terminal based commands
  - [ ] Process manager

## Usage

Set up hooks for different file types (see below). The command `ExtCmd cmd` will
execute the external command associated with `cmd`.

## Configuration

### Global configuration options

By far, the most important configuration option is the `g:external_tools#cmds`
option. This sets up hooks for each file type to external commands.
`g:external_tools#cmds` is a dictionary. The keys are the file types that neovim
recognizes, and their associated values are dictionaries that associate file
type specific commands with a dictionary with the following entries:

- `cmd`: string. The command to be invoked
- `with_filename`: 1 or 0. Whether to invoke the command with the file name.
- `in_term`: 1 or 0. To execute the command in the built-in terminal or in the
  background.

Instead of defining file type specific commands, you can also define commands
for any file type by using `'*'` as the file type.


Example:

```vim
let g:external_tools#cmds = {
      \ '*': {
      \     'update-ctags': 'ctags -R -h --exclude={.git,__pycache,__init__.py}', 'with_filename': 0, 'in_term': 0},
      \   },
      \ 'python': {
      \     'run': {'cmd': '$HOME/anaconda3/bin/python', 'with_filename': 1, 'in_term': 1},
      \     'backgroun-run': {'cmd': 'python3', 'with_filename': 1, 'in_term': 0},
      \   },
      \ 'tex': {
      \     'compile': {'cmd': 'latexmk -gg -silent', 'with_filename': 1, 'in_term': 1},
      \   },
      \ 'rust': {
      \     'build': {'cmd': 'cargo build', 'with_filename': 0, 'in_term': 1},
      \   },
      \ }
```

Additional options should be quite self-explanatory. Shown here are their
default values.

```vim
" Available directions are 'up', 'down', 'left' and 'right'.
let g:external_tools#split_direction = 'down'
let g:external_tools#exit_message = '\n-------------------------\nPress ENTER to exit'
let g:external_tools#term_height = 15
let g:external_tools#term_width = 79
let g:external_tools#remove_term_buffer_when_done = 1
```

### Local Configurations

Local configuration lets you tailor the behavior of the extension to specific
projects. The configuration works the same way it does for global
configurations, except that the configurations reside in `.external_tools.vim`
in the local directory or the root of your git project. External-tools will pick
up your local configurations and override the global settings (if any) with
them.

## License

MIT
