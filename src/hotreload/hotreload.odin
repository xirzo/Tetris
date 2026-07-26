package hotreload

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:strings"

OUTPUT_FILE_PATH :: "plug.so"

Plug :: struct {
	init:   proc(),
	update: proc(),
	draw:   proc(),
	deinit: proc(),
	handle: dynlib.Library,
}

plug_load :: proc(plug: ^Plug, plug_source_file_path: string = "plug.odin") ->
bool {
	if !plug_build(plug_source_file_path, OUTPUT_FILE_PATH) do return false

	count, ok := dynlib.initialize_symbols(plug, OUTPUT_FILE_PATH, handle_field_name = "handle")
	if !ok {
		fmt.eprintfln("failed to load the plug, error: %v", dynlib.last_error())
		return false
	}

	fmt.printfln("successfully loaded the plug, elements count: %i", count)
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
		fmt.eprintfln("failed to unload the plug, error: %v", dynlib.last_error())
	}

	plug.handle = nil
	plug.init = nil
	plug.update = nil
	plug.draw = nil
	plug.deinit = nil
}

@(private = "file")
plug_build :: proc(plug_source_file_path: string, output_file_path: string) -> bool {
	out_argument, alloc_err := strings.concatenate([]string{"-out:", output_file_path})
	if alloc_err != runtime.Allocator_Error.None {
		fmt.eprintfln("failed to allocate out argument, error: %v", alloc_err)
		return false
	}
	defer delete(out_argument)

	state, stdout, stderr, _ := os.process_exec(
		os.Process_Desc {
			command = {
				"odin",
				"build",
				plug_source_file_path,
				"-file",
				"-build-mode:shared",
				out_argument,
			},
		},
		context.temp_allocator,
	)

	if state.exit_code != 0 {
		fmt.eprintfln("failed to build the plug, error code: %i", state.exit_code)
		return false
	}

	return true
}
