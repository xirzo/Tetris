package plug

import "base:runtime"
import "core:fmt"
import rl "vendor:raylib"

Game_State :: struct {
	score: int,
}

@(export)
game_init :: proc(state: ^rawptr, ctx: runtime.Context) {
	context = ctx
	fmt.println("[plug] init")

	if state^ != nil {
		fmt.println("[plug] memory already allocated, skipping...")
		return
	}

	tmp := new(Game_State)

	tmp.score = 69

	state^ = tmp
	fmt.println("[plug] allocated game_state")
}

@(export)
game_update :: proc(state: rawptr, ctx: runtime.Context) {
	context = ctx
	game_state := cast(^Game_State)state

	fmt.println(game_state.score)
}

@(export)
game_draw :: proc(state: rawptr, ctx: runtime.Context) {
	context = ctx
	game_state := cast(^Game_State)state

	rl.ClearBackground(rl.WHITE)
}

@(export)
game_deinit :: proc(state: ^rawptr, ctx: runtime.Context) {
	context = ctx

    game_state := cast(^Game_State)(state^)

    game_state.score -= 1;

	fmt.println("[plug] deinit")
}

@(export)
game_shutdown :: proc(state: ^rawptr, ctx: runtime.Context) {
	context = ctx

	if state^ == nil {
		fmt.println("[plug] state is already null, while shutting down, skipping...")
		return
	}

    // NOTE: all of the arrays, UnloadTexture, etc... go here

	fmt.println("[plug] full shutdown complete")
}
