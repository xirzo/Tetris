package plug

import rl "vendor:raylib"
import "core:fmt"

@(export)
init :: proc() {
    fmt.println("[plug] init")
}

@(export)
update :: proc() {
}

@(export)
draw :: proc() {
    rl.ClearBackground(rl.WHITE)
}

@(export)
deinit :: proc() {
    fmt.println("[plug] deinit")
}
