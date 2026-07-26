package plug

import "core:fmt"

@(export)
init :: proc() {
    fmt.println("[plug] init")
}

@(export)
update :: proc() {
    fmt.println("[plug] update")
}

@(export)
draw :: proc() {
    fmt.println("[plug] draw")
}

@(export)
deinit :: proc() {
    fmt.println("[plug] deinit")
}
