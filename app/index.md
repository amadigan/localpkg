# localpkg - a CLI tool for managing packages in ~/.local/bin

# commands used directly by localpkg
- zsh
- bsdtar

# built-in packages
In addition to preloaded aliases, several packages are built into localpkg. These are installed by referencing their names as aliases. Note that loaded aliases will override built-in packages.

- localpkg - installs localpkg itself from the current script, updates from GitHub
- code - installs Visual Studio Code to ~/Applications and creates a symlink in ~/.local/bin
- code-link - creates a symlink to Visual Studio Code in ~/.local/bin
- go - installs the Go programming language