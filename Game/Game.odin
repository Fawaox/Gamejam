package Game

import "core:math"

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
angle: f32
step :: proc() -> bool
{
	if !k2.update()
	{
        return false
    }

    //HandleMovement()
    gameState.player.position = k2.get_mouse_position()

    k2.clear(k2.LIGHT_BLUE)
    defer k2.present()

    // Drawing

    // Tower
    k2.draw_circle(k2.get_window_scale() * Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}, 32.0, k2.RED)

    middle:=k2.get_window_scale() *Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}

    dir: Vec2 = k2.get_mouse_position() - middle
    angle: f32 = math.atan2(dir.y, dir.x)

    k2.draw_circle(Vec2{middle.x + math.cos(angle)*256, middle.y + math.sin(angle)*256}, 32.0, k2.WHITE)

    //k2.draw_circle(gameState.player.position, 32.0, k2.WHITE)

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
