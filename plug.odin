package plug

import "base:runtime"
import "core:fmt"
import rl "vendor:raylib"

IMAGE_SOURCE_SIZE :: 8
IMAGE_SPRITE_SCALE :: 4
IMAGE_DEST_SIZE :: IMAGE_SOURCE_SIZE * IMAGE_SPRITE_SCALE

ATLAS_TEXTURE_PATH :: "assets/atlas.png"
FONT_TEXTURE_PATH :: "assets/vcr_osd_mono.ttf"

COLS_COUNT :: 12
ROWS_COUNT :: 21

GAME_WIDTH :: 1920
GAME_HEIGHT :: 1080

BACKGROUND_COLOR :: rl.Color{34, 35, 35, 255}

DEBUG_BUILD :: true

texture_offsets := [Cell]rl.Vector2 {
	.Wall    = rl.Vector2{0, 0},
	.AltWall = rl.Vector2{IMAGE_SOURCE_SIZE, 0},
	.Empty   = rl.Vector2{IMAGE_SOURCE_SIZE * 2, 0},
}

Cell :: enum {
	Wall,
	AltWall,
	Empty,
}

Game_State :: struct {
	atlas:              rl.Texture,
	cells:              [COLS_COUNT][ROWS_COUNT]Cell,
	target_texture:     rl.RenderTexture,
	debug_font:         rl.Font,
	debug_font_size:    f32,
	debug_font_spacing: f32,
	font:               rl.Font,
	font_size:          f32,
	font_spacing:       f32,
	score:              i32,
	level:              i32,
	lines:              i32,
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
	game_state.target_texture = rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT)
	game_state.debug_font_size = 32
	game_state.debug_font_spacing = 2
	game_state.debug_font = rl.LoadFont(FONT_TEXTURE_PATH)

	game_state.font_size = 32
	game_state.font_spacing = 2
	game_state.font = rl.LoadFont(FONT_TEXTURE_PATH)

	game_state.score = 0
	game_state.level = 1
	game_state.lines = 0

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

	rl.BeginTextureMode(game_state.target_texture)
	rl.ClearBackground(BACKGROUND_COLOR)
	draw_grid(game_state)

	draw_game_info(game_state, rl.Vector2{GAME_WIDTH * 0.3, GAME_HEIGHT * 0.55})
	when DEBUG_BUILD do rl.DrawTextEx(
		game_state.debug_font,
		"DEVELOPMENT_BUILD",
		rl.Vector2{10, 10},
		game_state.debug_font_size,
		game_state.debug_font_spacing,
		rl.WHITE,
	)

	rl.EndTextureMode()

	rl.BeginDrawing()

	rl.ClearBackground(BACKGROUND_COLOR)

	screen_w := cast(f32)rl.GetScreenWidth()
	screen_h := cast(f32)rl.GetScreenHeight()
	game_w := cast(f32)GAME_WIDTH
	game_h := cast(f32)GAME_HEIGHT

	scale := min(screen_w / game_w, screen_h / game_h)

	dest_w := game_w * scale
	dest_h := game_h * scale
	offset_x := (screen_w - dest_w) * 0.5
	offset_y := (screen_h - dest_h) * 0.5

	source_rect := rl.Rectangle{0, 0, game_w, -game_h}
	dest_rect := rl.Rectangle{offset_x, offset_y, dest_w, dest_h}

	rl.DrawTexturePro(
		game_state.target_texture.texture,
		source_rect,
		dest_rect,
		{0, 0},
		0.0,
		rl.WHITE,
	)

	rl.EndDrawing()
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
	rl.UnloadRenderTexture(game_state.target_texture)
	rl.UnloadFont(game_state.debug_font)
	rl.UnloadFont(game_state.font)

	fmt.println("[plug] full shutdown complete")
}


draw_game_info :: proc(game_state: ^Game_State, position: rl.Vector2) {
	rl.DrawTextEx(
		game_state.font,
		rl.TextFormat("LINES\n    %i", game_state.lines),
		rl.Vector2{position.x, position.y},
		game_state.font_size,
		game_state.font_spacing,
		rl.WHITE,
	)

	rl.DrawTextEx(
		game_state.font,
		rl.TextFormat("LEVEL\n    %i", game_state.level),
		rl.Vector2{position.x, position.y + 100},
		game_state.font_size,
		game_state.font_spacing,
		rl.WHITE,
	)

	rl.DrawTextEx(
		game_state.font,
		rl.TextFormat("SCORE\n    %i", game_state.score),
		rl.Vector2{position.x, position.y + 200},
		game_state.font_size,
		game_state.font_spacing,
		rl.WHITE,
	)
}

draw_grid :: proc(game_state: ^Game_State) {
	GRID_PIXEL_WIDTH :: COLS_COUNT * IMAGE_DEST_SIZE
	GRID_PIXEL_HEIGHT :: ROWS_COUNT * IMAGE_DEST_SIZE

	START_X :: (GAME_WIDTH - GRID_PIXEL_WIDTH) * 0.5
	START_Y :: (GAME_HEIGHT - GRID_PIXEL_HEIGHT) * 0.5

	for x in 0 ..< COLS_COUNT {
		for y in 0 ..< ROWS_COUNT {
			pos_x := START_X + (x * IMAGE_DEST_SIZE)
			pos_y := START_Y + (y * IMAGE_DEST_SIZE)

			draw_atlas_texture(
				game_state,
				texture_offsets[game_state.cells[x][y]],
				rl.Vector2{cast(f32)pos_x, cast(f32)pos_y},
			)
		}
	}
}

place_tetromino :: proc(game_state: ^Game_State) {

}


draw_atlas_texture :: proc(
	game_state: ^Game_State,
	texture_offset: rl.Vector2,
	position: rl.Vector2,
) {
	dest := rl.Rectangle{position.x, position.y, IMAGE_DEST_SIZE, IMAGE_DEST_SIZE}

	rl.DrawTexturePro(
		game_state.atlas,
		rl.Rectangle{texture_offset.x, texture_offset.y, IMAGE_SOURCE_SIZE, IMAGE_SOURCE_SIZE},
		dest,
		rl.Vector2{0, 0},
		0,
		rl.WHITE,
	)
}
