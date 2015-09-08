# The Muni Race

A Mountain Unicycle (Muni) Racing game for the Commodore 64!

## WIP

This is still Work In Progress. There is no playable game yet.
However, if you want to see the progress of the game, feel free to clone it, report bugs, submit pull requests, etc.

## How to compile it

- Install [cc65](http://cc65.github.io/cc65/) and put it in the path. Requires cc65 v2.15 or newer (Don't install it from brew)
- Install [Vice](http://vice-emu.sourceforge.net/) and make sure `c1541` and `x64` are in the path. On Mac do: `$ brew install vice`
- Optional: Install [exomizer](http://hem.bredband.net/magli143/exo/) to generate compressed .prg files (`$ make dist`)
- Clone this project and `make test`:

```
$ git clone https://github.com/ricardoquesada/c64-the-muni-race.git
$ cd c64-the-muni-race
$ make test
```
