
## Running

```sh
odin run src -define:RAYLIB_SHARED=true
```

## Issues

Odin compiler may use regular C installation of raylib, so in order to fix that
change _LD_LIBRARY_ in your *.bashrc* or *.zshrc*

from this:

```
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/opt/Odin/vendor/raylib/linux
```

to this:

```
export LD_LIBRARY_PATH="/opt/Odin/vendor/raylib/linux:$LD_LIBRARY_PATH:/usr/local/lib"
```
