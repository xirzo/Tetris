# Tetris

<div align="center">
  <img width="800" height="450" alt="gif" src="https://github.com/user-attachments/assets/654c38ff-6cdc-4d79-b068-4df817010111" />
</div>

## Running

### Development

```sh
odin run src/main_hotreload.odin -file -define:RAYLIB_SHARED=true
```

### Release

```sh
odin run src/main_release.odin -file
```

## Building

### Release

```sh
odin build src/main_release.odin -file -out:x86_64_linux_tetris -o:speed
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
