package Game

import k2 "../karl2d"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import b2 "vendor:box2d"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

NUM_MAX_ENEMIES :: 30
ENEMY_SPAWN_INTERVAL_SECONDS :: 0.1
ENEMY_SPEED :: 7
ENEMY_RADIUS :: 6
ENEMY_MAX_HEALTH :: 100
ENEMY_MINIMUM_SPAWN_DISTANCE_FROM_PLAYEER :: 300

BULLET_RADIUS :: 5
BULLET_SPEED :: 400
BULLET_LIFETIME_SECONDS :: 3 // TODO destroy bullets after a while.
BULLET_DAMAGE :: 101 // Yeah, this might have been pointless. Made zombies have health. In case we want them to take more than 1 shot.

PLAYER_VEHICLE_WIDTH :: 100
PLAYER_VEHICLE_HEIGHT :: 150
PLAYER_MAX_HEALTH :: 100
PLAYER_FORWARD_FORCE :: 100000000000 // TODO tweak numbers
PLAYER_BACKWARD_FORCE :: 70000000000
PLAYER_ROTATION_FORCE :: 600000000000

Vec2 :: k2.Vec2

// Global Variables
screenCenter: Vec2
gameState: GameState
textures: Textures
sounds: Sounds

// Structs
Textures :: struct {
	crosshair: k2.Texture,
	car:       k2.Texture,
	bullet:    k2.Texture,
}

Sounds :: struct {
	buffShoot_1: k2.Audio_Buffer,
	buffShoot_2: k2.Audio_Buffer,
	Shoot_1:     k2.Sound,
	Shoot_2:     k2.Sound,
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

	b2.SetLengthUnitsPerMeter(1) // TODO does this make sense?
	world_def := b2.DefaultWorldDef()
	world_def.gravity = b2.Vec2{0, 0}
	world_id = b2.CreateWorld(world_def)

	screenCenter = k2.get_window_scale() * Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2} // wait maybe remove getwindowscale here and only do when drawing

	LoadTextures()
	LoadSounds()
	InitGameState()
}

LoadTextures :: proc() {
	textures.crosshair = k2.load_texture_from_bytes(#load("../assets/crosshair.png"))
	textures.car = k2.load_texture_from_bytes(#load("../assets/Car_1_Gray.png"))
	textures.bullet = k2.load_texture_from_bytes(#load("../assets/Pistol-Bullet.png"))
}

LoadSounds :: proc() {
	sounds.buffShoot_1 = k2.load_audio_buffer_from_bytes(#load("../assets/laserShoot_1.wav"))
	sounds.buffShoot_2 = k2.load_audio_buffer_from_bytes(#load("../assets/laserShoot_2.wav"))

	sounds.Shoot_1 = k2.create_sound_from_audio_buffer(sounds.buffShoot_1)
	sounds.Shoot_2 = k2.create_sound_from_audio_buffer(sounds.buffShoot_2)
}

InitGameState :: proc() {
	// Terrible hack: allocate big buffer, so pointers never change. Otherwise, if we reallocate
	// the dynamic array, would invalidate all the pointers in box2d userdata.
	gameState.entities = make([dynamic]Entity, 0, 10000)

	player_position := k2.get_window_scale() * Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
	append(&gameState.entities, create_player(player_position))
	b2.Body_SetUserData(
		gameState.entities[len(gameState.entities) - 1].body_id,
		cast(rawptr)&gameState.entities[len(gameState.entities) - 1],
	)
	gameState.player = &gameState.entities[len(gameState.entities) - 1]
}

UpdatePlayer :: proc() {
	if gameState.player == nil {
		return
	}

	// For testing: Do lots of damage to the player.
	if k2.key_went_down(k2.Keyboard_Key.K) {
		DamagePlayer(9999999999)
		return // Player will have died, can't update.
	}

	player_foward_force: f32
	player_torque: f32
	if k2.key_is_held(k2.Keyboard_Key.W) {
		player_foward_force += PLAYER_FORWARD_FORCE * k2.get_frame_time()
	}
	if k2.key_is_held(k2.Keyboard_Key.S) {
		player_foward_force -= PLAYER_BACKWARD_FORCE * k2.get_frame_time()
	}
	if k2.key_is_held(k2.Keyboard_Key.A) {
		player_torque += PLAYER_ROTATION_FORCE * k2.get_frame_time()
	}
	if k2.key_is_held(k2.Keyboard_Key.D) {
		player_torque -= PLAYER_ROTATION_FORCE * k2.get_frame_time()
	}

	local_force_vector := k2.Vec2{0, player_foward_force}
	rot := b2.Body_GetRotation(gameState.player.body_id)
	world_force_vector := b2.RotateVector(rot, local_force_vector)

	b2.Body_ApplyForceToCenter(gameState.player.body_id, world_force_vector, true)
	b2.Body_ApplyTorque(gameState.player.body_id, player_torque, true)

	player_position := b2.Body_GetPosition(gameState.player.body_id)

	direction: Vec2 = k2.get_mouse_position() - b2_position_to_k2_position(player_position)

	if k2.mouse_button_went_down(.Left) {
		direction_normalized := linalg.normalize0(direction)
		if direction != {0, 0} { 	// Dir == 0,0 happens if you click exaclty on the player position.
			k2.play_sound(sounds.Shoot_2)
			velocity := direction * BULLET_SPEED
			append(&gameState.entities, create_bullet(GetPlayerMuzzlePosition(), velocity))
			b2.Body_SetUserData(
				gameState.entities[len(gameState.entities) - 1].body_id,
				cast(rawptr)&gameState.entities[len(gameState.entities) - 1],
			)
		}
	}

	gameState.player.gunAngle = math.atan2(direction.y, direction.x)
}

DrawPlayer :: proc() {
	if gameState.player == nil {
		return
	}
	player_position := b2_position_to_k2_position(b2.Body_GetPosition(gameState.player.body_id))
	player_rotation := b2.Body_GetRotation(gameState.player.body_id)
	player_angle := math.atan2(player_rotation.s, player_rotation.c)
	k2.draw_rect(
		k2.Rect{player_position.x, player_position.y, PLAYER_VEHICLE_WIDTH, PLAYER_VEHICLE_HEIGHT},
		k2.DARK_BLUE,
		{PLAYER_VEHICLE_WIDTH / 2, PLAYER_VEHICLE_HEIGHT / 2},
		-player_angle,
	)
	k2.draw_circle(player_position, 32.0, k2.Color{7, 47, 132, 255})
	k2.draw_circle(GetPlayerMuzzlePosition(), 4.0, k2.Color{7, 47, 132, 255})
}

DrawHUD :: proc() {
	window_size := k2.get_window_scale() * Vec2{WINDOW_WIDTH, WINDOW_HEIGHT}
	if gameState.player != nil {
		max_width: f32 = 400
		x := window_size.x / 2 - max_width / 2
		k2.draw_rect(k2.Rect{x, 40, max_width, 45}, k2.BLACK)
		k2.draw_rect(
			k2.Rect {
				x,
				40,
				max_width * (gameState.player.currentHealth / gameState.player.maxHealth),
				45,
			},
			k2.DARK_RED,
		)
	} else {
		k2.draw_text("Game Over!", window_size / 2, 48, k2.LIGHT_RED)
		k2.draw_text("Press R to restart.", window_size / 2 + {0, 50}, 16, k2.LIGHT_RED)
	}
}

GetPlayerMuzzlePosition :: proc() -> Vec2 {
	assert(gameState.player != nil) // we should not be calling this if the player is nil.
	if gameState.player == nil {
		return {0, 0}
	}
	player_position := b2_position_to_k2_position(b2.Body_GetPosition(gameState.player.body_id))
	return Vec2 {
		player_position.x + math.cos(gameState.player.gunAngle) * 32,
		player_position.y + math.sin(gameState.player.gunAngle) * 32,
	}
}

DrawCrosshair :: proc() {
	src := k2.get_texture_rect(textures.crosshair)
	dst := k2.Rect {
		x = k2.get_mouse_position().x - 256 / 8,
		y = k2.get_mouse_position().y - 256 / 8,
		w = src.w / 8,
		h = src.h / 8,
	}
	k2.draw_texture_fit(textures.crosshair, src, dst)
}

step :: proc() -> bool {
	if !k2.update() {
		return false
	}

	dt := k2.get_frame_time()
	time_acc += dt

	// Game over. Handle restarting.
	if gameState.player == nil {
		if k2.key_went_down(k2.Keyboard_Key.R) {
			// TODO have proper delete everything procedure.
			// Would make sense to call that in shutdown, too. Or maybe just call shutdown here?
			for &entity in gameState.entities {
				destroy_entity(&entity)
			}
			delete(gameState.entities)
			InitGameState()
		}
	}

	enemy_count: i32
	// Move enemies towards the target and count enemies
	for &entity in gameState.entities {
		if entity.type == .Enemy {
			enemy_count += 1
			if gameState.player != nil {
				b2_player_position := b2.Body_GetPosition(gameState.player.body_id)
				direction := linalg.normalize0(
					b2_player_position - b2.Body_GetPosition(entity.body_id),
				)
				b2.Body_SetLinearVelocity(entity.body_id, direction * ENEMY_SPEED)
			}
		} else if entity.type == .Bullet {
			// TODO handle bullet lifetime here, destroy when too old.
		}
	}

	// Spawn new enemies, based on time, at random positions
	if enemy_count < NUM_MAX_ENEMIES &&
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
				if entityA.type == .Bullet && entityB.type == .Enemy {
					fmt.println("Hit event between bullet and enemy, at time: ", k2.get_time())
					destroy_entity(entityA)
					on_bullet_hits_enemy(entityB)
				} else if entityA.type == .Enemy && entityB.type == .Bullet {
					fmt.println("Hit event between bullet and enemy, at time: ", k2.get_time())
					on_bullet_hits_enemy(entityA)
					destroy_entity(entityB)
				} else if entityA.type == .Enemy && entityB.type == .Player {
					fmt.println("Hit event between player and enemy, at time: ", k2.get_time())
					DamagePlayer(7)
					destroy_entity(entityA)
				} else if entityA.type == .Player && entityB.type == .Enemy {
					fmt.println("Hit event between player and enemy, at time: ", k2.get_time())
					DamagePlayer(7)
					destroy_entity(entityB)
				}
			}
		}
	}

	UpdatePlayer()

	k2.clear(k2.GREEN)
	defer k2.present()

	// Drawing
	DrawPlayer()
	DrawCrosshair()

	for entity in gameState.entities {
		switch entity.type {
		case .Enemy:
			k2.draw_circle(
				b2_position_to_k2_position(b2.Body_GetPosition(entity.body_id)),
				ENEMY_RADIUS,
				k2.DARK_GRAY,
			)
		case .Bullet:
			k2.draw_circle(
				b2_position_to_k2_position(b2.Body_GetPosition(entity.body_id)),
				BULLET_RADIUS,
				k2.RED,
			)
		case .Player:
		//player is handled separately.
		}

		// Draw contact points. For debugging.
		{
			contactData: [100]b2.ContactData
			contactDataSlice := b2.Body_GetContactData(entity.body_id, contactData[:])
			for i in 0 ..< len(contactDataSlice) {
				for j in 0 ..< contactDataSlice[i].manifold.pointCount {
					point := contactDataSlice[i].manifold.points[j]
					b2_location := k2_position_to_b2_position(point.point)
					k2.draw_circle(
						b2_position_to_k2_position(b2.Body_GetPosition(entity.body_id)),
						1,
						k2.YELLOW,
					)
				}
			}
		}
	}

	DrawHUD()

	return true
}

shutdown :: proc() {
	delete(gameState.entities)
}

create_enemy :: proc() -> Entity {
	x := rand.float32_range(0, WINDOW_WIDTH) // TODO set sense making range
	y := rand.float32_range(0, WINDOW_HEIGHT) // TODO set sense making range
	random_position := Vec2{x, y}

	// Avoid spawning too close to the player. Attempts is used to avoid an endless loop.
	if gameState.player != nil {
		attempts: i32 = 1000
		player_position := k2_position_to_b2_position(
			b2.Body_GetPosition(gameState.player.body_id),
		)
		for attempts > 0 &&
		    linalg.length(player_position - random_position) <
			    ENEMY_MINIMUM_SPAWN_DISTANCE_FROM_PLAYEER {
			x = rand.float32_range(0, WINDOW_WIDTH)
			y = rand.float32_range(0, WINDOW_HEIGHT)
			random_position = Vec2{x, y}
			attempts -= 1
		}
	}

	body_def := b2.DefaultBodyDef()
	body_def.type = .dynamicBody
	body_def.position = k2_position_to_b2_position(random_position)
	body_id := b2.CreateBody(world_id, body_def)

	shape_def := b2.DefaultShapeDef()
	shape_def.density = 1000
	shape_def.material.friction = 0.3
	shape_def.enableContactEvents = true
	shape_def.enableHitEvents = true

	circle: b2.Circle
	circle.radius = ENEMY_RADIUS
	_ = b2.CreateCircleShape(body_id, shape_def, circle)

	return Entity {
		type = .Enemy,
		body_id = body_id,
		maxHealth = ENEMY_MAX_HEALTH,
		currentHealth = ENEMY_MAX_HEALTH,
	}
}

create_bullet :: proc(position: Vec2, velocity: Vec2) -> Entity {
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
	circle.radius = BULLET_RADIUS
	_ = b2.CreateCircleShape(body_id, shape_def, circle)

	return Entity{type = .Bullet, body_id = body_id}
}

create_player :: proc(position: Vec2) -> Entity {
	body_def := b2.DefaultBodyDef()
	body_def.type = .dynamicBody
	body_def.position = k2_position_to_b2_position(position)
	body_id := b2.CreateBody(world_id, body_def)

	shape_def := b2.DefaultShapeDef()
	shape_def.density = 10000
	shape_def.material.friction = 0.3
	shape_def.enableContactEvents = true
	shape_def.enableHitEvents = true

	box := b2.MakeBox(PLAYER_VEHICLE_WIDTH / 2, PLAYER_VEHICLE_HEIGHT / 2)
	_ = b2.CreatePolygonShape(body_id, shape_def, box)

	return Entity {
		type = .Player,
		body_id = body_id,
		maxHealth = PLAYER_MAX_HEALTH,
		currentHealth = PLAYER_MAX_HEALTH,
	}
}

destroy_entity :: proc(entity_ptr: ^Entity) {
	assert(entity_ptr != nil)
	fmt.println("Destroying entity. Type: ", entity_ptr.type)
	for &entity, i in gameState.entities {
		if &entity == entity_ptr {
			b2.DestroyBody(entity.body_id)
			unordered_remove(&gameState.entities, i)
			fmt.println("Found the entity and removed it from the array.")
		}
	}
	// TODO: recreating all the userdata pointers whenever we destroy an entity. very silly, should use some kind of stable ID system.
	for &entity in gameState.entities {
		b2.Body_SetUserData(entity.body_id, cast(rawptr)&entity)
	}
}

on_bullet_hits_enemy :: proc(entity_ptr: ^Entity) {
	assert(entity_ptr != nil && entity_ptr.type == .Enemy)
	entity_ptr.currentHealth -= BULLET_DAMAGE
	if entity_ptr.currentHealth <= 0 {
		destroy_entity(entity_ptr)
	}
}

DamagePlayer :: proc(damage: f32) {
	assert(gameState.player != nil)
	gameState.player.currentHealth = math.clamp(
		gameState.player.currentHealth - damage,
		0,
		gameState.player.maxHealth,
	)
	if gameState.player.currentHealth <= 0 {
		fmt.println("Destroying player entity.")
		destroy_entity(gameState.player)
		gameState.player = nil
	}
}

k2_position_to_b2_position :: proc(position: Vec2) -> b2.Vec2 {
	return b2.Vec2{position.x, -position.y}
}

b2_position_to_k2_position :: proc(position: b2.Vec2) -> b2.Vec2 {
	return Vec2{position.x, -position.y}
}

GameState :: struct {
	player:                ^Entity,
	entities:              [dynamic]Entity,
	last_enemy_spawn_time: f64,
}

Entity_Type :: enum {
	Player,
	Enemy,
	Bullet,
}

Entity :: struct {
	type:          Entity_Type,
	body_id:       b2.BodyId,
	//Player data:
	gunAngle:      f32,
	//Player and zombie:
	maxHealth:     f32,
	currentHealth: f32,
}
