package Game

import k2 "../karl2d"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

Vec2 :: k2.Vec2

main :: proc()
{
	init()
	for step() {}
	shutdown()
}

init :: proc()
{
	k2.init(WINDOW_WIDTH, WINDOW_HEIGHT, "Game!")

	InitGameState(&gameState)
}

HandleMovement :: proc()
{
	if k2.key_is_held(k2.Keyboard_Key.W)
    {
    	gameState.player.position.y -= 250 * k2.get_frame_time()
    }
    if k2.key_is_held(k2.Keyboard_Key.S)
    {
    	gameState.player.position.y += 250 * k2.get_frame_time()
    }
    if k2.key_is_held(k2.Keyboard_Key.A)
    {
    	gameState.player.position.x -= 250 * k2.get_frame_time()
    }
    if k2.key_is_held(k2.Keyboard_Key.D)
    {
    	gameState.player.position.x += 250 * k2.get_frame_time()
    }
}

step :: proc() -> bool
{
	if !k2.update()
	{
        return false
    }

    HandleMovement()

    k2.clear(k2.LIGHT_BLUE)
    defer k2.present()

    // Drawing
    k2.draw_text("Hellope!", {50, 50}, 100, k2.WHITE)

    k2.draw_circle(gameState.player.position, 32.0, k2.WHITE)

	return true
}

shutdown :: proc()
{

}

GameState :: struct
{
	player: Player
}

gameState: GameState

InitGameState :: proc(gameState: ^GameState)
{
	gameState.player.position = k2.get_window_scale() * Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
}

Player :: struct
{
	position: Vec2
}
