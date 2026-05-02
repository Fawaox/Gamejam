package Game

import k2 "../karl2d"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import b2 "vendor:box2d"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

NUM_MAX_ENEMIES :: 50
ENEMY_SPAWN_INTERVAL_SECONDS :: 0.1
ENEMY_SPEED :: 7
ENEMY_RADIUS :: 6

PROJECTILE_RADIUS :: 2
PROJECTILE_SPEED :: 500
PROJECTILE_LIFETIME_SECONDS :: 3 // TODO destroy projectiles after a while.

MAX_BULLETS :: 128
BULLET_SPEED :: 400

Vec2 :: k2.Vec2

// Global Variables
screenCenter: Vec2
gameState: GameState
textures: Textures

// Structs
Textures :: struct {
	crosshair: k2.Texture,
	car:    k2.Texture,
	bullet: k2.Texture,
}

Player :: struct {
	position:  Vec2,
	roatation: f32,
	bodyRect:  k2.Rect, // use this as pos?? rename to sprite?
	gunAngle:  f32,
}

Bullet :: struct {
	position: Vec2,
	rotation: f32,
	velocity: Vec2,
	age:      f32, // 0 is unused (free), 1 - 255 alive and after 255 it will die (= 0).
}

// TODO: from b2 example. maybe remove/put in gameState?
world_id: b2.WorldId
time_acc: f32

main :: proc() {
	init()
	for step() {}
	shutdown()
}

init :: proc() {
	k2.init(WINDOW_WIDTH, WINDOW_HEIGHT, "Game!")

	k2.set_cursor_visible(false)

	b2.SetLengthUnitsPerMeter(4) // TODO does this make sense?
	world_def := b2.DefaultWorldDef()
	world_def.gravity = b2.Vec2{0, 0}
	world_id = b2.CreateWorld(world_def)

	screenCenter = k2.get_window_scale() * Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2} // wait maybe remove getwindowscale here and only do when drawing

	LoadTextures()
	InitGameState()
}

LoadTextures :: proc() {
	textures.crosshair = k2.load_texture_from_bytes(#load("../assets/crosshair.png"))
	textures.car = k2.load_texture_from_bytes(#load("../assets/Car_1_Gray.png"))
	textures.bullet = k2.load_texture_from_bytes(#load("../assets/Pistol-Bullet.png"))
}

InitGameState :: proc() {
	gameState.player.position = k2.get_window_scale() * Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}

	gameState.player.bodyRect = k2.Rect{640 - 50, 360 - 75, 100, 150}

	for i in 0 ..< MAX_BULLETS {
		gameState.bullets[i].position =
			k2.get_window_scale() * Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
	}

	// Terrible hack: allocate big buffer, so pointers never change. Otherwise, if we reallocate
	// the dynamic array, would invalidate all the pointers in box2d userdata.
	gameState.entities = make([dynamic]Entity, 0, 10000)
}

UpdatePlayer :: proc() {
	if k2.key_is_held(k2.Keyboard_Key.W) {
		gameState.player.position.y -= 250 * k2.get_frame_time()
	}
	if k2.key_is_held(k2.Keyboard_Key.S) {
		gameState.player.position.y += 250 * k2.get_frame_time()
	}
	if k2.key_is_held(k2.Keyboard_Key.A) {
		gameState.player.position.x -= 250 * k2.get_frame_time()
	}
	if k2.key_is_held(k2.Keyboard_Key.D) {
		gameState.player.position.x += 250 * k2.get_frame_time()
	}

	gameState.player.bodyRect.x = gameState.player.position.x
	gameState.player.bodyRect.y = gameState.player.position.y

	direction: Vec2 = k2.get_mouse_position() - gameState.player.position
	len := linalg.length(direction)
	unit := direction
	if len > 0 do unit /= len

	if k2.mouse_button_went_down(.Left) {
		gameState.bullets[gameState.bulletCounter].position = gameState.player.position
		gameState.bullets[gameState.bulletCounter].velocity = unit
		gameState.bullets[gameState.bulletCounter].rotation = math.atan2(direction.y, direction.x)
		gameState.bullets[gameState.bulletCounter].age = 1
		gameState.bulletCounter += 1
	}

	gameState.player.gunAngle = math.atan2(direction.y, direction.x)
}

DrawPlayer :: proc() {
	k2.draw_rect(gameState.player.bodyRect, k2.BLUE)
	k2.draw_circle(gameState.player.position, 32.0, k2.GREEN)
	k2.draw_circle(
		Vec2 {
			gameState.player.position.x + math.cos(gameState.player.gunAngle) * 32,
			gameState.player.position.y + math.sin(gameState.player.gunAngle) * 32,
		},
		4.0,
		k2.WHITE,
	)
}

DrawCrosshair :: proc()
{
	src := k2.get_texture_rect(textures.crosshair)
	dst := k2.Rect{
    x = k2.get_mouse_position().x-256/8,
    y = k2.get_mouse_position().y-256/8,
    w = src.w/8,
    h = src.h/8,
	}
	k2.draw_texture_fit(textures.crosshair, src, dst)
}

UpdateBullets :: proc() {
	for bullet in 0 ..< MAX_BULLETS {
		if gameState.bullets[bullet].age > 0 {
			gameState.bullets[bullet].position.x +=
				gameState.bullets[bullet].velocity.x * BULLET_SPEED * k2.get_frame_time()
			gameState.bullets[bullet].position.y +=
				gameState.bullets[bullet].velocity.y * BULLET_SPEED * k2.get_frame_time()

			gameState.bullets[bullet].age += 0.5
			if gameState.bullets[bullet].age == 255 do gameState.bullets[bullet].age = 0
		}
	}
}

DrawBullets :: proc() {
	for bullet in 0 ..< MAX_BULLETS {
		if gameState.bullets[bullet].age > 0 {
			k2.draw_circle(gameState.bullets[bullet].position, 16.0, k2.RED)
		}
	}
}

step :: proc() -> bool {
	if !k2.update() {
		return false
	}

	dt := k2.get_frame_time()
	time_acc += dt

	// Set the target. That's where the zombies walk to for now. Needs to be using the vehicle position later.
	if k2.mouse_button_went_down(.Left) {
		gameState.current_enemy_target = k2.get_mouse_position()
	}

	if k2.mouse_button_went_down(.Right) {
		target_position := k2.get_mouse_position()
		direction := linalg.normalize0(target_position - gameState.current_enemy_target)
		velocity := direction * PROJECTILE_SPEED
		append(&gameState.entities, create_projectile(gameState.current_enemy_target, velocity))
		b2.Body_SetUserData(
			gameState.entities[len(gameState.entities) - 1].body_id,
			cast(rawptr)&gameState.entities[len(gameState.entities) - 1],
		)
	}

	enemity_count: i32
	// Move enemies towards the target and count enemies
	for &entity in gameState.entities {
		if entity.type == .Enemy {
			b2_target_pos := k2_position_to_b2_position(gameState.current_enemy_target)
			direction := linalg.normalize0(b2_target_pos - b2.Body_GetPosition(entity.body_id))
			b2.Body_SetLinearVelocity(entity.body_id, direction * ENEMY_SPEED)
			enemity_count += 1
		}
	}

	// Spawn new enemies, based on time, at random positions
	if enemity_count < NUM_MAX_ENEMIES &&
	   gameState.last_enemy_spawn_time + ENEMY_SPAWN_INTERVAL_SECONDS <= k2.get_time() {
		append(&gameState.entities, create_enemy())
		b2.Body_SetUserData(
			gameState.entities[len(gameState.entities) - 1].body_id,
			cast(rawptr)&gameState.entities[len(gameState.entities) - 1],
		)
		gameState.last_enemy_spawn_time = k2.get_time()
	}

	pos := k2.get_mouse_position()

	SUB_STEPS :: 4
	TIME_STEP :: 1.0 / 60

	for time_acc >= TIME_STEP {
		b2.World_Step(world_id, TIME_STEP, SUB_STEPS)
		time_acc -= TIME_STEP

		// TODO react to events here. Having a problem with figuring out the speed of hit events, atm.
		contactEvents := b2.World_GetContactEvents(world_id)
		for i in 0 ..< contactEvents.beginCount {
			//fmt.println("begin event, game time: ", k2.get_time())
		}
		for i in 0 ..< contactEvents.endCount {
		}
		for i in 0 ..< contactEvents.hitCount {
			hitEvent := contactEvents.hitEvents[i]
			if hitEvent.approachSpeed > 29 {
				//fmt.println("hit event; speed:", hitEvent.approachSpeed)
				shapeA := hitEvent.shapeIdA
				shapeB := hitEvent.shapeIdB
				bodyA := b2.Shape_GetBody(shapeA)
				bodyB := b2.Shape_GetBody(shapeB)
				dataA := b2.Body_GetUserData(bodyA)
				dataB := b2.Body_GetUserData(bodyB)
				entityA := cast(^Entity)dataA
				entityB := cast(^Entity)dataB
				if entityA.type == .Projectile && entityB.type == .Enemy {
					fmt.println("Hit event between projectile and enemy, at time: ", k2.get_time())
					destroy_entity(entityA)
					destroy_entity(entityB)
				}
			}
		}
	}

	UpdatePlayer()
	UpdateBullets()

	k2.clear(k2.LIGHT_BLUE)
	defer k2.present()

	// Drawing
	DrawPlayer()
	DrawBullets()
	DrawCrosshair()

	k2.draw_circle(gameState.player.position, 32.0, k2.WHITE)
	//k2.draw_circle(gameState.current_enemy_target, 32.0, k2.BLUE)

	for entity in gameState.entities {
		switch entity.type {
		case .Enemy:
			k2.draw_circle(
				b2_position_to_k2_position(b2.Body_GetPosition(entity.body_id)),
				ENEMY_RADIUS,
				k2.RED,
			)
		case .Projectile:
			k2.draw_circle(
				b2_position_to_k2_position(b2.Body_GetPosition(entity.body_id)),
				PROJECTILE_RADIUS,
				k2.GRAY,
			)
		}
	}

	return true
}

shutdown :: proc() {
	delete(gameState.entities)
}

create_enemy :: proc() -> Entity {
	x := rand.float32_range(0, WINDOW_WIDTH) // TODO set sense making range
	y := rand.float32_range(0, WINDOW_HEIGHT) // TODO set sense making range

	body_def := b2.DefaultBodyDef()
	body_def.type = .dynamicBody
	body_def.position = k2_position_to_b2_position(Vec2{x, y})
	body_id := b2.CreateBody(world_id, body_def)

	shape_def := b2.DefaultShapeDef()
	shape_def.density = 1000
	shape_def.material.friction = 0.3
	shape_def.enableContactEvents = true
	shape_def.enableHitEvents = true

	circle: b2.Circle
	circle.radius = ENEMY_RADIUS
	_ = b2.CreateCircleShape(body_id, shape_def, circle)

	return Entity{.Enemy, body_id}
}

create_projectile :: proc(position: Vec2, velocity: Vec2) -> Entity {
	body_def := b2.DefaultBodyDef()
	body_def.type = .kinematicBody
	body_def.position = k2_position_to_b2_position(position)
	body_def.isBullet = true
	body_id := b2.CreateBody(world_id, body_def)
	b2.Body_SetLinearVelocity(body_id, k2_position_to_b2_position(velocity))

	shape_def := b2.DefaultShapeDef()
	shape_def.density = 1000
	shape_def.material.friction = 0.3
	shape_def.enableContactEvents = true
	shape_def.enableHitEvents = true

	circle: b2.Circle
	circle.radius = PROJECTILE_RADIUS
	_ = b2.CreateCircleShape(body_id, shape_def, circle)

	return Entity{.Projectile, body_id}
}

destroy_entity :: proc(entity_ptr: ^Entity) {
	for &entity, i in gameState.entities {
		if &entity == entity_ptr {
			b2.DestroyBody(entity.body_id)
			unordered_remove(&gameState.entities, i)
		}
	}
	// TODO: recreating all the userdata pointers whenever we destroy an entity. very silly, should use some kind of stable ID system.
	for &entity in gameState.entities {
		b2.Body_SetUserData(entity.body_id, cast(rawptr)&entity)
	}
}

k2_position_to_b2_position :: proc(position: Vec2) -> b2.Vec2 {
	return b2.Vec2{position.x, -position.y}
}

b2_position_to_k2_position :: proc(position: b2.Vec2) -> b2.Vec2 {
	return Vec2{position.x, -position.y}
}

GameState :: struct {
	player:                Player,
	bullets:               [MAX_BULLETS]Bullet,
	bulletCounter:         i32,
	current_enemy_target:  Vec2,
	entities:              [dynamic]Entity,
	last_enemy_spawn_time: f64,
}

Entity_Type :: enum {
	Enemy,
	Projectile,
}

Entity :: struct {
	type:    Entity_Type,
	body_id: b2.BodyId,
}
