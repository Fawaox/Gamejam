package Game

import "core:math"

import k2 "../karl2d"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

MAX_PROJECTILES :: 32

Vec2 :: k2.Vec2

main :: proc()
{
	init()
	for step() {}
	shutdown()
}
car: k2.Texture

bulletTex: k2.Texture
init :: proc()
{
	k2.init(WINDOW_WIDTH, WINDOW_HEIGHT, "Game!")

	car = k2.load_texture_from_bytes(#load("../assets/Car_1_Gray.png"))
	bulletTex = k2.load_texture_from_bytes(#load("../assets/Pistol-Bullet.png"))


	InitGameState(&gameState)

	for i in 0..<MAX_PROJECTILES
	{
		gameState.projectiles[i].position = k2.get_window_scale() *Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
	}
	//projectile.position = k2.get_window_scale() *Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
}

HandlePlayerMovement :: proc()
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
bulletCounter: i32 = 0
step :: proc() -> bool
{
	if !k2.update()
	{
        return false
    }

    HandlePlayerMovement()
    //gameState.player.position = k2.get_mouse_position()

    k2.clear(k2.LIGHT_BLUE)
    defer k2.present()

    // Drawing



    middle:=k2.get_window_scale() *Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}

    dir: Vec2 = k2.get_mouse_position() - middle
    angle: f32 = math.atan2(dir.y, dir.x)




    len := math.sqrt(dir.x*dir.x + dir.y*dir.y) // same as vector2length in raylib

    unit := dir
    if len > 0 {
        unit /= len
    }

    speed: f32 = 300.0

    src := k2.get_texture_rect(bulletTex)

    if k2.mouse_button_went_down(.Left)
    {
    	gameState.projectiles[bulletCounter].velocity = unit
     	gameState.projectiles[bulletCounter].alive = true
     	bulletCounter += 1
    }

    gameState.player.body.x = gameState.player.position.x
    gameState.player.body.y = gameState.player.position.y
    k2.draw_rect(gameState.player.body, k2.BLUE )

    for bullet in 0..<MAX_PROJECTILES
    {
    	if gameState.projectiles[bullet].alive
     	{
      gameState.projectiles[bullet].position.x += gameState.projectiles[bullet].velocity.x * speed * k2.get_frame_time()
	    gameState.projectiles[bullet].position.y += gameState.projectiles[bullet].velocity.y * speed * k2.get_frame_time()

	    k2.draw_circle(gameState.projectiles[bullet].position, 16.0, k2.RED)
			//k2.draw_texture(bulletTex,gameState.projectiles[bullet].position)
			dst := k2.Rect {
			    x = gameState.projectiles[bullet].position.x,
			    y = gameState.projectiles[bullet].position.y,
			    w = src.w*5,
			    h = src.h*5,
			}
			k2.draw_texture_fit(bulletTex, src, dst,rotation=angle)
      }

    }
    src = k2.get_texture_rect(car)
    dst := k2.Rect {
			    x = gameState.player.position.x,
			    y = gameState.player.position.y,
			    w = src.w*5,
			    h = src.h*5,
			}
			k2.draw_texture_fit(car, src, dst)
    // Tower
    k2.draw_circle(k2.get_window_scale() * Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}, 32.0, k2.GREEN)
    k2.draw_circle(Vec2{middle.x + math.cos(angle)*32, middle.y + math.sin(angle)*32}, 4.0, k2.WHITE)



    //k2.draw_circle(gameState.player.position, 32.0, k2.WHITE)

	return true
}

shutdown :: proc()
{

}

Projectile :: struct
{
	position: Vec2,
	velocity: Vec2,
	alive: bool, // maybe this u8 and age and the at age 255 it dies?
}

GameState :: struct
{
	player: Player,
	projectiles: [MAX_PROJECTILES]Projectile
}

gameState: GameState

InitGameState :: proc(gameState: ^GameState)
{
	gameState.player.position = k2.get_window_scale() * Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}

	gameState.player.body = k2.Rect{640*k2.get_window_scale()-50,k2.get_window_scale()*360-75,100,150}
}

Player :: struct
{
	position: Vec2,
	body: k2.Rect,
}
