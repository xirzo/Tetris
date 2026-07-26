package main

import "core:fmt"
import "core:os"
import "core:time"
import h "hotreload"

PLUG_SOURCE_PATH :: "plug.odin"

main :: proc() {
	plug: h.Plug

	if !h.plug_load(&plug, PLUG_SOURCE_PATH) do os.exit(1)
	defer h.plug_unload(&plug)

	plug.init()

	last_write_time, err := os.last_write_time_by_name(PLUG_SOURCE_PATH)
	if err != os.ERROR_NONE {
		fmt.eprintfln("[main] [warn] could not get initial write time: %v", err)
	}

	fmt.println("[main] starting main loop. edit plug.odin to trigger a reload...")

	for {
		current_write_time, check_err := os.last_write_time_by_name(PLUG_SOURCE_PATH)

		if check_err == os.ERROR_NONE && time.diff(last_write_time, current_write_time) > 0 {
			fmt.println("\n[main] changes detected! recompiling...")

			plug.deinit()

			if !h.plug_reload(&plug, PLUG_SOURCE_PATH) do os.exit(1)

			plug.init()

			last_write_time = current_write_time
		}

		plug.update()

		plug.draw()

		time.sleep(time.Millisecond * 16)
	}
}
