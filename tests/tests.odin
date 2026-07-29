package tests

import "core:testing"
import pl "game:plug"
import rl "vendor:raylib"

@(test)
test_tetromino_drop :: proc(t: ^testing.T) {
	rl.SetTraceLogLevel(.FATAL)
	rl.InitWindow(100, 100, "Integration Test")
	defer rl.CloseWindow()
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	state: rawptr = nil
	pl.game_init(&state, context)
	game_state := cast(^pl.Game_State)state

	defer {
		pl.game_shutdown(&state, context)
		free(state)
	}

	pl.spawn_tetromino(game_state, .I)
	game_state.active_x = 0
	game_state.active_y = 0

	testing.expect(t, game_state.board[0][pl.ROWS_COUNT - 1] == .Empty, "Board should start empty")

	pl.drop_active_tetromino(game_state)

	testing.expect_value(t, game_state.active_y, 19)

	testing.expect(
		t,
		game_state.board[0][19] == .LockedTetromino,
		"Piece did not lock into the board!",
	)
}
