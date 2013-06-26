**qlist** lists content of a package with filtering ability, such as: manual pages, documentation, info pages, binary files etc.
The program inspired by qlist from app-portage/portage-utils from Gentoo OS.

## Usage

qlist [options] package [pattern to search]

## Options

Built-in filters:

* **-b** - lists binary files
* **-m** - lists manual pages, matching to 'man/'
* **-d** - lists documentations, matching to 'doc/'
* **-i** - lists info pages, matching to 'info/'
* **-l** - lists locales, matching to 'locale/'
* **-p** - lists files ending on: .png, .xpm, .svg, .icons, .jpg and matching to 'picture'
* **-o** - lists files which doesn't match to above

### Others options

* **-g** - like as grep
* **--no-color** - switch off color
* **--all** - doesn't omit empty directories
* **-h** - print help

## License and copyright

The program is distributed as-is.
