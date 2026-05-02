package Game

import "core:math"
import "core:math/linalg"

import k2 "../karl2d"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

MAX_BULLETS :: 128
BULLET_SPEED :: 400

Vec2 :: k2.Vec2

// Global Variables
screenCenter: Vec2
gameState: GameState
textures: Textures

// Structs
Textures :: struct
{
	car: k2.Texture,
	bullet: k2.Texture,
}

GameState :: struct
{
	player: Player,
	bullets: [MAX_BULLETS]Bullet,
	bulletCounter: i32,
}

Player :: struct
{
	position: Vec2,
	roatation: f32,
	bodyRect: k2.Rect, // use this as pos?? rename to sprite?
	gunAngle: f32,
}

Bullet :: struct
{
	position: Vec2,
	rotation: f32,
	velocity: Vec2,
	age: f32, // 0 is unused (free), 1 - 255 alive and after 255 it will die (= 0).
}

main :: proc()
{
	init()
	for step() {}
	shutdown()
}

init :: proc()
{
	k2.init(WINDOW_WIDTH, WINDOW_HEIGHT, "Game!")

	screenCenter = k2.get_window_scale() * Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2} // wait maybe remove getwindowscale here and only do when drawing

	LoadTextures()
	InitGameState()
}

LoadTextures :: proc()
{
	textures.car = k2.load_texture_from_bytes(#load("../assets/Car_1_Gray.png"))
	textures.bullet = k2.load_texture_from_bytes(#load("../assets/Pistol-Bullet.png"))
}

InitGameState :: proc()
{
	gameState.player.position =  k2.get_window_scale() * Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}

	gameState.player.bodyRect = k2.Rect{640-50,360-75,100,150}

	for i in 0..<MAX_BULLETS
	{
		gameState.bullets[i].position = k2.get_window_scale() *Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
	}
}

UpdatePlayer :: proc()
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

    gameState.player.bodyRect.x = gameState.player.position.x
    gameState.player.bodyRect.y = gameState.player.position.y

    direction: Vec2 = k2.get_mouse_position() - gameState.player.position
   	len := linalg.length(direction)
    unit := direction
    if len > 0 do unit /= len

    if k2.mouse_button_went_down(.Left)
    {
    	gameState.bullets[gameState.bulletCounter].position = gameState.player.position
    	gameState.bullets[gameState.bulletCounter].velocity = unit
     	gameState.bullets[gameState.bulletCounter].rotation = math.atan2(direction.y, direction.x)
     	gameState.bullets[gameState.bulletCounter].age = 1
     	gameState.bulletCounter += 1
    }

    gameState.player.gunAngle = math.atan2(direction.y, direction.x)
}

DrawPlayer :: proc()
{
	k2.draw_rect(gameState.player.bodyRect, k2.BLUE)
	k2.draw_circle(gameState.player.position, 32.0, k2.GREEN)
    k2.draw_circle(Vec2{gameState.player.position.x + math.cos(gameState.player.gunAngle) * 32, gameState.player.position.y + math.sin(gameState.player.gunAngle) * 32}, 4.0, k2.WHITE)
}

UpdateBullets :: proc()
{
	for bullet in 0..<MAX_BULLETS
	{
		if gameState.bullets[bullet].age > 0
		{
			gameState.bullets[bullet].position.x += gameState.bullets[bullet].velocity.x * BULLET_SPEED * k2.get_frame_time()
			gameState.bullets[bullet].position.y += gameState.bullets[bullet].velocity.y * BULLET_SPEED * k2.get_frame_time()

			gameState.bullets[bullet].age += 0.5
			if gameState.bullets[bullet].age == 255 do gameState.bullets[bullet].age = 0
		}
	}
}

DrawBullets :: proc()
{
	for bullet in 0..<MAX_BULLETS
	{
		if gameState.bullets[bullet].age > 0
		{
			k2.draw_circle(gameState.bullets[bullet].position, 16.0, k2.RED)
		}
	}
}

step :: proc() -> bool
{
	if !k2.update()
	{
        return false
    }

    UpdatePlayer()
    UpdateBullets()

    k2.clear(k2.LIGHT_BLUE)
    defer k2.present()

    // Drawing
    DrawPlayer()
    DrawBullets()

	return true
}

shutdown :: proc()
{

}
