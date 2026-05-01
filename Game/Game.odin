package Game

import k2 "../karl2d"

main :: proc()
{
	init()
	for step() {}
	shutdown()
}

init :: proc()
{
	k2.init(1280, 720, "Game!")
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
    k2.draw_text("Hellope!", {50, 50}, 100, TEST_COLOR)

	return true
}

TEST_COLOR :: k2.Color{20, 20, 20, 255}

shutdown :: proc()
{

}

GameState :: struct
{
	player: Player
}

Player :: struct
{
	position: k2.Vec2
}
