# The Uni Games

The first and only "Unicycle Games" games for the Commodore 64 compatible with Uni-Joysti-Cle™.

## Version v0.2.4

![Title Screen](https://lh3.googleusercontent.com/-iIjET-7cb9M/V4BFVkcc5WI/AAAAAAABexI/tiyfWHQSNlAIULfSHkY7qe_09n3qgJ7xwCCo/s288/capture2.png)
![Riding](https://lh3.googleusercontent.com/-2aUt6XxtEAU/V4BFVmPdHMI/AAAAAAABexE/zj73EICjTpk27gcDmljJfO6nXWSlWawDgCCo/s288/capture4.png)
![About](https://lh3.googleusercontent.com/-SbLrO1sAhWM/V4BFVvCHjYI/AAAAAAABexA/iloekpcOv5ohmgoRzsXHDbFYnpvAmXMcQCCo/s288/capture3.png)

The game is far from finished. __IT IS NOT IN A PLAYABLE STATE__.
However, if you want to see the progress of the game, feel free to clone it, report bugs, submit pull requests, etc.

## How to play it

Best if used with the [UniJoystiCle™](https://retro.moe/unijoysticle).
If you don't have one, go and get one. In the meantime you can try it with a Joystick in port 2.

## Download

Download version v0.2.4 from here: [unigames_exo.prg](https://github.com/ricardoquesada/c64-the-uni-games/raw/master/bin/unigames_exo.prg)

## How to compile it

- Install [cc65](http://cc65.github.io/cc65/) and put it in the path. Requires cc65 v2.15 or newer (Don't install it using `brew` since it is an old version)
- Install [Vice](http://vice-emu.sourceforge.net/) and make sure `c1541` and `x64` are in the path.
    - On Mac: `$ brew install vice`
    - On Linux: `$ apt-get install vice` and follow [these instructions](http://iseborn.eu/wiki/index.php?title=Ubuntu/Install_and_set_up_VICE)
- Optional: Install [exomizer](http://hem.bredband.net/magli143/exo/) to generate compressed .prg files. Only useful for `$ make dist`
- Clone this project and `make test`:

```
$ git clone https://github.com/ricardoquesada/c64-the-uni-games.git
$ cd c64-uni-games
$ make test
```
