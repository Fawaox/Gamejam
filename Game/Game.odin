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

step :: proc() -> bool
{
	if !k2.update()
	{
        return false
    }

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
	gameState.player.position = Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
}

Player :: struct
{
	position: Vec2
}
