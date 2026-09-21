extends CharacterBody3D

# ============================================================
# TRIPP ENEMY AI
# ============================================================

@export_category("Movement")
@export var move_speed: float = 2.5
@export var run_speed: float = 3.5
@export var acceleration: float = 12.0
@export var rotation_speed: float = 8.0
@export var gravity: float = 16.0
@export var jump_velocity: float = 5.0

@export_category("AI Range")
@export var chase_distance: float = 15.0
@export var wander_square_side: float = 4.0
@export var wander_speed: float = 1.2
@export var wander_walk_time: float = 5.0
@export var wander_wait_time: float = 3.0

@export_category("Obstacle Jump")
@export var enable_obstacle_jump: bool = true
@export var max_jump_attempts: int = 3
@export var jump_attempt_cooldown: float = 2.0
@export var jump_cooldown_duration: float = 10.0

@export_category("Health")
@export var max_health: float = 200.0

@export_category("Combat & Auto-Target")
@export var attack_damage: float = 10.0
@export var skill_damage: float = 15.0
@export var auto_target_range: float = 1.8
@export var attack_distance: float = 1.8
@export var attack_angle_degrees: float = 180.0
@export var skill_distance: float = 2.5
@export var skill_angle_degrees: float = 70.0
@export var attack_cooldown: float = 1.2
@export var skill_cooldown: float = 10.0
@export var attack_hit_start: float = 0.20
@export var attack_hit_duration: float = 0.15
@export var skill_hit_start: float = 0.30
@export var skill_hit_duration: float = 0.20

@export_category("Drops")
@export var hp_pickup_value: float = 70.0


var animation_player: AnimationPlayer
var player: Node3D

var current_health: float = 200.0
var attack_timer: float = 0.0
var skill_timer: float = 0.0
var stun_timer: float = 0.0

var is_dead: bool = false
var is_attacking: bool = false
var is_using_skill: bool = false


# ============================================================
# SQUARE WANDERING
# ============================================================

var home_position: Vector3
var wander_target: Vector3
var wander_timer: float = 0.0
var wander_walk_timer: float = 0.0
var has_wander_target: bool = false
var wander_point_index: int = 0
var wander_points: Array[Vector3] = []


# ============================================================
# OBSTACLE JUMP
# ============================================================

var jump_attempts: int = 0
var jump_timer: float = 0.0
var general_jump_cooldown: float = 0.0
var was_blocked: bool = false


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

	find_enemy_nodes()
	find_player()
	create_health_bar()

	initialize_square_wander()

	play_animation("Idle")


func find_enemy_nodes() -> void:
	animation_player = find_child(
		"AnimationPlayer",
		true,
		false
	) as AnimationPlayer


func find_player() -> void:
	var players: Array[Node] = (
		get_tree().get_nodes_in_group("player")
	)

	if players.size() > 0:
		player = players[0] as Node3D


# ============================================================
# PHYSICS PROCESS
# ============================================================

func _physics_process(delta: float) -> void:

	if attack_timer > 0.0:
		attack_timer -= delta

	if skill_timer > 0.0:
		skill_timer -= delta

	if jump_timer > 0.0:
		jump_timer -= delta

	if general_jump_cooldown > 0.0:
		general_jump_cooldown -= delta

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

	if player == null or not is_instance_valid(player):
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


	if distance_to_player > chase_distance:
		handle_wander(delta)
		return


	if distance_to_player <= auto_target_range:

		stop_horizontal(delta)
		face_player()

		if skill_timer <= 0.0 and distance_to_player <= skill_distance:
			use_skill()
			return

		if attack_timer <= 0.0 and distance_to_player <= attack_distance:
			request_attack()
			return

		play_animation("Idle")
		return


	if distance_to_player <= skill_distance:
		if skill_timer <= 0.0:
			use_skill()
			return


	if distance_to_player <= attack_distance:
		if attack_timer <= 0.0:
			request_attack()
			return


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
		play_animation("Idle")

		return


	var move_direction: Vector3 = (
		direction.normalized()
	)


	if is_on_wall() and is_on_floor():

		was_blocked = true

		if enable_obstacle_jump:

			if general_jump_cooldown <= 0.0:

				if jump_attempts < max_jump_attempts:

					if jump_timer <= 0.0:
						perform_obstacle_jump()

				else:

					general_jump_cooldown = (
						jump_cooldown_duration
					)

					jump_attempts = 0


	var target_velocity: Vector3 = (
		move_direction * run_speed
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

		play_animation("Run")

	else:

		play_animation("Idle")


# ============================================================
# OBSTACLE JUMP
# ============================================================

func perform_obstacle_jump() -> void:

	if not is_on_floor():
		return

	jump_attempts += 1

	jump_timer = jump_attempt_cooldown

	velocity.y = jump_velocity

	play_animation("Run")


# ============================================================
# ATTACK
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

	play_animation("Axe.Attack")

	face_player()


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

	play_animation("Axe.Skill")

	face_player()


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

	elif player.has_method("apply_damage"):

		player.apply_damage(damage)

	elif "health" in player:

		player.health -= damage


# ============================================================
# FACE PLAYER
# ============================================================

func face_player() -> void:

	if player == null:
		return

	if not is_instance_valid(player):
		return


	var direction: Vector3 = (
		player.global_position - global_position
	)

	direction.y = 0.0


	if direction.length_squared() > 0.0001:

		direction = direction.normalized()

		rotation.y = atan2(
			direction.x,
			direction.z
		)


# ============================================================
# SQUARE WANDER
# 4m x 4m
# ============================================================

func initialize_square_wander() -> void:

	wander_points.clear()

	var half_side: float = (
		wander_square_side * 0.5
	)


	wander_points.append(
		home_position + Vector3(
			-half_side,
			0.0,
			-half_side
		)
	)

	wander_points.append(
		home_position + Vector3(
			half_side,
			0.0,
			-half_side
		)
	)

	wander_points.append(
		home_position + Vector3(
			half_side,
			0.0,
			half_side
		)
	)

	wander_points.append(
		home_position + Vector3(
			-half_side,
			0.0,
			half_side
		)
	)


	wander_point_index = 0

	wander_target = (
		wander_points[wander_point_index]
	)

	has_wander_target = true

	wander_walk_timer = wander_walk_time

	wander_timer = 0.0


# ============================================================
# WANDERING
# ============================================================

func handle_wander(delta: float) -> void:

	if wander_points.is_empty():
		initialize_square_wander()
		return


	# --------------------------------------------------------
	# Waiting at point
	# --------------------------------------------------------

	if wander_timer > 0.0:

		wander_timer -= delta

		stop_horizontal(delta)

		play_animation("Idle")

		return


	# --------------------------------------------------------
	# Start next point
	# --------------------------------------------------------

	if not has_wander_target:

		wander_point_index += 1

		if wander_point_index >= wander_points.size():
			wander_point_index = 0


		wander_target = (
			wander_points[wander_point_index]
		)

		has_wander_target = true

		wander_walk_timer = wander_walk_time


	# --------------------------------------------------------
	# 5 second walking timer
	# --------------------------------------------------------

	if wander_walk_timer > 0.0:

		wander_walk_timer -= delta


	var direction: Vector3 = (
		wander_target - global_position
	)

	direction.y = 0.0


	# --------------------------------------------------------
	# Reached side/point
	# --------------------------------------------------------

	if direction.length() <= 0.25:

		has_wander_target = false

		wander_walk_timer = 0.0

		wander_timer = wander_wait_time

		stop_horizontal(delta)

		play_animation("Idle")

		return


	# --------------------------------------------------------
	# 5 seconds completed
	# --------------------------------------------------------

	if wander_walk_timer <= 0.0:

		has_wander_target = false

		wander_timer = wander_wait_time

		stop_horizontal(delta)

		play_animation("Idle")

		return


	# --------------------------------------------------------
	# Walk toward next side
	# --------------------------------------------------------

	var move_direction: Vector3 = (
		direction.normalized()
	)

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

		play_animation("Walk")

	else:

		play_animation("Idle")


# ============================================================
# COMPATIBILITY
# ============================================================

func set_new_wander_target() -> void:

	if wander_points.is_empty():
		initialize_square_wander()
		return

	wander_target = (
		wander_points[wander_point_index]
	)

	has_wander_target = true
	wander_walk_timer = wander_walk_time


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
# HEALTH BAR
# ============================================================

func create_health_bar() -> void:

	health_bar_layer = CanvasLayer.new()
	health_bar_layer.name = "EnemyHealthBarLayer"

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

		health_bar_bg.visible = true
		health_bar_bg.modulate.a = 1.0

	else:

		health_bar_bg.modulate.a = move_toward(
			health_bar_bg.modulate.a,
			0.0,
			delta * 3.0
		)

		if health_bar_bg.modulate.a <= 0.01:

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
			1.8,
			0.0
		)
	)


	if cam.is_position_behind(world_pos):

		health_bar_bg.visible = false

		return


	var screen_pos: Vector2 = (
		cam.unproject_position(world_pos)
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

	health_bar_visible_timer = 4.0


	if current_health <= 0.0:
		die()


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

	var pickup := Area3D.new()

	pickup.name = "HPPickup"

	pickup.add_to_group("pickup")

	pickup.collision_layer = 0
	pickup.collision_mask = 1


	var col := CollisionShape3D.new()

	var box := BoxShape3D.new()

	box.size = Vector3(
		2.2,
		2.2,
		2.2
	)

	col.shape = box

	pickup.add_child(col)


	var label := Label3D.new()

	label.text = "✚ +70 HP"

	label.font_size = 56

	label.outline_size = 12

	label.modulate = Color(
		0.15,
		0.95,
		0.2
	)

	label.outline_modulate = Color.BLACK

	label.billboard = (
		BaseMaterial3D.BILLBOARD_ENABLED
	)

	label.no_depth_test = true

	label.position = Vector3(
		0.0,
		0.4,
		0.0
	)

	pickup.add_child(label)


	if get_tree().current_scene != null:

		get_tree().current_scene.add_child(
			pickup
		)

		var ground_pos: Vector3 = global_position

		ground_pos.y += 0.1

		pickup.global_position = ground_pos


	pickup.body_entered.connect(
		func(body: Node3D):

			var body_name: String = (
				body.name.to_lower()
			)


			if (
				body.is_in_group("player")
				or body_name.contains("bing")
				or body_name.contains("kotaro")
				or "health" in body
			):

				if body.has_method("heal"):

					body.heal(
						hp_pickup_value
					)

				elif body.has_method("add_health"):

					body.add_health(
						hp_pickup_value
					)

				elif "health" in body:

					if "max_health" in body:

						body.health = min(
							body.max_health,
							body.health + hp_pickup_value
						)

					else:

						body.health += (
							hp_pickup_value
						)


					if body.has_method(
						"update_health_ui"
					):

						body.update_health_ui()

					elif body.has_method(
						"update_ui"
					):

						body.update_ui()


				pickup.queue_free()
	)


# ============================================================
# ANIMATION
# ============================================================

func play_animation(anim_name: String) -> void:

	if animation_player == null:
		return


	if animation_player.has_animation(
		anim_name
	):

		if animation_player.current_animation != anim_name:

			animation_player.play(
				anim_name,
				0.16
			)
