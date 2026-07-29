package plug

import "core:log"
import "core:math/rand"

// TODO: test each tetromino rotation

// FIX: when dropping with space, dropped tetromino does not get removed with
// lines
// TODO: gradually increase speed
// TODO: conuter clockwise rotation
// TODO: falling with S key
// TODO: some tetrominos rotate incorrectly
// TODO: add sounds
// TODO: do not spawn tetromino after losing (locking the top shelf)

import "base:runtime"
import rl "vendor:raylib"

UPDATES_PER_SECOND :: 60.0
FIXED_DT :: 1.0 / UPDATES_PER_SECOND
MAX_FRAME_TIME :: 0.25

MASTER_VOLUME :: 0.1

GAME_VERSION :: "v0.3"

TETROMINO_SIDE :: 4
TETROMINO_LOCK_DELAY :: 0.5
INITIAL_GRAIVTY :: 0.8

IMAGE_SOURCE_SIZE :: 8
IMAGE_SPRITE_SCALE :: 4
IMAGE_DEST_SIZE :: IMAGE_SOURCE_SIZE * IMAGE_SPRITE_SCALE

ATLAS_BYTES :: #load("../assets/atlas.png")
FONT_BYTES :: #load("../assets/vcr_osd_mono.ttf")
TETROMINO_FALL_SOUND_1_BYTES :: #load("../assets/tetromino_fell_1.wav")
TETROMINO_FALL_SOUND_2_BYTES :: #load("../assets/tetromino_fell_2.wav")
TETROMINO_FALL_SOUND_3_BYTES :: #load("../assets/tetromino_fell_3.wav")
MAIN_THEME_BYTES :: #load("../assets/main_theme.mp3")

COLS_COUNT :: 10
ROWS_COUNT :: 20

GAME_WIDTH :: 1920
GAME_HEIGHT :: 1080

PITCH_LOWER_LIMIT :: 0.8
PITCH_DEFAULT :: 1.0
PITCH_UPPER_LIMIT :: 1.2

BACKGROUND_COLOR :: rl.Color{34, 35, 35, 255}

DEBUG_BUILD :: #config(DEBUG_BUILD, false)

TEXTURE_OFFSETS := [Cell]rl.Vector2 {
	.Wall            = rl.Vector2{0, 0},
	.AltWall         = rl.Vector2{IMAGE_SOURCE_SIZE, 0},
	.Empty           = rl.Vector2{IMAGE_SOURCE_SIZE * 2, 0},
	.Tetromino       = rl.Vector2{IMAGE_SOURCE_SIZE * 3, 0},
	.LockedTetromino = rl.Vector2{IMAGE_SOURCE_SIZE * 4, 0},
}

TETROMINO_SHAPES: [Tetromino_Shape]Shape_Grid = {
	.I = {{1, 1, 1, 1}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
	.J = {{1, 0, 0, 0}, {1, 1, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
	.L = {{0, 0, 1, 0}, {1, 1, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
	.O = {{0, 1, 1, 0}, {0, 1, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
	.S = {{0, 1, 1, 0}, {1, 1, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
	.T = {{0, 1, 0, 0}, {1, 1, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
	.Z = {{1, 1, 0, 0}, {0, 1, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
}

SOUNDS_COUNT :: 3

Shape_Grid :: [TETROMINO_SIDE][TETROMINO_SIDE]u8

Tetromino_Shape :: enum {
	I,
	J,
	L,
	O,
	S,
	T,
	Z,
}

Cell :: enum {
	Wall,
	AltWall,
	Empty,
	Tetromino,
	LockedTetromino,
}

Game_State :: struct {
	atlas:              rl.Texture,
	board:              [COLS_COUNT][ROWS_COUNT]Cell,
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
	active_shape:       Tetromino_Shape,
	active_grid:        Shape_Grid,
	active_x:           i32,
	active_y:           i32,
	active_move_delay:  f32,
	active_move_timer:  f32,
	has_lost:           bool,
	locking_timer:      f32,
	accumulator:        f32,
	sounds:             [SOUNDS_COUNT]rl.Sound,
	music:              rl.Music,
}

@(export)
game_init :: proc(state: ^rawptr, ctx: runtime.Context) {
	context = ctx
	log.info("[plug] init")

	if state^ != nil {
		log.info("[plug] memory already allocated, skipping...")

		game_state := cast(^Game_State)state
		rl.ResumeMusicStream(game_state.music)
		return
	}

	game_state := new(Game_State)

	rl.SetMasterVolume(MASTER_VOLUME)

	reset_game(game_state)

	atlas_img := rl.LoadImageFromMemory(".png", raw_data(ATLAS_BYTES), cast(i32)len(ATLAS_BYTES))
	if atlas_img.data == nil {
		log.error("[plug] failed to load atlas texture from memory")
		return
	}

	atlas := rl.LoadTextureFromImage(atlas_img)
	rl.UnloadImage(atlas_img)
	if atlas.id <= 0 {
		log.error("[plug] failed to load atlas texture")
		return
	}

	game_state.font = rl.LoadFontFromMemory(
		".ttf",
		raw_data(FONT_BYTES),
		cast(i32)len(FONT_BYTES),
		cast(i32)game_state.font_size,
		nil,
		0,
	)

	game_state.debug_font = rl.LoadFontFromMemory(
		".ttf",
		raw_data(FONT_BYTES),
		cast(i32)len(FONT_BYTES),
		cast(i32)game_state.debug_font_size,
		nil,
		0,
	)

	game_state.atlas = atlas
	game_state.target_texture = rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT)

	sound_waves := [SOUNDS_COUNT]rl.Wave {
		rl.LoadWaveFromMemory(
			".wav",
			raw_data(TETROMINO_FALL_SOUND_1_BYTES),
			cast(i32)len(TETROMINO_FALL_SOUND_1_BYTES),
		),
		rl.LoadWaveFromMemory(
			".wav",
			raw_data(TETROMINO_FALL_SOUND_2_BYTES),
			cast(i32)len(TETROMINO_FALL_SOUND_2_BYTES),
		),
		rl.LoadWaveFromMemory(
			".wav",
			raw_data(TETROMINO_FALL_SOUND_3_BYTES),
			cast(i32)len(TETROMINO_FALL_SOUND_3_BYTES),
		),
	}

	for wave, i in sound_waves {
		game_state.sounds[i] = rl.LoadSoundFromWave(wave)
		rl.UnloadWave(wave)
	}

	game_state.music = rl.LoadMusicStreamFromMemory(
		".mp3",
		raw_data(MAIN_THEME_BYTES),
		cast(i32)len(MAIN_THEME_BYTES),
	)

	state^ = game_state
	log.info("[plug] allocated game_state")

	rl.SetMusicVolume(game_state.music, 0.5)
	rl.PlayMusicStream(game_state.music)
}

play_random_fall_sound :: proc(game_state: ^Game_State) {
	sound := game_state.sounds[2]

	value := rand.float32_range(PITCH_LOWER_LIMIT, PITCH_UPPER_LIMIT)
	rl.SetSoundPitch(sound, value)

	rl.PlaySound(sound)

	rl.SetSoundPitch(sound, PITCH_DEFAULT)
}

@(export)
game_update :: proc(state: rawptr, ctx: runtime.Context) {
	context = ctx
	game_state := cast(^Game_State)state

	frame_time := rl.GetFrameTime()
	frame_time = min(frame_time, MAX_FRAME_TIME)
	game_state.accumulator += frame_time

	when DEBUG_BUILD do if rl.IsKeyPressed(.R) do reset_game(game_state)
	when DEBUG_BUILD do if rl.IsKeyPressed(.F1) do set_midgame_state(game_state)

	if game_state.has_lost {
		if rl.IsKeyPressed(.ENTER) do reset_game(game_state)
		return
	}

	update_movement_input(game_state)
	update_drop_input(game_state)
	update_rotation_input(game_state)

	rl.UpdateMusicStream(game_state.music)

	for game_state.accumulator >= FIXED_DT {
		update_active_tetromino(game_state)
		clear_lines(game_state)
		game_state.accumulator -= FIXED_DT
	}
}

is_valid_position :: proc(game_state: ^Game_State, target_x: i32, target_y: i32) -> bool {
	for y in 0 ..< TETROMINO_SIDE {
		for x in 0 ..< TETROMINO_SIDE {
			if game_state.active_grid[y][x] != 1 {
				continue
			}

			board_x := target_x + cast(i32)x
			board_y := target_y + cast(i32)y

			if board_x < 0 || board_x >= COLS_COUNT do return false

			if board_y < 0 || board_y >= ROWS_COUNT do return false

			if board_y >= 0 && game_state.board[board_x][board_y] != .Empty do return false

		}
	}

	return true
}

drop_active_tetromino :: proc(game_state: ^Game_State) {
	target_y := game_state.active_y

	if target_y == ROWS_COUNT {
		return
	}

	for {
		if !is_valid_position(game_state, game_state.active_x, target_y + 1) {
			break
		}

		target_y += 1
	}

	game_state.active_y = target_y

	lock_active_tetromino(game_state)
	clear_lines(game_state)
	game_state.locking_timer = 0
}

update_drop_input :: proc(game_state: ^Game_State) {
	if rl.IsKeyPressed(.SPACE) do drop_active_tetromino(game_state)
}

update_movement_input :: proc(game_state: ^Game_State) {
	input: i32

	if rl.IsKeyPressed(rl.KeyboardKey.A) || rl.IsKeyPressed(rl.KeyboardKey.LEFT) do input = -1
	if rl.IsKeyPressed(rl.KeyboardKey.D) || rl.IsKeyPressed(rl.KeyboardKey.RIGHT) do input = 1

	if input == 0 {
		return
	}

	target_x := game_state.active_x + input

	if is_valid_position(game_state, target_x, game_state.active_y) {
		game_state.active_x = target_x
	}
}

update_rotation_input :: proc(game_state: ^Game_State) {
	if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		rotate_active_tetromino_clockwise(game_state)
	}
}

rotate_active_tetromino_clockwise :: proc(game_state: ^Game_State) {
	transposed := transpose(game_state.active_grid)

	rotated: [TETROMINO_SIDE][TETROMINO_SIDE]u8

	for y in 0 ..< TETROMINO_SIDE {
		for x in 0 ..< TETROMINO_SIDE {
			reverse_x := (TETROMINO_SIDE - 1) - x
			rotated[y][reverse_x] = transposed[y][x]
		}
	}

	old_grid := game_state.active_grid

	game_state.active_grid = rotated

	if !is_valid_position(game_state, game_state.active_x, game_state.active_y) {
		game_state.active_grid = old_grid
	}
}

transpose :: proc(grid: [TETROMINO_SIDE][TETROMINO_SIDE]u8) -> [TETROMINO_SIDE][TETROMINO_SIDE]u8 {
	result: [TETROMINO_SIDE][TETROMINO_SIDE]u8

	for y in 0 ..< TETROMINO_SIDE {
		for x in 0 ..< TETROMINO_SIDE {
			result[x][y] = grid[y][x]
		}
	}

	return result
}

@(export)
game_draw :: proc(state: rawptr, ctx: runtime.Context) {
	context = ctx
	game_state := cast(^Game_State)state

	rl.BeginTextureMode(game_state.target_texture)
	rl.ClearBackground(BACKGROUND_COLOR)
	draw_grid(game_state)

	draw_game_info(game_state, rl.Vector2{GAME_WIDTH * 0.3, GAME_HEIGHT * 0.55})

	rl.DrawTextEx(
		game_state.debug_font,
		"GAME_VERSION: " + GAME_VERSION,
		rl.Vector2{10, 10},
		game_state.debug_font_size,
		game_state.debug_font_spacing,
		rl.WHITE,
	)

	when DEBUG_BUILD do rl.DrawTextEx(
		game_state.debug_font,
		"DEVELOPMENT_BUILD",
		rl.Vector2{10, 10 + game_state.debug_font_size},
		game_state.debug_font_size,
		game_state.debug_font_spacing,
		rl.WHITE,
	)

	when DEBUG_BUILD do rl.DrawTextEx(
		game_state.debug_font,
		rl.TextFormat("HAS_LOST: %s", game_state.has_lost ? "TRUE" : "FALSE"),
		rl.Vector2{10, 10 + 2 * game_state.debug_font_size},
		game_state.debug_font_size,
		game_state.debug_font_spacing,
		rl.WHITE,
	)

	when DEBUG_BUILD do rl.DrawTextEx(
		game_state.debug_font,
		"PRESS R TO RESTART",
		rl.Vector2{10, 10 + 3 * game_state.debug_font_size},
		game_state.debug_font_size,
		game_state.debug_font_spacing,
		rl.WHITE,
	)

	when DEBUG_BUILD do rl.DrawTextEx(
		game_state.debug_font,
		"PRESS F1 TO SET MIDGAME",
		rl.Vector2{10, 10 + 4 * game_state.debug_font_size},
		game_state.debug_font_size,
		game_state.debug_font_spacing,
		rl.WHITE,
	)

	when DEBUG_BUILD do rl.DrawTextEx(
		game_state.debug_font,
		rl.TextFormat("CURRENT GRAVITY: %f", game_state.active_move_delay),
		rl.Vector2{10, 10 + 5 * game_state.debug_font_size},
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

	rl.PauseMusicStream(game_state.music)
	log.info("[plug] deinit")
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
			pos_x := START_X + (cast(f32)x * IMAGE_DEST_SIZE)
			pos_y := START_Y + (cast(f32)y * IMAGE_DEST_SIZE)

			draw_atlas_texture(
				game_state,
				TEXTURE_OFFSETS[game_state.board[x][y]],
				rl.Vector2{pos_x, pos_y},
			)
		}
	}

	for y in 0 ..< ROWS_COUNT {
		y_pos := START_Y + (cast(f32)y * IMAGE_DEST_SIZE)

		draw_atlas_texture(
			game_state,
			TEXTURE_OFFSETS[.Wall],
			rl.Vector2{START_X - IMAGE_DEST_SIZE, y_pos},
		)

		draw_atlas_texture(
			game_state,
			TEXTURE_OFFSETS[.Wall],
			rl.Vector2{START_X + GRID_PIXEL_WIDTH, y_pos},
		)
	}

	bottom_y := START_Y + GRID_PIXEL_HEIGHT
	for x in -1 ..= COLS_COUNT {
		x_pos := START_X + (cast(f32)x * IMAGE_DEST_SIZE)
		draw_atlas_texture(
			game_state,
			TEXTURE_OFFSETS[.Wall],
			rl.Vector2{x_pos, cast(f32)bottom_y},
		)
	}

	for y in 0 ..< TETROMINO_SIDE {
		for x in 0 ..< TETROMINO_SIDE {
			if game_state.active_grid[y][x] == 1 {

				board_x := game_state.active_x + cast(i32)x
				board_y := game_state.active_y + cast(i32)y

				pos_x := START_X + (cast(f32)board_x * IMAGE_DEST_SIZE)
				pos_y := START_Y + (cast(f32)board_y * IMAGE_DEST_SIZE)

				draw_atlas_texture(
					game_state,
					TEXTURE_OFFSETS[.Tetromino],
					rl.Vector2{pos_x, pos_y},
				)
			}
		}
	}
}

lock_active_tetromino :: proc(game_state: ^Game_State) {
	for y in 0 ..< TETROMINO_SIDE {
		for x in 0 ..< TETROMINO_SIDE {
			if game_state.active_grid[y][x] != 1 {
				continue
			}

			board_x := game_state.active_x + cast(i32)x
			board_y := game_state.active_y + cast(i32)y

			game_state.board[board_x][board_y] = Cell.LockedTetromino
		}
	}
}

update_active_tetromino :: proc(game_state: ^Game_State) {
	target_y := game_state.active_y + 1
	is_touching_floor := !is_valid_position(game_state, game_state.active_x, target_y)

	if is_touching_floor {
		game_state.locking_timer += FIXED_DT

		if game_state.locking_timer >= TETROMINO_LOCK_DELAY {
			game_state.locking_timer = 0
			lock_active_tetromino(game_state)
			play_random_fall_sound(game_state)
			spawn_tetromino(game_state, rand.choice_enum(Tetromino_Shape))
			return
		}
	} else {
		game_state.locking_timer = 0
	}

	game_state.active_move_timer += FIXED_DT

	if game_state.active_move_timer >= game_state.active_move_delay {
		game_state.active_move_timer -= game_state.active_move_delay

		if !is_touching_floor {
			game_state.active_y = target_y
		}
	}
}

spawn_tetromino :: proc(game_state: ^Game_State, shape: Tetromino_Shape) {
	game_state.active_shape = shape
	game_state.active_grid = TETROMINO_SHAPES[shape]

	game_state.active_x = 3
	game_state.active_y = 0

	// TODO: check before spawning
	if !is_valid_position(game_state, game_state.active_x, game_state.active_y) {
		game_state.has_lost = true
	}
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

set_midgame_state :: proc(game_state: ^Game_State) {
	game_state.debug_font_size = 32
	game_state.debug_font_spacing = 2

	game_state.font_size = 32
	game_state.font_spacing = 2

	game_state.score = 0
	game_state.level = 1
	game_state.lines = 0

	game_state.active_move_delay = INITIAL_GRAIVTY
	game_state.active_move_timer = 0

	game_state.has_lost = false

	game_state.locking_timer = 0

	for x in 0 ..< COLS_COUNT {
		for y in 0 ..< ROWS_COUNT {
			game_state.board[x][y] = Cell.Empty
		}
	}

	for x in 0 ..< COLS_COUNT {
		for y := ROWS_COUNT - 1; y > 5; y -= 1 {
			game_state.board[x][y] = Cell.LockedTetromino
		}
	}

	spawn_tetromino(game_state, .I)
}

clear_line :: proc(game_state: ^Game_State, y: i32) {
	for x in 0 ..< COLS_COUNT do game_state.board[x][y] = .Empty
}

clear_lines :: proc(game_state: ^Game_State) {
	cleared_lines := 0

	for y := ROWS_COUNT - 1; y >= 0; {
		is_full := true

		for x in 0 ..< COLS_COUNT {
			if game_state.board[x][y] != .LockedTetromino {
				is_full = false
				break
			}
		}

		if is_full {
			for shift_y := y; shift_y > 0; shift_y -= 1 {
				for x in 0 ..< COLS_COUNT {
					game_state.board[x][shift_y] = game_state.board[x][shift_y - 1]
				}
			}
			clear_line(game_state, 0)
			cleared_lines += 1
		} else {
			y -= 1
		}
	}

	if cleared_lines > 0 {
		game_state.lines += cast(i32)cleared_lines
		switch cleared_lines {
		case 1:
			game_state.score += 100
		case 2:
			game_state.score += 300
		case 3:
			game_state.score += 500
		case 4:
			game_state.score += 800
		}
	}
}

reset_game :: proc(game_state: ^Game_State) {
	game_state.debug_font_size = 32
	game_state.debug_font_spacing = 2

	game_state.font_size = 32
	game_state.font_spacing = 2
	game_state.accumulator = 0

	game_state.score = 0
	game_state.level = 1
	game_state.lines = 0

	game_state.active_move_delay = INITIAL_GRAIVTY
	game_state.active_move_timer = 0

	game_state.has_lost = false

	for x in 0 ..< COLS_COUNT {
		for y in 0 ..< ROWS_COUNT {
			game_state.board[x][y] = Cell.Empty
		}
	}

	game_state.locking_timer = 0

	spawn_tetromino(game_state, rand.choice_enum(Tetromino_Shape))
}

@(export)
game_shutdown :: proc(state: ^rawptr, ctx: runtime.Context) {
	context = ctx
	if state^ == nil {
		log.info("[plug] state is already null, while shutting down, skipping...")
		return
	}

	game_state := cast(^Game_State)(state^)

	rl.UnloadTexture(game_state.atlas)
	rl.UnloadRenderTexture(game_state.target_texture)
	rl.UnloadFont(game_state.debug_font)
	rl.UnloadFont(game_state.font)

	for fall_sound in game_state.sounds {
		rl.UnloadSound(fall_sound)
	}

	rl.UnloadMusicStream(game_state.music)

	log.info("[plug] full shutdown complete")
}
