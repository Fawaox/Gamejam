package Game

import k2 "karl2d"

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
    k2.draw_text("Hellope!", {50, 50}, 100, k2.DARK_BLUE)

	return true
}

shutdown :: proc()
{

}
