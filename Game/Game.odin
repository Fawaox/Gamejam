package Game

import k2 "../karl2d"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import b2 "vendor:box2d"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

PIXELS_PER_METER :: 30.0

DRAW_DEBUG :: false

PHYICS_SUB_STEPS :: 4
PHYSICS_TIME_STEP :: 1.0 / 60

NUM_MAX_ENEMIES :: 10
ENEMY_SPAWN_INTERVAL_SECONDS :: 0.01
ENEMY_SPEED :: 10.0 / PIXELS_PER_METER
ENEMY_RADIUS :: 14.0 / PIXELS_PER_METER
ENEMY_MAX_HEALTH :: 100
ENEMY_MINIMUM_SPAWN_DISTANCE_FROM_PLAYER :: 300.0 / PIXELS_PER_METER

BULLET_RADIUS :: 5.0 / PIXELS_PER_METER
BULLET_SPEED :: 100.0 / PIXELS_PER_METER
BULLET_LIFETIME_SECONDS :: 3 // TODO destroy bullets after a while.
BULLET_DAMAGE :: 101 // Yeah, this might have been pointless. Made zombies have health. In case we want them to take more than 1 shot.

// Jeep textue is 94 * 50
PLAYER_VEHICLE_WIDTH :: 50.0 * 1.3 / PIXELS_PER_METER
PLAYER_VEHICLE_HEIGHT :: 94.0 * 1.3 / PIXELS_PER_METER
PLAYER_VEHICLE_COLOR :: k2.Color{223, 86, 86, 255} // Color from jeep.png
PLAYER_VEHICLE_COLOR_SLIGHTLY_DARKER :: k2.Color{183, 46, 46, 255}
PLAYER_GUN_RADIUS :: 16.0 / PIXELS_PER_METER
PLAYER_MAX_HEALTH :: 100
PLAYER_FORWARD_FORCE :: 10000.0 // TODO tweak numbers
PLAYER_BACKWARD_FORCE :: PLAYER_FORWARD_FORCE * 0.9
PLAYER_ROTATION_FORCE :: 6000.0
PLAYER_TURN_IDEAL_SPEED :: 5.0 // Couldn't think of a good name. At speeds below this, we will scale down the ability to turn.

PLAYER_DEFAULT_AMMO :: 9
NUM_MAX_CRATES :: 1
CRATE_AMMO :: 6
CRATE_SIZE :: 20.0 / PIXELS_PER_METER
CRATE_MAX_HEALTH :: 102
CRATE_HEALTH :: 40

Vec2 :: k2.Vec2

// Global Variables
screenCenter: Vec2
gameState: GameState
textures: Textures
sounds: Sounds

// Structs
Textures :: struct {
	crosshair:    k2.Texture,
	jeep:         k2.Texture,
	car:          k2.Texture,
	bullet:       k2.Texture,
	crate_ammo:   k2.Texture,
	crate_health: k2.Texture,
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

	//b2.SetLengthUnitsPerMeter(1) // TODO does this make sense?
	world_def := b2.DefaultWorldDef()
	world_def.gravity = b2.Vec2{0, 0}
	world_id = b2.CreateWorld(world_def)

	screenCenter = k2.get_window_scale() * Vec2{WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2} // wait maybe remove getwindowscale here and only do when drawing

	screen_width := k2.get_window_scale() * WINDOW_WIDTH
	screen_height := k2.get_window_scale() * WINDOW_HEIGHT
	screen_half_width := screen_width / 2
	screen_half_height := screen_height / 2
	blocking_volume_thickness: f32 = 200.0
	blocking_volume_half_thickness := blocking_volume_thickness / 2
	create_blocking_volume(
		{-blocking_volume_half_thickness, screen_half_height},
		{blocking_volume_thickness, screen_height},
	)
	create_blocking_volume(
		{screen_width + blocking_volume_half_thickness, screen_half_height},
		{blocking_volume_thickness, screen_height},
	)
	create_blocking_volume(
		{screen_half_width, -blocking_volume_half_thickness},
		{screen_width, blocking_volume_thickness},
	)
	create_blocking_volume(
		{screen_half_width, screen_height + blocking_volume_half_thickness},
		{screen_width, blocking_volume_thickness},
	)

	LoadTextures()
	LoadSounds()
	InitGameState()
}

LoadTextures :: proc() {
	textures.crosshair = k2.load_texture_from_bytes(#load("../assets/crosshair.png"))
	textures.car = k2.load_texture_from_bytes(#load("../assets/Car_1_Gray.png"))
	textures.bullet = k2.load_texture_from_bytes(#load("../assets/Pistol-Bullet.png"))
	textures.jeep = k2.load_texture_from_bytes(#load("../assets/Jeep.png"))
	textures.crate_ammo = k2.load_texture_from_bytes(#load("../assets/crateWood.png"))
	textures.crate_health = k2.load_texture_from_bytes(#load("../assets/crateWood_Health.png"))
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

	gameState.gameStartTime = k2.get_time()
	gameState.currentAmmo = PLAYER_DEFAULT_AMMO
}

GetLongitudinalVelocity :: proc(body_id: b2.BodyId) -> b2.Vec2 {
	vel := b2.Body_GetLinearVelocity(gameState.player.body_id)
	forward := b2.Body_GetWorldVector(gameState.player.body_id, b2.Vec2{0, 1})
	longitudinal_speed := linalg.dot(vel, forward)
	longitudina_vel := forward * longitudinal_speed
	return longitudina_vel

	// vel := b2.Body_GetLinearVelocity(gameState.player.body_id)
	// local_velocity := b2.Body_GetLocalVector(gameState.player.body_id, vel)
	// return b2.Vec2{0, local_velocity.y}
}

GetLateralVelocity :: proc(body_id: b2.BodyId) -> b2.Vec2 {
	vel := b2.Body_GetLinearVelocity(gameState.player.body_id)
	right := b2.Body_GetWorldVector(gameState.player.body_id, b2.Vec2{1, 0})
	lateral_speed := linalg.dot(vel, right)
	lateral_vel := right * lateral_speed
	return lateral_vel

	// vel := b2.Body_GetLinearVelocity(gameState.player.body_id)
	// local_velocity := b2.Body_GetLocalVector(gameState.player.body_id, vel)
	// return b2.Vec2{local_velocity.x, 0}
}

UpdatePlayerPhysics :: proc() {
	if gameState.player == nil {
		return
	}

	// Apply desired acceleration and turning.
	local_force_vector := k2.Vec2{0, gameState.player_foward_force * PHYSICS_TIME_STEP}
	rot := b2.Body_GetRotation(gameState.player.body_id)
	world_force_vector := b2.RotateVector(rot, local_force_vector)
	b2.Body_ApplyForceToCenter(gameState.player.body_id, world_force_vector, true)

	speed := GetLongitudinalVelocity(gameState.player.body_id).y
	torque_factor := math.clamp(math.abs(speed) / PLAYER_TURN_IDEAL_SPEED, 0, 1)
	b2.Body_ApplyTorque(
		gameState.player.body_id,
		gameState.player_torque * PHYSICS_TIME_STEP * torque_factor,
		true,
	)

	// Reduce sideways sliding.
	{
		vel := b2.Body_GetLinearVelocity(gameState.player.body_id)
		side_speed := b2.Body_GetLocalVector(gameState.player.body_id, vel).x
		instant_side_accel := -side_speed / PHYSICS_TIME_STEP
		mass := b2.Body_GetMass(gameState.player.body_id)
		side_force := instant_side_accel * mass
		side_direction := b2.Body_GetWorldVector(gameState.player.body_id, {1, 0})
		b2.Body_ApplyForceToCenter(gameState.player.body_id, side_direction * side_force, true)
	}
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

	speed :=
		b2.Body_GetLocalVector(gameState.player.body_id, GetLongitudinalVelocity(gameState.player.body_id)).y
	changing_direction: bool
	player_foward_force: f32
	player_torque: f32
	if k2.key_is_held(k2.Keyboard_Key.W) {
		// If we're moving backwards, we use braking force, which is higher.
		if speed < 0 {
			changing_direction = true
		}
		//player_foward_force += PLAYER_BRAKING_FORCE
		//} else {
		player_foward_force += PLAYER_FORWARD_FORCE
		//}
	}
	if k2.key_is_held(k2.Keyboard_Key.S) {
		// If we're moving forwards, we use braking force, which is higher.
		if speed > 0 {
			changing_direction = true
		}
		//player_foward_force -= PLAYER_BRAKING_FORCE
		//} else {
		player_foward_force -= PLAYER_BACKWARD_FORCE
		//}
	}
	if k2.key_is_held(k2.Keyboard_Key.A) {
		player_torque += PLAYER_ROTATION_FORCE
	}
	if k2.key_is_held(k2.Keyboard_Key.D) {
		player_torque -= PLAYER_ROTATION_FORCE
	}

	b2.Body_SetLinearDamping(gameState.player.body_id, changing_direction ? 0.99 : 0.3)

	// Rotate the other way, if we're tryimg to go backwards.
	if speed < 0 {
		player_torque *= -1
	}
	if changing_direction {
		player_torque = 0 // Only turn if we are already going in the desired direction.
	}

	gameState.player_foward_force = player_foward_force
	gameState.player_torque = player_torque

	player_position := b2.Body_GetPosition(gameState.player.body_id)

	direction: Vec2 = k2.get_mouse_position() - b2_position_to_k2_position(player_position)

	if k2.mouse_button_went_down(.Left) && gameState.currentAmmo > 0 {
		direction_normalized := linalg.normalize0(direction)
		if direction != {0, 0} { 	// Dir == 0,0 happens if you click exaclty on the player position.
			k2.play_sound(sounds.Shoot_2)
			velocity := direction * BULLET_SPEED
			append(&gameState.entities, create_bullet(GetPlayerMuzzlePosition(), velocity))
			b2.Body_SetUserData(
				gameState.entities[len(gameState.entities) - 1].body_id,
				cast(rawptr)&gameState.entities[len(gameState.entities) - 1],
			)
			gameState.currentAmmo -= 1
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
	// k2.draw_rect(
	// 	k2.Rect {
	// 		player_position.x,
	// 		player_position.y,
	// 		PLAYER_VEHICLE_WIDTH * PIXELS_PER_METER,
	// 		PLAYER_VEHICLE_HEIGHT * PIXELS_PER_METER,
	// 	},
	// 	k2.DARK_BLUE,
	// 	{PLAYER_VEHICLE_WIDTH / 2, PLAYER_VEHICLE_HEIGHT / 2},
	// 	-player_angle,
	// )
	src := k2.get_texture_rect(textures.jeep)
	dst := k2.Rect {
		player_position.x,
		player_position.y,
		PLAYER_VEHICLE_WIDTH * PIXELS_PER_METER,
		PLAYER_VEHICLE_HEIGHT * PIXELS_PER_METER,
	}
	k2.draw_texture_fit(
		textures.jeep,
		src,
		dst,
		{
			PLAYER_VEHICLE_WIDTH * PIXELS_PER_METER / 2,
			PLAYER_VEHICLE_HEIGHT * PIXELS_PER_METER / 2,
		},
		-player_angle,
	)

	k2.draw_circle(
		player_position,
		PLAYER_GUN_RADIUS * PIXELS_PER_METER,
		PLAYER_VEHICLE_COLOR_SLIGHTLY_DARKER,
	)
	k2.draw_circle(
		player_position,
		PLAYER_GUN_RADIUS * 0.9 * PIXELS_PER_METER,
		PLAYER_VEHICLE_COLOR,
	)
	k2.draw_circle(GetPlayerMuzzlePosition(), 4.0, PLAYER_VEHICLE_COLOR_SLIGHTLY_DARKER)

	// Some debug drawing.
	if DRAW_DEBUG {
		k2.draw_line(
			player_position,
			player_position +
			b2_position_to_k2_position(GetLongitudinalVelocity(gameState.player.body_id)),
			2,
			k2.YELLOW,
		)
		k2.draw_line(
			player_position,
			player_position +
			b2_position_to_k2_position(GetLateralVelocity(gameState.player.body_id)),
			2,
			k2.BLUE,
		)
	}
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
		vel := b2.Body_GetLinearVelocity(gameState.player.body_id)
		speed := linalg.length(vel)
		k2.draw_text(
			fmt.tprintf(
				"Speed: %0.0fkmh | Survival Time: %0.0f | Ammo: %d",
				speed * 3.6,
				k2.get_time() - gameState.gameStartTime,
				gameState.currentAmmo,
			),
			{0, window_size.y - 30},
			30,
			k2.WHITE,
		)
	} else {
		k2.draw_text("Game Over!", window_size / 2, 48, k2.LIGHT_RED)
		k2.draw_text("Press R to restart.", window_size / 2 + {0, 50}, 16, k2.LIGHT_RED)
	}
}

DrawGrid :: proc() {
	for x := -1000; x < 1000; x += 1 {
		k2.draw_line(
			b2_position_to_k2_position({cast(f32)x, 0}),
			b2_position_to_k2_position({cast(f32)x, -WINDOW_HEIGHT}),
			1,
			k2.DARK_GRAY,
		)
	}
	for y := -1000; y < 1000; y += 1 {
		k2.draw_line(
			b2_position_to_k2_position({0, cast(f32)y}),
			b2_position_to_k2_position({WINDOW_WIDTH, cast(f32)y}),
			1,
			k2.DARK_GREEN,
		)
	}
}

GetPlayerMuzzlePosition :: proc() -> Vec2 {
	assert(gameState.player != nil) // we should not be calling this if the player is nil.
	if gameState.player == nil {
		return {0, 0}
	}
	player_position := b2_position_to_k2_position(b2.Body_GetPosition(gameState.player.body_id))
	return Vec2 {
		player_position.x +
		math.cos(gameState.player.gunAngle) * PLAYER_GUN_RADIUS * PIXELS_PER_METER,
		player_position.y +
		math.sin(gameState.player.gunAngle) * PLAYER_GUN_RADIUS * PIXELS_PER_METER,
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
	crate_count: i32
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
			} else {
				b2.Body_SetLinearVelocity(entity.body_id, 0)
			}
		} else if entity.type == .Bullet {
			// TODO handle bullet lifetime here, destroy when too old.
		} else if entity.type == .CrateAmmo || entity.type == .CrateHealth {
			crate_count += 1
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

	if crate_count < NUM_MAX_CRATES {
		x := rand.float32_range(0, WINDOW_WIDTH) // TODO set sense making range
		y := rand.float32_range(0, WINDOW_HEIGHT) // TODO set sense making range
		random_position := Vec2{x, y}
		make_ammo_crate := rand.int31() % 2 == 1
		if make_ammo_crate {
			append(&gameState.entities, create_crate_ammo(random_position))
		} else {
			append(&gameState.entities, create_crate_health(random_position))
		}
		b2.Body_SetUserData(
			gameState.entities[len(gameState.entities) - 1].body_id,
			cast(rawptr)&gameState.entities[len(gameState.entities) - 1],
		)
	}

	pos := k2.get_mouse_position()

	for time_acc >= PHYSICS_TIME_STEP {
		b2.World_Step(world_id, PHYSICS_TIME_STEP, PHYICS_SUB_STEPS)
		time_acc -= PHYSICS_TIME_STEP

		UpdatePlayerPhysics()

		// TODO react to events here. Having a problem with figuring out the speed of hit events, atm.
		contactEvents := b2.World_GetContactEvents(world_id)
		for i in 0 ..< contactEvents.beginCount {
			//fmt.println("begin event, game time: ", k2.get_time())
		}
		for i in 0 ..< contactEvents.endCount {
		}
		for i in 0 ..< contactEvents.hitCount {
			hitEvent := contactEvents.hitEvents[i]
			if hitEvent.approachSpeed > 1 {
				//fmt.println("hit event; speed:", hitEvent.approachSpeed)
				shapeA := hitEvent.shapeIdA
				shapeB := hitEvent.shapeIdB
				bodyA := b2.Shape_GetBody(shapeA)
				bodyB := b2.Shape_GetBody(shapeB)
				dataA := b2.Body_GetUserData(bodyA)
				dataB := b2.Body_GetUserData(bodyB)
				if dataA == nil || dataB == nil {
					continue // user data is nil for the blocking volumes on the outsides.
				}
				entityA := cast(^Entity)dataA
				entityB := cast(^Entity)dataB
				if entityA.type == .Bullet && entityB.type == .Enemy {
					fmt.println("Hit event between bullet and enemy, at time: ", k2.get_time())
					bullet_enemy_hit(entityA, entityB)
				} else if entityA.type == .Enemy && entityB.type == .Bullet {
					fmt.println("Hit event between bullet and enemy, at time: ", k2.get_time())
					bullet_enemy_hit(entityB, entityA)
				} else if entityA.type == .Enemy && entityB.type == .Player {
					if hitEvent.approachSpeed > 15 {
						fmt.println("Hit event between player and enemy, at time: ", k2.get_time())
						player_enemy_hit(entityB, entityA)
					}
				} else if entityA.type == .Player && entityB.type == .Enemy {
					if hitEvent.approachSpeed > 15 {
						fmt.println("Hit event between player and enemy, at time: ", k2.get_time())
						player_enemy_hit(entityA, entityB)
					}
				} else if entityA.type == .CrateHealth && entityB.type == .Player {
					if hitEvent.approachSpeed > 1 {
						fmt.println(
							"Hit event between player and CrateHealth, at time: ",
							k2.get_time(),
						)
						player_crate_health_hit(entityB, entityA)
					}
				} else if entityA.type == .Player && entityB.type == .CrateHealth {
					if hitEvent.approachSpeed > 1 {
						fmt.println(
							"Hit event between player and CrateHealth, at time: ",
							k2.get_time(),
						)
						player_crate_health_hit(entityA, entityB)
					}
				} else if entityA.type == .CrateAmmo && entityB.type == .Player {
					if hitEvent.approachSpeed > 1 {
						fmt.println(
							"Hit event between player and CrateAmmo, at time: ",
							k2.get_time(),
						)
						player_crate_ammo_hit(entityB, entityA)
					}
				} else if entityA.type == .Player && entityB.type == .CrateAmmo {
					if hitEvent.approachSpeed > 1 {
						fmt.println(
							"Hit event between player and CrateAmmo, at time: ",
							k2.get_time(),
						)
						player_crate_ammo_hit(entityA, entityB)
					}
				} else {
					fmt.println("Hit event being ignored, at time: ", k2.get_time())
				}
			}
		}
	}

	UpdatePlayer()

	k2.clear(k2.GREEN)
	defer k2.present()

	// Drawing
	DrawGrid()
	DrawPlayer()
	DrawCrosshair()

	for entity in gameState.entities {
		switch entity.type {
		case .Enemy:
			k2.draw_circle(
				b2_position_to_k2_position(b2.Body_GetPosition(entity.body_id)),
				ENEMY_RADIUS * PIXELS_PER_METER,
				k2.DARK_GRAY,
			)
		case .Bullet:
			k2.draw_circle(
				b2_position_to_k2_position(b2.Body_GetPosition(entity.body_id)),
				BULLET_RADIUS * PIXELS_PER_METER,
				k2.RED,
			)
		case .Player:
		//player is handled separately.
		case .CrateAmmo:
			src := k2.get_texture_rect(textures.crate_ammo)
			position := b2_position_to_k2_position(b2.Body_GetPosition(entity.body_id))
			dst := k2.Rect {
				position.x,
				position.y,
				CRATE_SIZE * PIXELS_PER_METER,
				CRATE_SIZE * PIXELS_PER_METER,
			}
			k2.draw_texture_fit(
				textures.crate_ammo,
				src,
				dst,
				{CRATE_SIZE * PIXELS_PER_METER / 2, CRATE_SIZE * PIXELS_PER_METER / 2},
				0,
			)
		case .CrateHealth:
			src := k2.get_texture_rect(textures.crate_health)
			position := b2_position_to_k2_position(b2.Body_GetPosition(entity.body_id))
			dst := k2.Rect {
				position.x,
				position.y,
				CRATE_SIZE * PIXELS_PER_METER,
				CRATE_SIZE * PIXELS_PER_METER,
			}
			k2.draw_texture_fit(
				textures.crate_health,
				src,
				dst,
				{CRATE_SIZE * PIXELS_PER_METER / 2, CRATE_SIZE * PIXELS_PER_METER / 2},
				0,
			)
		}

		// Draw contact points. For debugging.\
		if DRAW_DEBUG {
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
	free_all(context.temp_allocator)
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
		attempts: i32 = 100000
		player_position := b2_position_to_k2_position(
			b2.Body_GetPosition(gameState.player.body_id),
		)
		for attempts > 0 &&
		    linalg.length(player_position - random_position) <
			    ENEMY_MINIMUM_SPAWN_DISTANCE_FROM_PLAYER * PIXELS_PER_METER {
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
	shape_def.density = 1 //000
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
	shape_def.density = 1 //000
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
	body_def.isBullet = true
	body_def.angularDamping = 0.99
	body_def.linearDamping = 0.3
	body_id := b2.CreateBody(world_id, body_def)

	shape_def := b2.DefaultShapeDef()
	shape_def.density = 1
	shape_def.material.friction = 0.1
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

create_crate_ammo :: proc(position: Vec2) -> Entity {
	body_def := b2.DefaultBodyDef()
	body_def.type = .dynamicBody
	body_def.position = k2_position_to_b2_position(position)
	body_def.angularDamping = 0.99
	body_def.linearDamping = 0.9
	body_id := b2.CreateBody(world_id, body_def)

	shape_def := b2.DefaultShapeDef()
	shape_def.density = 2
	shape_def.material.friction = 0.9
	shape_def.enableContactEvents = true
	shape_def.enableHitEvents = true

	box := b2.MakeBox(CRATE_SIZE / 2, CRATE_SIZE / 2)
	_ = b2.CreatePolygonShape(body_id, shape_def, box)

	return Entity {
		type = .CrateAmmo,
		body_id = body_id,
		maxHealth = CRATE_MAX_HEALTH,
		currentHealth = CRATE_MAX_HEALTH,
	}
}

create_crate_health :: proc(position: Vec2) -> Entity {
	body_def := b2.DefaultBodyDef()
	body_def.type = .dynamicBody
	body_def.position = k2_position_to_b2_position(position)
	body_def.angularDamping = 0.99
	body_def.linearDamping = 0.99
	body_id := b2.CreateBody(world_id, body_def)

	shape_def := b2.DefaultShapeDef()
	shape_def.density = 2
	shape_def.material.friction = 0.9
	shape_def.enableContactEvents = true
	shape_def.enableHitEvents = true

	box := b2.MakeBox(CRATE_SIZE / 2, CRATE_SIZE / 2)
	_ = b2.CreatePolygonShape(body_id, shape_def, box)

	return Entity {
		type = .CrateHealth,
		body_id = body_id,
		maxHealth = CRATE_MAX_HEALTH,
		currentHealth = CRATE_MAX_HEALTH,
	}
}

create_blocking_volume :: proc(position: Vec2, size: Vec2) {
	body_def := b2.DefaultBodyDef()
	body_def.type = .staticBody
	body_def.position = k2_position_to_b2_position(position)
	body_id := b2.CreateBody(world_id, body_def)

	shape_def := b2.DefaultShapeDef()
	shape_def.material.friction = 0.1

	size_b2 := size / PIXELS_PER_METER
	box := b2.MakeBox(size_b2.x / 2, size_b2.y / 2)
	_ = b2.CreatePolygonShape(body_id, shape_def, box)
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

bullet_enemy_hit :: proc(bullet: ^Entity, enemy: ^Entity) {
	assert(enemy != nil && enemy.type == .Enemy)
	enemy.currentHealth -= BULLET_DAMAGE
	if enemy.currentHealth <= 0 {
		destroy_entity(enemy)
	}
	destroy_entity(bullet)
}

player_enemy_hit :: proc(player: ^Entity, enemy: ^Entity) {
	DamagePlayer(7)
	destroy_entity(enemy)
}

player_crate_health_hit :: proc(player: ^Entity, crate: ^Entity) {
	destroy_entity(crate)
	gameState.player.currentHealth = math.clamp(
		gameState.player.currentHealth + CRATE_HEALTH,
		0,
		PLAYER_MAX_HEALTH,
	)
}

player_crate_ammo_hit :: proc(player: ^Entity, crate: ^Entity) {
	destroy_entity(crate)
	gameState.currentAmmo += CRATE_AMMO
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
	return b2.Vec2{position.x, -position.y} / PIXELS_PER_METER
}

b2_position_to_k2_position :: proc(position: b2.Vec2) -> b2.Vec2 {
	return Vec2{position.x, -position.y} * PIXELS_PER_METER
}

GameState :: struct {
	player:                ^Entity,
	entities:              [dynamic]Entity,
	last_enemy_spawn_time: f64,
	player_foward_force:   f32,
	player_torque:         f32,
	gameStartTime:         f64,
	currentAmmo:           i32,
}

Entity_Type :: enum {
	Player,
	Enemy,
	Bullet,
	CrateAmmo,
	CrateHealth,
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
