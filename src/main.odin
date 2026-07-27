package main

import "core:fmt"
import "core:os"
import "core:time"
import h "hotreload"
import rl "vendor:raylib"

PLUG_SOURCE_PATH :: "plug.odin"

main :: proc() {
	plug: h.Plug
	state: rawptr = nil

	if !h.plug_load(&plug, PLUG_SOURCE_PATH) do os.exit(1)
	defer h.plug_unload(&plug)

    rl.SetTraceLogLevel(rl.TraceLogLevel.ERROR)
    rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1920/2, 1080/2, "Tetris")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	plug.init(&state, context)

	defer {
		plug.shutdown(&state, context)
		if state != nil {
			fmt.println("[main] freeing game memory...")
			free(state)
		}
	}

	last_write_time, err := os.last_write_time_by_name(PLUG_SOURCE_PATH)
	if err != os.ERROR_NONE {
		fmt.eprintfln("[main] [warn] could not get initial write time: %v", err)
	}

	fmt.println("[main] starting main loop. edit plug.odin to trigger a reload...")

	for !rl.WindowShouldClose() {
		current_write_time, check_err := os.last_write_time_by_name(PLUG_SOURCE_PATH)

		if check_err == os.ERROR_NONE && time.diff(last_write_time,
            current_write_time) > 0|| rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
			fmt.println("[main] changes detected! recompiling...")

			plug.deinit(&state, context)

			if !h.plug_reload(&plug, PLUG_SOURCE_PATH) do os.exit(1)

			plug.init(&state, context)

			last_write_time = current_write_time
		}

		plug.update(state, context)
		
		plug.draw(state, context)
	}
}
