# The Uni Games

The first and only "Unicycle Games" games for the Commodore 64 compatible with Uni-Joysti-Cle.

## Preview Version

![Title Screen](https://lh3.googleusercontent.com/-lS8RLTwCrjg/VwLiawqXoHI/AAAAAAABdoU/VhVqIy8xSkglfyyL45PODNooTTixcZ1mgCCo/s288-Ic42/Screen%2BShot%2B2016-04-04%2Bat%2B2.38.14%2BPM.png)
![Riding](https://lh3.googleusercontent.com/-0AO3EXGssnE/VwLia951ibI/AAAAAAABdoc/WckCySb2-0oFOKJgvXXGUnmBJ0es2lMwACCo/s288-Ic42/Screen%2BShot%2B2016-04-04%2Bat%2B2.39.10%2BPM.png)
![High Scores](https://lh3.googleusercontent.com/-UQPThcDYF6w/VwLia-4tEaI/AAAAAAABdoY/I7FzbnVJTc4SdXxMbJIMrI5aa8KZwiUBgCCo/s288-Ic42/Screen%2BShot%2B2016-04-04%2Bat%2B2.40.39%2BPM.png)

However, if you want to see the progress of the game, feel free to clone it, report bugs, submit pull requests, etc.

## Download

Download preview version from here: [unigames.prg](https://github.com/ricardoquesada/c64-the-uni-games/raw/master/bin/unigames.prg)

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
