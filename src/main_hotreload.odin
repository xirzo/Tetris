package main

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

OUTPUT_FILE_PATH :: "plug.so"
FUNCTIONS_PREFIX :: "game_"
PLUG_SOURCE_PATH :: "src/plug/plug.odin"

main :: proc() {
	plug: Plug
	state: rawptr = nil

	if !plug_load(&plug, PLUG_SOURCE_PATH) do os.exit(1)
	defer plug_unload(&plug)

	rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1920 / 2, 1080 / 2, "Tetris")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

	plug.init(&state, context)

	defer {
		plug.shutdown(&state, context)
		if state != nil {
			fmt.println("[main] freeing game memory...")
			free(state)
		}
	}

	// last_write_time, err := os.last_write_time_by_name(PLUG_SOURCE_PATH)
	// if err != os.ERROR_NONE {
	// 	fmt.eprintfln("[main] [warn] could not get initial write time: %v", err)
	// }

	// fmt.println("[main] starting main loop. edit plug.odin to trigger a reload...")

	for !rl.WindowShouldClose() {
		// current_write_time, check_err := os.last_write_time_by_name(PLUG_SOURCE_PATH)
		// if check_err == os.ERROR_NONE && time.diff(last_write_time,
		// current_write_time) > 0|| rl.IsKeyPressed(rl.KeyboardKey.SPACE) {

		if rl.IsKeyPressed(rl.KeyboardKey.G) {
			fmt.println("[main] changes detected! recompiling...")

			plug.deinit(&state, context)

			if !plug_reload(&plug, PLUG_SOURCE_PATH) do os.exit(1)

			plug.init(&state, context)

			// last_write_time = current_write_time
		}

		plug.update(state, context)

		plug.draw(state, context)
	}
}

Plug :: struct {
	init:     proc(state: ^rawptr, ctx: runtime.Context),
	update:   proc(state: rawptr, ctx: runtime.Context),
	draw:     proc(state: rawptr, ctx: runtime.Context),
	deinit:   proc(state: ^rawptr, ctx: runtime.Context),
	shutdown: proc(state: ^rawptr, ctx: runtime.Context),
	handle:   dynlib.Library,
}

plug_load :: proc(plug: ^Plug, plug_source_file_path: string = "plug.odin") -> bool {
	if !plug_build(plug_source_file_path, OUTPUT_FILE_PATH) do return false

	count, ok := dynlib.initialize_symbols(
		plug,
		OUTPUT_FILE_PATH,
		handle_field_name = "handle",
		symbol_prefix = FUNCTIONS_PREFIX,
	)
	if !ok {
		fmt.eprintfln("failed to load the plug, error: %v", dynlib.last_error())
		return false
	}

	fmt.printfln("[hotreload] successfully loaded the plug, elements count: %i", count)
	return true
}


plug_reload :: proc(plug: ^Plug, plug_source_file_path: string = "plug.odin") -> bool {
	if !plug_build(plug_source_file_path, OUTPUT_FILE_PATH) {
		return false
	}

	plug_unload(plug)

	return plug_load(plug, plug_source_file_path)
}

plug_unload :: proc(plug: ^Plug) {
	if plug.handle == nil {
		return
	}

	if !dynlib.unload_library(plug.handle) {
		fmt.eprintfln("[hotreload] failed to unload the plug, error: %v", dynlib.last_error())
	}

	plug.handle = nil
	plug.init = nil
	plug.update = nil
	plug.draw = nil
	plug.deinit = nil
	plug.shutdown = nil
}

@(private = "file")
plug_build :: proc(plug_source_file_path: string, output_file_path: string) -> bool {
	out_argument, alloc_err := strings.concatenate([]string{"-out:", output_file_path})
	if alloc_err != runtime.Allocator_Error.None {
		fmt.eprintfln("[hotreload] failed to allocate out argument, error: %v", alloc_err)
		return false
	}
	defer delete(out_argument)

	state, stdout, stderr, _ := os.process_exec(
		os.Process_Desc {
			command = {
				"odin",
				"build",
				plug_source_file_path,
				"-define:RAYLIB_SHARED=true",
				"-define:DEBUG_BUILD=true",
				"-file",
				"-build-mode:shared",
				out_argument,
			},
		},
		context.temp_allocator,
	)

	if state.exit_code != 0 {
		fmt.eprintfln("[hotreload] failed to build the plug, error code: %i", state.exit_code)
		fmt.eprintfln("%s", stderr)
		return false
	}

	return true
}
