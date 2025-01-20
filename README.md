# localpkg - A barebones package installer for ~/.local on macOS

localpkg is a trivial package installer written in zsh for macOS. It is primarily intended to install packages directly
from .tar.gz archives fetched from GitHub Releases or other sources.

## WORK IN PROGRESS

This repository exists to enable early development of the localpkg tool. It is not yet ready for general use.

## Why?

A basic development environment can now be set up on macOS with a handful of tools:

- git - typically installed with XCode
- Visual Studio Code - downloadable from the website
- docker - either through Docker Desktop or another implementation
- gh - GitHub CLI (or the CLI for your preferred git host)

Once these items are installed, the rest of the development environment can live in dev containers. However, these few
tools must be on the macOS host system. Of these, git and gh both require XCode (at least the Command Line Tools) to be
installed for standard installation. Docker Desktop is also a large download and has licensing restrictions. Visual Studio,
on the other hand, is a standard macOS application that can be installed by dragging it to the Applications folder.

The goal of localpkg is to allow a developer to get a working development environment up and running, even without
admin rights, and without preinstalled tools. As such, it is not designed to be a general-purpose package manager, but
rather a way to install a few key tools that are not easily installed otherwise. localpkg also helps set up the 
shell environment for a developer, including setting up the PATH and other environment variables.

localpkg packages are installed by running a zsh script, a normal instruction might look like this:

```
curl -sL https://github.com/username/repo/releases/latest/download/install.zsh | zsh
```

The install.zsh script is generated by appending the localpkg "library" to a script written by the package author. The
author's script defines variables which are used by the library to drive the installation process. A script might look
like this:

```zsh
# This is the package script
# It defines variables that are used by the localpkg library
lp_gh_repo="username/repo"
lp_version="1.0.0" # Optional
lp_pkgfile_pattern="myapp-macOS-${HOSTTYPE}.tar.gz"
lp_tar_args=( "--strip-components=1" )
```
