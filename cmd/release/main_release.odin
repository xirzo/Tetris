package main

import "core:mem/virtual"
import "core:log"
import pl "game:plug"
import rl "vendor:raylib"

main :: proc() {
    arena: virtual.Arena
    arena_err := virtual.arena_init_growing(&arena)
    ensure(arena_err == nil)
    arena_alloc := virtual.arena_allocator(&arena)

    context.allocator = arena_alloc
    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

	rl.SetTraceLogLevel(rl.TraceLogLevel.INFO)
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})

	rl.InitWindow(1920 / 2, 1080 / 2, "Tetris")

	rl.InitAudioDevice()

	state: rawptr = nil

	pl.game_init(&state, context)

	for !rl.WindowShouldClose() {
		pl.game_update(state, context)
		pl.game_draw(state, context)
	}

	pl.game_shutdown(&state, context)
    free(state)
	rl.CloseAudioDevice()
	rl.CloseWindow()
}
