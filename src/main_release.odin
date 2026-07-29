package main

import "core:log"
import pl "plug"
import rl "vendor:raylib"

main :: proc() {
    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

	rl.SetTraceLogLevel(rl.TraceLogLevel.INFO)
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})

	rl.InitWindow(1920 / 2, 1080 / 2, "Tetris")
	defer rl.CloseWindow()

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	state: rawptr = nil

	pl.game_init(&state, context)

	for !rl.WindowShouldClose() {
		pl.game_update(state, context)
		pl.game_draw(state, context)
	}

	pl.game_shutdown(&state, context)
    free(state)
}
