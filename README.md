**qlist** lists content of a package with filtering ability, such as: manual pages, documentation, info pages, binary files etc.
The program inspired by qlist from app-portage/portage-utils from Gentoo OS.

qlist was tested on Debian, Gentoo and ArchLinux.

## Usage

qlist [options] package [pattern to search]

## Options

Built-in filters:

* **-b|--bin**      - lists binary files
* **-m|--man**      - lists manual pages, matching to 'man/'
* **-d|--doc**      - lists documentations, matching to 'doc/'
* **-i|--info**     - lists info pages, matching to 'info/'
* **-l|--locale**   - lists locales, matching to 'locale/'
* **-p|--picture**  - lists files ending on: .png, .xpm, .svg, .icons, .jpg and matching to 'picture'
* **-o|--other**    - lists files which doesn't match to above

### Others options

* **-g** *pattern*  - like as grep
* **--all**         - doesn't omit empty directories
* **--case**        - do not ignore case letter
* **--all**         - print all files and directories belongs to the package
* **--os** *name*   - do not use Linux::Distribution to determine Operating System

### Rest options
* **-h|--help**             - print help
* **--no-color|--nocolor**  - switch off color

## License and copyright

The program is distributed as-is.
