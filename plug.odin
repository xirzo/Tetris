package plug

import "base:runtime"
import "core:fmt"
import rl "vendor:raylib"

IMAGE_SPRIDE_SIDE :: 8
IMAGE_SPRITE_SCALE :: 32

ATLAS_TEXTURE_PATH :: "assets/atlas.png"

WALL_TEXTURE_OFFSET :: rl.Vector2{0, 0}
WALL_ALT_TEXTURE_OFFSET :: rl.Vector2{8, 0}

Game_State :: struct {
	atlas: rl.Texture,
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

	atlas := rl.LoadTexture(ATLAS_TEXTURE_PATH)
	if atlas.id <= 0 {
		fmt.eprintln("[plug] failed to load atlas texture")
		return
	}

	tmp.atlas = atlas
	tmp.score = 0

	state^ = tmp
	fmt.println("[plug] allocated game_state")
}

@(export)
game_update :: proc(state: rawptr, ctx: runtime.Context) {
	context = ctx
	game_state := cast(^Game_State)state
}

@(export)
game_draw :: proc(state: rawptr, ctx: runtime.Context) {
	context = ctx
	game_state := cast(^Game_State)state

	rl.ClearBackground(rl.BLACK)
	draw_atlas_texture(game_state, WALL_TEXTURE_OFFSET, rl.Vector2{50, 50})
	draw_atlas_texture(game_state, WALL_ALT_TEXTURE_OFFSET, rl.Vector2{100, 50})
}

@(export)
game_deinit :: proc(state: ^rawptr, ctx: runtime.Context) {
	context = ctx
	game_state := cast(^Game_State)(state^)

	fmt.println("[plug] deinit")
}

@(export)
game_shutdown :: proc(state: ^rawptr, ctx: runtime.Context) {
	context = ctx
	if state^ == nil {
		fmt.println("[plug] state is already null, while shutting down, skipping...")
		return
	}

	game_state := cast(^Game_State)(state^)

	rl.UnloadTexture(game_state.atlas)

	fmt.println("[plug] full shutdown complete")
}


draw_atlas_texture :: proc(
	game_state: ^Game_State,
	texture_offset: rl.Vector2,
	position: rl.Vector2,
) {
	dest := rl.Rectangle{position.x, position.y, IMAGE_SPRITE_SCALE, IMAGE_SPRITE_SCALE}

	rl.DrawTexturePro(
		game_state.atlas,
		rl.Rectangle{texture_offset.x, texture_offset.y, IMAGE_SPRIDE_SIDE, IMAGE_SPRIDE_SIDE},
		dest,
		rl.Vector2{0, 0},
		0,
		rl.WHITE,
	)
}
