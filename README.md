# The Uni Games

The first and only "Unicycle Games" games for the Commodore 64 compatible with UniJoystiCle™.

## Version v0.2.4

![Title Screen](https://lh3.googleusercontent.com/-yQCSKtv_UFQ/V5ZT_h0yFAI/AAAAAAABe24/0kqLpZXgRVcHFsCEGYktsQwUe3q4E5JhACCo/s800/capture1.png)
![RoadRace](https://lh3.googleusercontent.com/-8hNjbAZFeQQ/V5ZT_lzJWEI/AAAAAAABe28/Vi5UdHVHvscV4jwW92_ne154eXWHQcatgCCo/s800/capture2.png)
![CycloCross](https://lh3.googleusercontent.com/-ce3uigCabI8/V5ZT_odzEcI/AAAAAAABe20/TXyhvXMrqZQb110Lb9xY76Ff5k1WFqHVwCCo/s800/capture3.png)
![CrossCountry](https://lh3.googleusercontent.com/-qYOFLfHu_Ac/V5ZU1lnd5-I/AAAAAAABe3A/LBW-xfCv_30HZhN5hlLnk1pRhRgafaBFQCCo/s800/capture5.png)

The game is not finished yet. However, if you want to see the progress of the game, feel free to clone it, report bugs, submit pull requests, etc.

## How to play it

Best if played with a [UniJoystiCle™](https://retro.moe/unijoysticle).
If you don't have one, go and get one. In the meantime you can try it with a regular joystick.

There are three events:

* Road Race:
   * Joystick: Left + Right to speed
   * UniJoystiCle: Idle or pedal to speed
* Cyclo Cross
   * Joystick: Fire to jump
   * UniJoystiCle: Hop to jump
* Cross Country:
   * Joystick: Left + Right to speed; fire to jump
   * UniJoystiCle: Idle or pedal to speed; hop to jump

Try to beat the computer in all three events. Or play face-to-face with a friend.

## Download

Download latest version from here: [unigames.d64](https://github.com/ricardoquesada/c64-the-uni-games/raw/master/bin/unigames.d64)

## How to compile it

- Install [cc65](http://cc65.github.io/cc65/) and put it in the path. Requires cc65 v2.15 or newer (Don't install it using `brew` since it is an old version)
- Install [Vice](http://vice-emu.sourceforge.net/) and make sure `c1541` and `x64` are in the path.
    - On Mac: `$ brew install vice`
    - On Linux: `$ apt-get install vice` and follow [these instructions](http://iseborn.eu/wiki/index.php?title=Ubuntu/Install_and_set_up_VICE)
- Install [exomizer](http://hem.bredband.net/magli143/exo/) to generate compressed .prg files.
- Clone this project and `make bin`:

```
$ git clone https://github.com/ricardoquesada/c64-the-uni-games.git
$ cd c64-uni-games
$ make bin
```

## License

(c) 2015, 2016 Ricardo Quesada
[Apache License v2.0](LICENSE)
