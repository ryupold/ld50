# LD #50 - Delay the inevitable

## Event Details
- Theme: **Delay the inevitable**
- Saturday April 2nd to Tuesday April 5th, 2022
Starts at 3:00 AM CEST *

You are a student in a class room. Today is exam day but you didn't learn at all. So you need to get the test answers by silently asking other students, read the notes of the teacher, etc. while he is patrolling the room.

Made with [zecsi](https://github.com/ryupold/zecsi).

---

## BUILD

### dependencies
- git
- [zig (0.9.1)](https://ziglang.org/documentation/0.9.1/)
- [emscripten sdk](https://emscripten.org/)

```
git clone --recurse-submodules https://github.com/ryupold/ld50
```

### run locally

```sh
zig build run
```

### build for host os and architecture

```sh
zig build -Drelease-small
```

The output files will be in `./zig-out/bin`

### html5 / emscripten

```sh
EMSDK=../emsdk #path to emscripten sdk

zig build -Drelease-small -Dtarget=wasm32-wasi --sysroot $EMSDK/upstream/emscripten/
```

The output files will be in `./zig-out/web/`

- game.html (entry point)
- game.js
- game.wasm
- game.data

The game data needs to be served with a webserver. Just opening the game.html in a browser won't work

You can utilize python as local http server:
```sh
python -m http.server
```