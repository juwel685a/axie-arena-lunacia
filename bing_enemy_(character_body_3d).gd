extends CharacterBody3D

# ============================================================
# BING ENEMY
# ============================================================

@export_category("Movement")
@export var move_speed: float = 2.5
@export var acceleration: float = 12.0
@export var rotation_speed: float = 8.0
@export var gravity: float = 16.0
@export var jump_velocity: float = 5.0

@export_category("AI Range")
@export var chase_distance: float = 10.0
@export var wander_area: float = 6.0
@export var wander_speed: float = 1.2
@export var wander_wait_time: float = 3.0

@export_category("Obstacle Avoidance")
@export var obstacle_check_distance: float = 2.2
@export var obstacle_side_distance: float = 2.0
@export var obstacle_look_height: float = 1.0
@export var obstacle_turn_strength: float = 0.85

@export_category("Obstacle Jump")
@export var enable_obstacle_jump: bool = true
@export var max_jump_attempts: int = 3
@export var jump_attempt_cooldown: float = 2.0
@export var unreachable_check_time: float = 6.0
@export var minimum_progress_distance: float = 0.8

@export_category("Unreachable Waiting")
@export var unreachable_wander_radius: float = 4.0
@export var unreachable_wander_speed: float = 1.0
@export var unreachable_wait_time: float = 1.5

@export_category("Health")
@export var max_health: float = 200.0
@export var blood_start_health: float = 120.0
@export var heavy_blood_health: float = 60.0
@export var blood_damage_threshold: float = 40.0
@export var blood_cooldown: float = 0.25

@export_category("Combat")
@export var attack_damage: float = 10.0
@export var skill_damage: float = 15.0
@export var attack_distance: float = 1.8
@export var attack_angle_degrees: float = 50.0
@export var skill_distance: float = 1.5
@export var skill_angle_degrees: float = 60.0
@export var attack_cooldown: float = 1.2
@export var skill_cooldown: float = 10.0
@export var attack_hit_start: float = 0.20
@export var attack_hit_duration: float = 0.15
@export var skill_hit_start: float = 0.30
@export var skill_hit_duration: float = 0.20

@export_category("Knockback")
@export var knockback_stun_time: float = 0.6

@export_category("Drops")
@export var hp_pickup_value: float = 70.0


var animation_player: AnimationPlayer

var hit_sound: AudioStreamPlayer3D
var attack_sound: AudioStreamPlayer3D
var skill_sound: AudioStreamPlayer3D

var player: Node3D

var current_health: float = 200.0
var damage_accumulator: float = 0.0
var blood_timer: float = 0.0

var attack_timer: float = 0.0
var skill_timer: float = 0.0
var stun_timer: float = 0.0

var is_dead: bool = false
var is_attacking: bool = false
var is_using_skill: bool = false


# ============================================================
# NORMAL SQUARE WANDER
# ============================================================

var home_position: Vector3
var wander_target: Vector3
var wander_timer: float = 0.0
var has_wander_target: bool = false

var wander_points: Array[Vector3] = []
var wander_point_index: int = 0
var wander_points_initialized: bool = false


# ============================================================
# OBSTACLE AVOIDANCE
# ============================================================

var obstacle_avoid_direction: Vector3 = Vector3.ZERO
var obstacle_avoid_timer: float = 0.0


# ============================================================
# OBSTACLE JUMP SYSTEM
# ============================================================

var jump_attempts: int = 0
var jump_timer: float = 0.0

var blocked_timer: float = 0.0
var progress_start_position: Vector3

var was_obstacle_blocked: bool = false


# ============================================================
# UNREACHABLE PLAYER SYSTEM
# ============================================================

var player_unreachable: bool = false

var unreachable_timer: float = 0.0
var unreachable_target: Vector3
var has_unreachable_target: bool = false
var unreachable_wander_timer: float = 0.0


# ============================================================
# HEALTH BAR
# ============================================================

var health_bar_layer: CanvasLayer
var health_bar_bg: Control
var health_bar_fill: Control
var health_bar_visible_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemy")

	current_health = max_health
	home_position = global_position
	progress_start_position = global_position

	find_enemy_nodes()
	find_player()
	setup_audio()
	create_health_bar()

	initialize_square_wander()

	play_animation("Cannon_Idle")


func find_enemy_nodes() -> void:
	animation_player = find_child(
		"AnimationPlayer",
		true,
		false
	) as AnimationPlayer

	hit_sound = find_child(
		"HitSound",
		true,
		true
	) as AudioStreamPlayer3D

	attack_sound = find_child(
		"AttackSound",
		true,
		true
	) as AudioStreamPlayer3D

	skill_sound = find_child(
		"SkillSound",
		true,
		true
	) as AudioStreamPlayer3D


func find_player() -> void:
	var players: Array[Node] = (
		get_tree().get_nodes_in_group("player")
	)

	if players.size() > 0:
		player = players[0] as Node3D


func setup_audio() -> void:
	if hit_sound != null:
		hit_sound.unit_size = 1.0

	if attack_sound != null:
		attack_sound.unit_size = 1.0

	if skill_sound != null:
		skill_sound.unit_size = 1.0


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta

	if skill_timer > 0.0:
		skill_timer -= delta

	if blood_timer > 0.0:
		blood_timer -= delta

	if obstacle_avoid_timer > 0.0:
		obstacle_avoid_timer -= delta

	if jump_timer > 0.0:
		jump_timer -= delta

	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0

		handle_gravity(delta)
		move_and_slide()

		return

	if stun_timer > 0.0:
		stun_timer -= delta

		handle_gravity(delta)
		stop_horizontal(delta)

		move_and_slide()

		return

	if player == null or not is_instance_valid(player):
		find_player()

	handle_gravity(delta)

	if is_attacking or is_using_skill:
		stop_horizontal(delta)

		move_and_slide()

		return

	if player != null:
		handle_ai(delta)
	else:
		handle_wander(delta)

	move_and_slide()


func _process(delta: float) -> void:
	update_health_bar(delta)


func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


# ============================================================
# AI
# ============================================================

func handle_ai(delta: float) -> void:
	if player == null:
		handle_wander(delta)
		return

	if not is_instance_valid(player):
		player = null
		handle_wander(delta)
		return

	var direction_to_player: Vector3 = (
		player.global_position - global_position
	)

	direction_to_player.y = 0.0

	var distance_to_player: float = (
		direction_to_player.length()
	)


	# ========================================================
	# PLAYER OUTSIDE 10 METERS
	# ========================================================

	if distance_to_player > chase_distance:
		player_unreachable = false
		reset_obstacle_attempts()
		handle_wander(delta)
		return


	# ========================================================
	# PLAYER INSIDE 10 METERS
	# ========================================================

	if player_unreachable:
		handle_unreachable_player(delta)
		return


	# ========================================================
	# COMBAT RANGE
	# ========================================================

	if distance_to_player <= skill_distance:
		if skill_timer <= 0.0:
			use_skill()
			return

	if distance_to_player <= attack_distance:
		if attack_timer <= 0.0:
			request_attack()
			return

		stop_and_face_player(delta)
		play_animation("Cannon_Idle")
		return


	# ========================================================
	# CHASE
	# ========================================================

	move_toward_player(
		direction_to_player,
		delta
	)


# ============================================================
# CHASE PLAYER
# ============================================================

func move_toward_player(
	direction: Vector3,
	delta: float
) -> void:

	if direction.length() <= 0.05:
		stop_horizontal(delta)
		play_animation("Cannon_Idle")
		return

	var desired_direction: Vector3 = (
		direction.normalized()
	)

	var blocked: bool = is_direction_blocked(
		desired_direction,
		obstacle_check_distance
	)

	if blocked:
		handle_obstacle_blocked(
			desired_direction,
			delta
		)
		return

	if was_obstacle_blocked:
		reset_obstacle_attempts()

	var move_direction: Vector3 = (
		get_avoidance_direction(
			desired_direction
		)
	)

	var target_velocity: Vector3 = (
		move_direction * move_speed
	)

	velocity.x = move_toward(
		velocity.x,
		target_velocity.x,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		target_velocity.z,
		acceleration * delta
	)

	var target_angle: float = atan2(
		move_direction.x,
		move_direction.z
	)

	rotation.y = lerp_angle(
		rotation.y,
		target_angle,
		rotation_speed * delta
	)

	if Vector2(
		velocity.x,
		velocity.z
	).length() > 0.2:

		play_animation("Cannon_Run")
	else:
		play_animation("Cannon_Idle")


# ============================================================
# OBSTACLE BLOCKED
# ============================================================

func handle_obstacle_blocked(
	desired_direction: Vector3,
	delta: float
) -> void:

	was_obstacle_blocked = true
	blocked_timer += delta

	if blocked_timer <= delta * 1.5:
		progress_start_position = global_position

	if enable_obstacle_jump:
		if jump_attempts < max_jump_attempts:
			if jump_timer <= 0.0:
				if is_on_floor():
					perform_obstacle_jump()
					return

	var avoidance_direction: Vector3 = (
		get_avoidance_direction(
			desired_direction
		)
	)

	if avoidance_direction == Vector3.ZERO:
		stop_horizontal(delta)
		play_animation("Cannon_Idle")
	else:
		var target_velocity: Vector3 = (
			avoidance_direction * move_speed
		)

		velocity.x = move_toward(
			velocity.x,
			target_velocity.x,
			acceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			target_velocity.z,
			acceleration * delta
		)

		var target_angle: float = atan2(
			avoidance_direction.x,
			avoidance_direction.z
		)

		rotation.y = lerp_angle(
			rotation.y,
			target_angle,
			rotation_speed * delta
		)

		if Vector2(
			velocity.x,
			velocity.z
		).length() > 0.15:

			play_animation("Cannon_Run")
		else:
			play_animation("Cannon_Idle")

	var horizontal_position := Vector3(
		global_position.x,
		0.0,
		global_position.z
	)

	var horizontal_start := Vector3(
		progress_start_position.x,
		0.0,
		progress_start_position.z
	)

	var moved_distance: float = (
		horizontal_position.distance_to(
			horizontal_start
		)
	)

	if moved_distance >= minimum_progress_distance:
		blocked_timer = 0.0
		progress_start_position = global_position
		return

	if blocked_timer >= unreachable_check_time:
		enter_unreachable_state()


# ============================================================
# OBSTACLE JUMP
# ============================================================

func perform_obstacle_jump() -> void:
	if not is_on_floor():
		return

	if jump_attempts >= max_jump_attempts:
		return

	jump_attempts += 1

	jump_timer = jump_attempt_cooldown

	velocity.y = jump_velocity

	play_animation("Cannon_Run")


# ============================================================
# RESET OBSTACLE ATTEMPTS
# ============================================================

func reset_obstacle_attempts() -> void:
	jump_attempts = 0
	blocked_timer = 0.0
	jump_timer = 0.0
	was_obstacle_blocked = false

	obstacle_avoid_timer = 0.0
	obstacle_avoid_direction = Vector3.ZERO

	progress_start_position = global_position


# ============================================================
# ENTER UNREACHABLE STATE
# ============================================================

func enter_unreachable_state() -> void:
	player_unreachable = true

	unreachable_timer = 0.0
	unreachable_wander_timer = 0.0
	has_unreachable_target = false

	velocity.x = 0.0
	velocity.z = 0.0

	reset_obstacle_attempts()

	set_new_unreachable_target()

	play_animation("Cannon_Idle")


# ============================================================
# UNREACHABLE PLAYER
# ============================================================

func handle_unreachable_player(
	delta: float
) -> void:

	if player == null:
		player_unreachable = false
		return

	if not is_instance_valid(player):
		player = null
		player_unreachable = false
		return

	var direction_to_player: Vector3 = (
		player.global_position - global_position
	)

	direction_to_player.y = 0.0

	var distance_to_player: float = (
		direction_to_player.length()
	)

	if distance_to_player > chase_distance:
		player_unreachable = false

		reset_obstacle_attempts()

		has_unreachable_target = false

		initialize_square_wander()

		return

	if is_player_reachable():
		player_unreachable = false

		reset_obstacle_attempts()

		has_unreachable_target = false

		return

	if unreachable_wander_timer > 0.0:
		unreachable_wander_timer -= delta

		stop_horizontal(delta)

		play_animation("Cannon_Idle")

		return

	if not has_unreachable_target:
		set_new_unreachable_target()

	var direction: Vector3 = (
		unreachable_target - global_position
	)

	direction.y = 0.0

	if direction.length() <= 0.6:
		has_unreachable_target = false

		unreachable_wander_timer = (
			unreachable_wait_time
		)

		stop_horizontal(delta)

		play_animation("Cannon_Idle")

		return

	var local_direction := direction.normalized()

	if is_direction_blocked(
		local_direction,
		1.5
	):
		has_unreachable_target = false

		stop_horizontal(delta)

		play_animation("Cannon_Idle")

		return

	var target_velocity: Vector3 = (
		local_direction * unreachable_wander_speed
	)

	velocity.x = move_toward(
		velocity.x,
		target_velocity.x,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		target_velocity.z,
		acceleration * delta
	)

	var target_angle: float = atan2(
		local_direction.x,
		local_direction.z
	)

	rotation.y = lerp_angle(
		rotation.y,
		target_angle,
		rotation_speed * delta
	)

	if Vector2(
		velocity.x,
		velocity.z
	).length() > 0.15:

		play_animation("Cannon_Run")
	else:
		play_animation("Cannon_Idle")


# ============================================================
# CREATE UNREACHABLE WANDER TARGET
# ============================================================

func set_new_unreachable_target() -> void:
	var random_angle: float = randf_range(
		0.0,
		TAU
	)

	var random_distance: float = randf_range(
		1.5,
		unreachable_wander_radius
	)

	var offset: Vector3 = Vector3(
		cos(random_angle) * random_distance,
		0.0,
		sin(random_angle) * random_distance
	)

	unreachable_target = (
		global_position + offset
	)

	has_unreachable_target = true


# ============================================================
# CHECK PLAYER REACHABLE
# ============================================================

func is_player_reachable() -> bool:
	if player == null:
		return false

	if not is_instance_valid(player):
		return false

	var direction: Vector3 = (
		player.global_position - global_position
	)

	direction.y = 0.0

	var distance: float = (
		direction.length()
	)

	if distance <= 0.05:
		return true

	if not is_direction_blocked(
		direction.normalized(),
		min(
			distance,
			obstacle_check_distance
		)
	):
		return true

	var right: Vector3 = (
		direction.normalized().cross(
			Vector3.UP
		)
	).normalized()

	var left: Vector3 = -right

	if not is_direction_blocked(
		right,
		obstacle_side_distance
	):
		return true

	if not is_direction_blocked(
		left,
		obstacle_side_distance
	):
		return true

	return false


# ============================================================
# SQUARE WANDERING
# TOTAL AREA = 6 m²
# SIDE = sqrt(6) ≈ 11.0 m
# ============================================================

func initialize_square_wander() -> void:
	var half_side: float = sqrt(
		wander_area
	) * 0.5

	wander_points.clear()

	wander_points.append(
		home_position
		+ Vector3(
			-half_side,
			0.0,
			-half_side
		)
	)

	wander_points.append(
		home_position
		+ Vector3(
			half_side,
			0.0,
			-half_side
		)
	)

	wander_points.append(
		home_position
		+ Vector3(
			half_side,
			0.0,
			half_side
		)
	)

	wander_points.append(
		home_position
		+ Vector3(
			-half_side,
			0.0,
			half_side
		)
	)

	wander_points.append(
		home_position
	)

	wander_point_index = 0

	wander_target = (
		wander_points[wander_point_index]
	)

	wander_timer = 0.0
	has_wander_target = true
	wander_points_initialized = true


func handle_wander(delta: float) -> void:
	if not wander_points_initialized:
		initialize_square_wander()

	if wander_points.is_empty():
		return

	var direction: Vector3 = (
		wander_target - global_position
	)

	direction.y = 0.0

	if direction.length() <= 0.25:
		stop_horizontal(delta)

		wander_timer -= delta

		play_animation("Cannon_Idle")

		if wander_timer <= 0.0:
			wander_point_index += 1

			if wander_point_index >= wander_points.size():
				wander_point_index = 0

			wander_target = (
				wander_points[wander_point_index]
			)

			wander_timer = wander_wait_time

		return

	move_wander_direction(
		direction.normalized(),
		delta
	)


func set_new_wander_target() -> void:
	if not wander_points_initialized:
		initialize_square_wander()

	if wander_points.is_empty():
		return

	wander_target = (
		wander_points[wander_point_index]
	)

	has_wander_target = true


func move_wander_direction(
	direction: Vector3,
	delta: float
) -> void:

	var move_direction: Vector3 = (
		get_avoidance_direction(
			direction
		)
	)

	if move_direction == Vector3.ZERO:
		stop_horizontal(delta)
		play_animation("Cannon_Idle")
		return

	var target_velocity: Vector3 = (
		move_direction * wander_speed
	)

	velocity.x = move_toward(
		velocity.x,
		target_velocity.x,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		target_velocity.z,
		acceleration * delta
	)

	var target_angle: float = atan2(
		move_direction.x,
		move_direction.z
	)

	rotation.y = lerp_angle(
		rotation.y,
		target_angle,
		rotation_speed * delta
	)

	if Vector2(
		velocity.x,
		velocity.z
	).length() > 0.15:

		play_animation("Cannon_Run")
	else:
		play_animation("Cannon_Idle")


# ============================================================
# IMPROVED OBSTACLE AVOIDANCE
# ============================================================

func get_avoidance_direction(
	desired_direction: Vector3
) -> Vector3:

	desired_direction.y = 0.0

	if desired_direction.length() <= 0.01:
		return Vector3.ZERO

	desired_direction = (
		desired_direction.normalized()
	)

	if obstacle_avoid_timer > 0.0:
		var obstacle_direction: Vector3 = (
			obstacle_avoid_direction
		)

		if obstacle_direction.length() > 0.01:
			if not is_direction_blocked(
				obstacle_direction,
				obstacle_check_distance
			):

				return (
					desired_direction * 0.45
					+ obstacle_direction * 0.55
				).normalized()

	if not is_direction_blocked(
		desired_direction,
		obstacle_check_distance
	):
		return desired_direction

	var right_direction: Vector3 = (
		desired_direction.cross(
			Vector3.UP
		)
	).normalized()

	var left_direction: Vector3 = (
		-right_direction
	)

	var right_clear: bool = not is_direction_blocked(
		right_direction,
		obstacle_side_distance
	)

	var left_clear: bool = not is_direction_blocked(
		left_direction,
		obstacle_side_distance
	)

	if right_clear and left_clear:
		obstacle_avoid_direction = (
			right_direction
		)

		obstacle_avoid_timer = 0.7

		return (
			desired_direction * 0.25
			+ right_direction * 0.75
		).normalized()

	if right_clear:
		obstacle_avoid_direction = (
			right_direction
		)

		obstacle_avoid_timer = 0.7

		return (
			desired_direction * 0.25
			+ right_direction * 0.75
		).normalized()

	if left_clear:
		obstacle_avoid_direction = (
			left_direction
		)

		obstacle_avoid_timer = 0.7

		return (
			desired_direction * 0.25
			+ left_direction * 0.75
		).normalized()

	var diagonal_right: Vector3 = (
		desired_direction
		+ right_direction * 0.8
	).normalized()

	var diagonal_left: Vector3 = (
		desired_direction
		+ left_direction * 0.8
	).normalized()

	if not is_direction_blocked(
		diagonal_right,
		obstacle_check_distance
	):
		obstacle_avoid_direction = (
			diagonal_right
		)

		obstacle_avoid_timer = 0.8

		return diagonal_right

	if not is_direction_blocked(
		diagonal_left,
		obstacle_check_distance
	):
		obstacle_avoid_direction = (
			diagonal_left
		)

		obstacle_avoid_timer = 0.8

		return diagonal_left

	obstacle_avoid_direction = Vector3.ZERO
	obstacle_avoid_timer = 0.0

	return Vector3.ZERO


# ============================================================
# OBSTACLE RAYCAST
# ============================================================

func is_direction_blocked(
	direction: Vector3,
	distance: float
) -> bool:

	if direction.length() <= 0.01:
		return false

	var space_state := (
		get_world_3d().direct_space_state
	)

	var from: Vector3 = (
		global_position
		+ Vector3(
			0.0,
			obstacle_look_height,
			0.0
		)
	)

	var to: Vector3 = (
		from
		+ direction.normalized() * distance
	)

	var query := PhysicsRayQueryParameters3D.create(
		from,
		to
	)

	query.exclude = [self]

	var result: Dictionary = (
		space_state.intersect_ray(query)
	)

	if result.is_empty():
		return false

	var collider: Object = (
		result.get("collider")
	)

	if collider == null:
		return true

	if collider is Node:
		var collider_node: Node = (
			collider as Node
		)

		if collider_node.is_in_group("player"):
			return false

		var parent_node: Node = (
			collider_node.get_parent()
		)

		if parent_node != null:
			if parent_node.is_in_group("player"):
				return false

	return true


# ============================================================
# STOP
# ============================================================

func stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(
		velocity.x,
		0.0,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		0.0,
		acceleration * delta
	)


# ============================================================
# STOP AND FACE PLAYER
# ============================================================

func stop_and_face_player(delta: float) -> void:
	stop_horizontal(delta)

	if player == null:
		return

	var direction: Vector3 = (
		player.global_position - global_position
	)

	direction.y = 0.0

	if direction.length() <= 0.05:
		return

	var target_angle: float = atan2(
		direction.x,
		direction.z
	)

	rotation.y = lerp_angle(
		rotation.y,
		target_angle,
		rotation_speed * delta
	)


# ============================================================
# NORMAL ATTACK
# ============================================================

func request_attack() -> void:
	if is_dead:
		return

	if is_attacking:
		return

	if is_using_skill:
		return

	if attack_timer > 0.0:
		return

	is_attacking = true
	attack_timer = attack_cooldown

	play_animation("Cannon_Attack")

	if attack_sound != null:
		attack_sound.play()

	var attack_length: float = (
		get_animation_length(
			"Cannon_Attack"
		)
	)

	if attack_length <= 0.0:
		attack_length = 0.7

	await get_tree().create_timer(
		attack_hit_start
	).timeout

	if not is_inside_tree() or is_dead:
		is_attacking = false
		return

	perform_auto_target_hit(
		attack_damage,
		attack_distance,
		attack_angle_degrees
	)

	await get_tree().create_timer(
		attack_hit_duration
	).timeout

	var remaining: float = max(
		0.0,
		attack_length
		- attack_hit_start
		- attack_hit_duration
	)

	if remaining > 0.0:
		await get_tree().create_timer(
			remaining
		).timeout

	is_attacking = false


# ============================================================
# SKILL
# ============================================================

func use_skill() -> void:
	if is_dead:
		return

	if is_attacking:
		return

	if is_using_skill:
		return

	if skill_timer > 0.0:
		return

	is_using_skill = true
	skill_timer = skill_cooldown

	play_animation("Cannon_Skill")

	if skill_sound != null:
		skill_sound.play()

	var skill_length: float = (
		get_animation_length(
			"Cannon_Skill"
		)
	)

	if skill_length <= 0.0:
		skill_length = 1.0

	await get_tree().create_timer(
		skill_hit_start
	).timeout

	if not is_inside_tree() or is_dead:
		is_using_skill = false
		return

	perform_auto_target_hit(
		skill_damage,
		skill_distance,
		skill_angle_degrees
	)

	await get_tree().create_timer(
		skill_hit_duration
	).timeout

	var remaining: float = max(
		0.0,
		skill_length
		- skill_hit_start
		- skill_hit_duration
	)

	if remaining > 0.0:
		await get_tree().create_timer(
			remaining
		).timeout

	is_using_skill = false


# ============================================================
# AUTO TARGET HIT
# ============================================================

func perform_auto_target_hit(
	damage: float,
	max_range: float,
	max_angle_degrees: float
) -> void:

	if player == null:
		return

	if not is_instance_valid(player):
		return

	var to_player: Vector3 = (
		player.global_position - global_position
	)

	to_player.y = 0.0

	var distance: float = (
		to_player.length()
	)

	if distance > max_range:
		return

	if distance <= 0.01:
		return

	var forward: Vector3 = Vector3(
		sin(rotation.y),
		0.0,
		cos(rotation.y)
	)

	var angle: float = rad_to_deg(
		forward.angle_to(
			to_player.normalized()
		)
	)

	if angle > max_angle_degrees:
		return

	if player.has_method("take_damage"):
		player.take_damage(damage)


# ============================================================
# KNOCKBACK
# ============================================================

func apply_knockback(
	direction: Vector3,
	distance: float
) -> void:

	if is_dead:
		return

	global_position += (
		direction * distance
	)

	stun_timer = knockback_stun_time

	is_attacking = false
	is_using_skill = false

	velocity = Vector3.ZERO


# ============================================================
# HEALTH BAR
# ============================================================

func create_health_bar() -> void:
	health_bar_layer = CanvasLayer.new()
	health_bar_layer.name = (
		"EnemyHealthBarLayer"
	)

	add_child(health_bar_layer)

	health_bar_bg = Control.new()

	health_bar_bg.size = Vector2(
		70,
		10
	)

	health_bar_bg.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	health_bar_bg.modulate.a = 0.0

	var bg_panel := Panel.new()

	bg_panel.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var bg_style := StyleBoxFlat.new()

	bg_style.bg_color = Color(
		0.1,
		0.1,
		0.1,
		0.8
	)

	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3

	bg_panel.add_theme_stylebox_override(
		"panel",
		bg_style
	)

	health_bar_bg.add_child(
		bg_panel
	)

	health_bar_fill = Control.new()

	health_bar_fill.position = Vector2(
		2,
		2
	)

	health_bar_fill.size = Vector2(
		66,
		6
	)

	health_bar_fill.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	health_bar_fill.draw.connect(
		_on_enemy_health_bar_draw
	)

	health_bar_bg.add_child(
		health_bar_fill
	)

	health_bar_layer.add_child(
		health_bar_bg
	)


func _on_enemy_health_bar_draw() -> void:
	var fraction: float = clamp(
		current_health / max_health,
		0.0,
		1.0
	)

	var width: float = (
		health_bar_fill.size.x
		* fraction
	)

	health_bar_fill.draw_rect(
		Rect2(
			Vector2.ZERO,
			Vector2(
				width,
				health_bar_fill.size.y
			)
		),
		Color(
			0.95,
			0.85,
			0.1
		)
	)


func update_health_bar(delta: float) -> void:
	if health_bar_bg == null:
		return

	if health_bar_visible_timer > 0.0:
		health_bar_visible_timer -= delta

	var target_alpha: float = (
		1.0
		if health_bar_visible_timer > 0.0
		else 0.0
	)

	health_bar_bg.modulate.a = move_toward(
		health_bar_bg.modulate.a,
		target_alpha,
		delta * 2.0
	)

	if health_bar_bg.modulate.a <= 0.001:
		health_bar_bg.visible = false
		return

	var cam: Camera3D = (
		get_viewport().get_camera_3d()
	)

	if cam == null:
		health_bar_bg.visible = false
		return

	var world_pos: Vector3 = (
		global_position
		+ Vector3(
			0.0,
			2.1,
			0.0
		)
	)

	if cam.is_position_behind(world_pos):
		health_bar_bg.visible = false
		return

	var screen_pos: Vector2 = (
		cam.unproject_position(
			world_pos
		)
	)

	health_bar_bg.visible = true

	health_bar_bg.position = (
		screen_pos
		- health_bar_bg.size * 0.5
	)

	health_bar_fill.queue_redraw()


# ============================================================
# TAKE DAMAGE
# ============================================================

func take_damage(amount: float) -> void:
	if is_dead:
		return

	if amount <= 0.0:
		return

	current_health = max(
		0.0,
		current_health - amount
	)

	damage_accumulator += amount

	health_bar_visible_timer = 3.0

	if damage_accumulator >= blood_damage_threshold:
		damage_accumulator -= (
			blood_damage_threshold
		)

		play_hit_sound()

	if current_health <= blood_start_health:
		if blood_timer <= 0.0:
			blood_timer = blood_cooldown

			var particle_amount: int = 12

			if current_health <= heavy_blood_health:
				particle_amount = 20

			spawn_blood_effect(
				particle_amount
			)

	if current_health <= 0.0:
		die()


func is_dead_now() -> bool:
	return is_dead


func play_hit_sound() -> void:
	if hit_sound != null:
		hit_sound.play()


# ============================================================
# BLOOD EFFECT
# ============================================================

func spawn_blood_effect(
	particle_amount: int
) -> void:

	var particles: GPUParticles3D = (
		GPUParticles3D.new()
	)

	particles.amount = particle_amount
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.35

	var process_material: ParticleProcessMaterial = (
		ParticleProcessMaterial.new()
	)

	process_material.direction = Vector3.UP
	process_material.spread = 35.0
	process_material.initial_velocity_min = 2.0
	process_material.initial_velocity_max = 5.0
	process_material.gravity = Vector3(
		0.0,
		-8.0,
		0.0
	)

	particles.process_material = (
		process_material
	)

	var sphere: SphereMesh = (
		SphereMesh.new()
	)

	sphere.radius = 0.035
	sphere.height = 0.07

	var material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	material.albedo_color = Color(
		0.55,
		0.02,
		0.02,
		1.0
	)

	sphere.material = material

	particles.draw_pass_1 = sphere

	get_tree().current_scene.add_child(
		particles
	)

	particles.global_position = (
		global_position
		+ Vector3(
			0.0,
			1.0,
			0.0
		)
	)

	particles.restart()

	await get_tree().create_timer(
		0.8
	).timeout

	if is_instance_valid(particles):
		particles.queue_free()


# ============================================================
# DEATH
# ============================================================

func die() -> void:
	if is_dead:
		return

	is_dead = true
	current_health = 0.0

	is_attacking = false
	is_using_skill = false

	velocity = Vector3.ZERO

	play_animation("Dead")

	if health_bar_bg != null:
		health_bar_bg.visible = false

	spawn_hp_pickup()

	await get_tree().create_timer(
		3.0
	).timeout

	if is_instance_valid(self):
		queue_free()


# ============================================================
# HP PICKUP
# ============================================================

func spawn_hp_pickup() -> void:
	var pickup := Node3D.new()

	pickup.name = "HpPickup"

	pickup.add_to_group(
		"pickup"
	)

	pickup.set_meta(
		"pickup_type",
		"hp"
	)

	pickup.set_meta(
		"pickup_value",
		hp_pickup_value
	)

	var label := Label3D.new()

	label.text = "+"
	label.font_size = 160
	label.outline_size = 0

	label.modulate = Color(
		0.15,
		0.95,
		0.2
	)

	label.billboard = (
		BaseMaterial3D.BILLBOARD_ENABLED
	)

	label.no_depth_test = true

	pickup.add_child(
		label
	)

	get_tree().current_scene.add_child(
		pickup
	)

	pickup.global_position = (
		global_position
		+ Vector3(
			0.0,
			0.6,
			0.0
		)
	)


# ============================================================
# ANIMATION
# ============================================================

func play_animation(
	requested_name: String
) -> void:

	if animation_player == null:
		return

	var actual_name: String = (
		resolve_animation_name(
			requested_name
		)
	)

	if actual_name != "":
		if animation_player.current_animation != actual_name:
			animation_player.play(
				actual_name,
				0.16
			)


func resolve_animation_name(
	requested_name: String
) -> String:

	if animation_player == null:
		return ""

	if animation_player.has_animation(
		requested_name
	):
		return requested_name

	var underscore_name: String = (
		requested_name.replace(
			".",
			"_"
		)
	)

	if animation_player.has_animation(
		underscore_name
	):
		return underscore_name

	var dot_name: String = (
		requested_name.replace(
			"_",
			"."
		)
	)

	if animation_player.has_animation(
		dot_name
	):
		return dot_name

	return ""


func get_animation_length(
	requested_name: String
) -> float:

	if animation_player == null:
		return 0.0

	var actual_name: String = (
		resolve_animation_name(
			requested_name
		)
	)

	if actual_name == "":
		return 0.0

	var animation: Animation = (
		animation_player.get_animation(
			actual_name
		)
	)

	if animation != null:
		return animation.length

	return 0.0
