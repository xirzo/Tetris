package main

import pl "plug"
import rl "vendor:raylib"

main :: proc() {
	rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
	rl.SetConfigFlags({.WINDOW_RESIZABLE})

	rl.InitWindow(1920 / 2, 1080 / 2, "Tetris")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	state: rawptr = nil

	pl.game_init(&state, context)

	for !rl.WindowShouldClose() {
		pl.game_update(state, context)
		pl.game_draw(state, context)
	}

    pl.game_shutdown(&state, context)
}
