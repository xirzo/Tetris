package plug

import "base:runtime"
import "core:fmt"
import rl "vendor:raylib"

IMAGE_SPRITE_SIDE :: 8
IMAGE_SPRITE_SCALE :: 32

ATLAS_TEXTURE_PATH :: "assets/atlas.png"

COLS_COUNT :: 10
ROWS_COUNT :: 20

BACKGROUND_COLOR :: rl.Color{ 34, 35, 35, 255 }

Cell :: enum {
	Wall,
	AltWall,
    Empty,
}

texture_offsets := [Cell]rl.Vector2 {
	.Wall    = rl.Vector2{0, 0},
	.AltWall = rl.Vector2{IMAGE_SPRITE_SIDE, 0},
    .Empty = rl.Vector2{IMAGE_SPRITE_SIDE * 2, 0}
}

Game_State :: struct {
	atlas: rl.Texture,
	score: int,
	cells: [COLS_COUNT][ROWS_COUNT]Cell,
}

@(export)
game_init :: proc(state: ^rawptr, ctx: runtime.Context) {
	context = ctx
	fmt.println("[plug] init")

	if state^ != nil {
		fmt.println("[plug] memory already allocated, skipping...")
		return
	}

	game_state := new(Game_State)

	atlas := rl.LoadTexture(ATLAS_TEXTURE_PATH)
	if atlas.id <= 0 {
		fmt.eprintln("[plug] failed to load atlas texture")
		return
	}

	game_state.atlas = atlas
	game_state.score = 0

	for x in 1 ..< COLS_COUNT - 1 {
		for y in 0 ..< ROWS_COUNT - 1 {
            game_state.cells[x][y] = Cell.Empty
		}
	}

	state^ = game_state
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

	rl.ClearBackground(BACKGROUND_COLOR)

	x_offset :: 50
	y_offset :: 50

	for x in 0 ..< COLS_COUNT {
		for y in 0 ..< ROWS_COUNT {

			draw_atlas_texture(
				game_state,
				texture_offsets[game_state.cells[x][y]],
				rl.Vector2 {
					x_offset + cast(f32)x * IMAGE_SPRITE_SCALE,
					y_offset + cast(f32)y * IMAGE_SPRITE_SCALE,
				},
			)
		}
	}
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
		rl.Rectangle{texture_offset.x, texture_offset.y, IMAGE_SPRITE_SIDE, IMAGE_SPRITE_SIDE},
		dest,
		rl.Vector2{0, 0},
		0,
		rl.WHITE,
	)
}
