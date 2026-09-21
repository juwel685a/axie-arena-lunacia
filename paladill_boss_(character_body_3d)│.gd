extends CharacterBody3D

# PALADILL BOSS AI
# Godot 4.x


# ============================================================
# BOSS MOVEMENT
# ============================================================

@export_category("Boss Movement")

@export var walk_speed: float = 1.8
@export var run_speed: float = 3.5
@export var acceleration: float = 8.0
@export var rotation_speed: float = 5.0
@export var gravity: float = 16.0

@export var home_radius: float = 15.0
@export var chase_distance: float = 15.0
@export var lose_target_distance: float = 15.0
@export var always_chase_player: bool = true
@export var stop_distance: float = 1.80
@export var wander_wait_min: float = 3.0
@export var wander_wait_max: float = 3.0
@export var chase_walk_distance: float = 5.0


# ============================================================
# BOSS HEALTH
# ============================================================

@export_category("Boss Health")

@export var max_health: float = 700.0
@export var rage_health_percent: float = 0.55
@export var enraged_health_percent: float = 0.25
@export var knockback_distance: float = 0.20
@export var stun_time_after_hit: float = 0.05


# ============================================================
# HAMMER COMBAT
# ============================================================

@export_category("Hammer Combat")

@export var attack_damage: float = 15.0
@export var attack_range: float = 2.0
@export var attack_angle_degrees: float = 70.0
@export var attack_cooldown: float = 3.0
@export var attack_hit_start: float = 0.38


# ============================================================
# SPECIAL JUMP HAMMER ATTACK
# ============================================================

@export_category("Special Jump Hammer Attack")

@export var special_attack_cooldown: float = 8.0
@export var special_jump_height: float = 2.5
@export var special_attack_range: float = 3.2
@export var special_attack_damage: float = 40.0
@export var special_attack_radius: float = 3.8
@export var special_jump_delay: float = 0.35
@export var special_land_time: float = 0.75


# ============================================================
# RAGE
# ============================================================

@export_category("Rage")

@export var rage_run_speed_multiplier: float = 1.12
@export var enraged_run_speed_multiplier: float = 1.25
@export var rage_attack_cooldown_multiplier: float = 0.85
@export var enraged_attack_cooldown_multiplier: float = 0.70
@export var roar_cooldown: float = 7.0
@export var roar_distance: float = 14.0
@export var rage_sequence_enabled: bool = false


# ============================================================
# BOSS TERRITORY
# ============================================================

@export_category("Boss Territory (15m Square Patrol)")

@export var boundary_size: float = 15.0
@export var boundary_edge_margin: float = 0.0

# Each side ends with a 3 second pause.
@export var patrol_corner_wait_time: float = 3.0

@export var show_boundary_line: bool = false


# ============================================================
# BOSS ANGER
# ============================================================

@export_category("Boss Anger (Provocation)")

@export var provoke_distance: float = 8.0
@export var anger_gain_per_second_jumping: float = 25.0
@export var anger_gain_per_hit: float = 15.0
@export var anger_decay_per_second: float = 8.0
@export var anger_max: float = 100.0
@export var anger_enrage_threshold: float = 60.0
@export var anger_calm_threshold: float = 20.0
@export var anger_run_speed_multiplier: float = 1.6
@export var anger_attack_cooldown_multiplier: float = 0.45
@export var anger_special_cooldown_multiplier: float = 0.5
@export var anger_damage_multiplier: float = 1.5
@export var anger_animation_speed: float = 1.3

@export var special_trigger_distance: float = 6.0
@export var angry_special_trigger_distance: float = 10.0


# ============================================================
# BOSS REWARDS
# ============================================================

@export_category("Boss Rewards")

@export var coin_count: int = 10
@export var diamond_count: int = 1
@export var win_after_boss_rewards: bool = true
@export var coin_spread_radius: float = 2.8
@export var coin_launch_height: float = 0.35
@export var reward_pickup_range: float = 1.35

@export var coin_scene: PackedScene
@export var diamond_scene: PackedScene


# ============================================================
# HAMMER
# ============================================================

@export_category("Hammer")

@export var hammer_scene: PackedScene
@export var hammer_bone_name: String = "Weapon_R_JNT"


# ============================================================
# NAVIGATION
# ============================================================

@export_category("Navigation")

@export var navigation_agent_path: NodePath = NodePath("NavigationAgent3D")


# ============================================================
# VARIABLES
# ============================================================

var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var hammer_attachment: BoneAttachment3D
var navigation_agent: NavigationAgent3D

var current_health: float = 700.0

var target: Node3D = null

var home_position: Vector3
var current_boundary_center: Vector3

var wander_target: Vector3 = Vector3.ZERO
var has_wander_target: bool = false
var wander_wait_timer: float = 0.0

var attack_timer: float = 1.2
var skill_timer: float = 8.0
var roar_timer: float = 0.0

var stun_timer: float = 0.0
var knockback_velocity: Vector3 = Vector3.ZERO

var is_dead: bool = false
var is_attacking: bool = false
var is_using_skill: bool = false
var is_roaring: bool = false
var is_busy: bool = false

var anger_level: float = 0.0
var is_angry: bool = false

var returning_to_boundary: bool = false
var boundary_ready: bool = false

var is_special_jumping: bool = false
var special_attack_hit_done: bool = false

var special_target_position: Vector3 = Vector3.ZERO

var boss_coins_collected: int = 0
var boss_diamonds_collected: int = 0


# ============================================================
# SQUARE PATROL VARIABLES
# ============================================================

var patrol_side: int = 0

var patrol_start_position: Vector3 = Vector3.ZERO
var patrol_end_position: Vector3 = Vector3.ZERO

var patrol_wait_timer: float = 0.0
var patrol_waiting: bool = false
var patrol_initialized: bool = false


# ============================================================
# HEALTH BAR VARIABLES
# ============================================================

var health_bar_node: Sprite3D
var health_progress_bar: ProgressBar
var health_text_label: Label
var health_bar_timer: float = 0.0


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	add_to_group("enemy")

	home_position = global_position
	current_boundary_center = global_position

	current_health = max_health

	animation_player = find_child(
		"AnimationPlayer",
		true,
		false
	) as AnimationPlayer

	skeleton = find_child(
		"Skeleton3D",
		true,
		false
	) as Skeleton3D

	navigation_agent = get_node_or_null(
		navigation_agent_path
	) as NavigationAgent3D

	if navigation_agent != null:

		navigation_agent.path_desired_distance = 0.5
		navigation_agent.target_desired_distance = 1.0
		navigation_agent.radius = 0.6
		navigation_agent.avoidance_enabled = true

	setup_hammer()
	setup_health_bar()

	wander_wait_timer = 0.5

	skill_timer = special_attack_cooldown
	roar_timer = 2.0

	play_animation("Idle")


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:

	if not boundary_ready:

		boundary_ready = true

		home_position = global_position
		current_boundary_center = global_position

		initialize_square_patrol()

	if show_boundary_line:
		create_boundary_debug()

	if is_dead:

		apply_dead_gravity(delta)
		move_and_slide()

		return

	update_timers(delta)

	if stun_timer > 0.0:

		stun_timer -= delta

		apply_knockback(delta)
		apply_gravity(delta)

		move_and_slide()

		return

	find_or_validate_player()
	update_anger(delta)

	if is_special_jumping:

		update_special_jump(delta)

	elif returning_to_boundary:

		update_return_home(delta)

	elif target != null and not is_busy:

		update_boss_combat(delta)

	elif target == null and not is_busy:

		update_square_patrol(delta)

	apply_gravity(delta)
	apply_knockback(delta)

	move_and_slide()


# ============================================================
# TIMERS
# ============================================================

func update_timers(delta: float) -> void:

	if attack_timer > 0.0:
		attack_timer -= delta

	if skill_timer > 0.0:
		skill_timer -= delta

	if roar_timer > 0.0:
		roar_timer -= delta

	if health_bar_timer > 0.0:

		health_bar_timer -= delta

		if health_bar_timer <= 0.0:

			if health_bar_node != null:
				health_bar_node.visible = false


# ============================================================
# PLAYER SEARCH / TARGET LOCK
# ============================================================

func find_or_validate_player() -> void:

	if returning_to_boundary:
		return

	if target != null and is_instance_valid(target):

		if target.has_method("is_dead_now"):

			if target.is_dead_now():

				return_to_home()

				return

		var distance_to_player: float = (
			global_position.distance_to(
				target.global_position
			)
		)

		# The Boss loses the player only when
		# the player becomes more than 15m away.
		if distance_to_player > chase_distance:

			return_to_home()

			return

		# Player is still within 15m.
		return

	target = null

	var players = get_tree().get_nodes_in_group("player")

	if players.size() <= 0:
		return

	var possible_player: Node3D = players[0] as Node3D

	if possible_player == null:
		return

	if possible_player.has_method("is_dead_now"):

		if possible_player.is_dead_now():
			return

	var distance_to_player: float = (
		global_position.distance_to(
			possible_player.global_position
		)
	)

	# Player enters the 15m detection distance.
	if distance_to_player <= chase_distance:

		target = possible_player

		has_wander_target = false
		patrol_waiting = false
		patrol_initialized = false


# ============================================================
# INITIALIZE 15 x 15m SQUARE PATROL
# ============================================================

func initialize_square_patrol() -> void:

	var half: float = boundary_size * 0.5

	patrol_side = 0

	patrol_wait_timer = 0.0
	patrol_waiting = false
	patrol_initialized = true

	# Start from the nearest first square corner
	# without teleporting the Boss.
	var current_x: float = clampf(
		global_position.x,
		home_position.x - half,
		home_position.x + half
	)

	var current_z: float = clampf(
		global_position.z,
		home_position.z - half,
		home_position.z + half
	)

	global_position.x = current_x
	global_position.z = current_z

	set_patrol_side_points()


# ============================================================
# PATROL SIDE POINTS
# ============================================================

func set_patrol_side_points() -> void:

	var half: float = boundary_size * 0.5

	var y_value: float = global_position.y

	match patrol_side:

		0:

			patrol_start_position = Vector3(
				home_position.x - half,
				y_value,
				home_position.z - half
			)

			patrol_end_position = Vector3(
				home_position.x + half,
				y_value,
				home_position.z - half
			)

		1:

			patrol_start_position = Vector3(
				home_position.x + half,
				y_value,
				home_position.z - half
			)

			patrol_end_position = Vector3(
				home_position.x + half,
				y_value,
				home_position.z + half
			)

		2:

			patrol_start_position = Vector3(
				home_position.x + half,
				y_value,
				home_position.z + half
			)

			patrol_end_position = Vector3(
				home_position.x - half,
				y_value,
				home_position.z + half
			)

		3:

			patrol_start_position = Vector3(
				home_position.x - half,
				y_value,
				home_position.z + half
			)

			patrol_end_position = Vector3(
				home_position.x - half,
				y_value,
				home_position.z - half
			)


# ============================================================
# SQUARE PATROL
# ============================================================

func update_square_patrol(delta: float) -> void:

	if is_busy:
		return

	if not patrol_initialized:

		initialize_square_patrol()

	if patrol_waiting:

		patrol_wait_timer -= delta

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

		play_animation("Hammer_Idle")

		if patrol_wait_timer <= 0.0:

			patrol_waiting = false

			patrol_side += 1

			if patrol_side >= 4:
				patrol_side = 0

			set_patrol_side_points()

		return

	var direction: Vector3 = (
		patrol_end_position -
		global_position
	)

	direction.y = 0.0

	var distance_to_end: float = direction.length()

	if distance_to_end <= 0.15:

		global_position.x = patrol_end_position.x
		global_position.z = patrol_end_position.z

		velocity.x = 0.0
		velocity.z = 0.0

		patrol_waiting = true
		patrol_wait_timer = patrol_corner_wait_time

		play_animation("Hammer_Idle")

		return

	direction = direction.normalized()

	velocity.x = move_toward(
		velocity.x,
		direction.x * walk_speed,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		direction.z * walk_speed,
		acceleration * delta
	)

	face_direction(
		direction,
		delta
	)

	play_animation("Hammer_Walk")


# ============================================================
# RETURN TO HOME
# ============================================================

func return_to_home() -> void:

	target = null

	has_wander_target = false
	patrol_waiting = false
	patrol_wait_timer = 0.0

	is_busy = false
	is_attacking = false
	is_using_skill = false
	is_special_jumping = false
	special_attack_hit_done = false

	returning_to_boundary = true

	patrol_initialized = false

	velocity.x = 0.0
	velocity.z = 0.0


# ============================================================
# RETURN HOME MOVEMENT
# ============================================================

func update_return_home(delta: float) -> void:

	var direction: Vector3 = (
		home_position -
		global_position
	)

	direction.y = 0.0

	var distance_to_home: float = direction.length()

	if distance_to_home <= 0.6:

		global_position.x = home_position.x
		global_position.z = home_position.z

		velocity.x = 0.0
		velocity.z = 0.0

		returning_to_boundary = false

		patrol_side = 0
		patrol_waiting = false
		patrol_wait_timer = 0.0
		patrol_initialized = false

		initialize_square_patrol()

		play_animation("Hammer_Idle")

		return

	if distance_to_home > 0.01:

		direction = direction.normalized()

		velocity.x = move_toward(
			velocity.x,
			direction.x * walk_speed,
			acceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			direction.z * walk_speed,
			acceleration * delta
		)

		face_direction(
			direction,
			delta
		)

		play_animation("Hammer_Walk")


# ============================================================
# BOSS COMBAT
# ============================================================

func update_boss_combat(delta: float) -> void:

	if target == null or is_busy:
		return

	var distance_to_player: float = (
		global_position.distance_to(
			target.global_position
		)
	)

	face_target(
		target,
		delta
	)

	# --------------------------------------------------------
	# SPECIAL JUMP ATTACK
	# --------------------------------------------------------

	if (
		skill_timer <= 0.0
		and distance_to_player <= get_special_trigger_distance()
	):

		start_special_jump_attack()

		return

	# --------------------------------------------------------
	# NORMAL ATTACK
	# --------------------------------------------------------

	if distance_to_player <= attack_range:

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

		if attack_timer <= 0.0:

			perform_hammer_attack()

		else:

			play_animation("Hammer_Idle")

	else:

		var chase_speed: float = walk_speed

		if is_angry:
			chase_speed = get_run_speed()

		move_using_navigation(
			target.global_position,
			chase_speed,
			delta
		)

		if chase_speed >= run_speed:

			play_animation("Hammer_Run")

		else:

			play_animation("Hammer_Walk")


# ============================================================
# NAVIGATION MOVEMENT
# ============================================================

func move_using_navigation(
	destination: Vector3,
	speed: float,
	delta: float
) -> void:

	# Chase is NOT restricted by the 15 x 15m patrol square.

	if navigation_agent == null:

		move_toward_point(
			destination,
			speed,
			delta
		)

		return

	navigation_agent.target_position = destination

	var next_point: Vector3 = (
		navigation_agent.get_next_path_position()
	)

	if next_point == Vector3.ZERO:

		move_toward_point(
			destination,
			speed,
			delta
		)

		return

	var direction: Vector3 = (
		next_point -
		global_position
	)

	direction.y = 0.0

	if direction.length_squared() < 0.0001:
		return

	direction = direction.normalized()

	velocity.x = move_toward(
		velocity.x,
		direction.x * speed,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		direction.z * speed,
		acceleration * delta
	)

	face_direction(
		direction,
		delta
	)


# ============================================================
# NORMAL MOVEMENT FALLBACK
# ============================================================

func move_toward_point(
	point: Vector3,
	speed: float,
	delta: float
) -> void:

	var direction: Vector3 = (
		point -
		global_position
	)

	direction.y = 0.0

	if direction.length_squared() < 0.0001:
		return

	direction = direction.normalized()

	velocity.x = move_toward(
		velocity.x,
		direction.x * speed,
		acceleration * delta
	)

	velocity.z = move_toward(
		velocity.z,
		direction.z * speed,
		acceleration * delta
	)

	face_direction(
		direction,
		delta
	)


# ============================================================
# FACE TARGET
# ============================================================

func face_target(
	target_node: Node3D,
	delta: float
) -> void:

	if target_node == null:
		return

	var direction: Vector3 = (
		target_node.global_position -
		global_position
	)

	direction.y = 0.0

	if direction.length_squared() > 0.0001:

		face_direction(
			direction.normalized(),
			delta
		)


func face_direction(
	direction: Vector3,
	delta: float
) -> void:

	if direction.length_squared() <= 0.0001:
		return

	var desired_yaw: float = atan2(
		direction.x,
		direction.z
	)

	rotation.y = lerp_angle(
		rotation.y,
		desired_yaw,
		clamp(
			rotation_speed * delta,
			0.0,
			1.0
		)
	)


# ============================================================
# NORMAL HAMMER ATTACK
# ============================================================

func perform_hammer_attack() -> void:

	if is_dead:
		return

	if target == null:
		return

	if is_busy:
		return

	is_busy = true
	is_attacking = true

	attack_timer = get_attack_cooldown()

	velocity.x = 0.0
	velocity.z = 0.0

	play_animation("Hammer_Attack")

	get_tree().create_timer(
		attack_hit_start / get_anim_speed(),
		false
	).timeout.connect(
		func():

			if not is_inside_tree() or is_dead:

				reset_states()

				return

			if is_instance_valid(target):

				var distance_to_player: float = (
					global_position.distance_to(
						target.global_position
					)
				)

				if distance_to_player <= attack_range + 0.5:

					if target.has_method("take_damage"):

						target.take_damage(
							get_attack_damage()
						)

			get_tree().create_timer(
				0.6 / get_anim_speed(),
				false
			).timeout.connect(
				func():
					reset_states()
			)
	)


# ============================================================
# SPECIAL JUMP HAMMER ATTACK
# ============================================================

func start_special_jump_attack() -> void:

	if is_dead:
		return

	if target == null:
		return

	if is_busy:
		return

	is_busy = true
	is_using_skill = true
	is_special_jumping = true
	special_attack_hit_done = false

	knockback_velocity = Vector3.ZERO

	skill_timer = get_special_cooldown()

	velocity = Vector3.ZERO

	special_target_position = target.global_position

	face_target(
		target,
		0.1
	)

	velocity.y = sqrt(
		2.0 *
		gravity *
		special_jump_height
	)

	play_animation("Hammer_Skill")


# ============================================================
# SPECIAL JUMP UPDATE
# ============================================================

func update_special_jump(delta: float) -> void:

	if is_dead:
		return

	var direction: Vector3 = (
		special_target_position -
		global_position
	)

	direction.y = 0.0

	var dist_to_target: float = direction.length()

	if dist_to_target > 0.2:

		direction = direction.normalized()

		velocity.x = direction.x * get_run_speed()
		velocity.z = direction.z * get_run_speed()

		face_direction(
			direction,
			delta
		)

	else:

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

	if not is_on_floor():

		velocity.y -= gravity * delta

	if is_on_floor() and velocity.y <= 0.0:

		velocity.x = 0.0
		velocity.z = 0.0

		if not special_attack_hit_done:

			special_attack_hit_done = true

			perform_special_hammer_hit()

			get_tree().create_timer(
				0.5,
				false
			).timeout.connect(
				func():

					reset_states()
					is_special_jumping = false
			)


# ============================================================
# SPECIAL HAMMER LANDING HIT
# ============================================================

func perform_special_hammer_hit() -> void:

	if is_dead:
		return

	if not special_attack_hit_done:
		return

	if target == null or not is_instance_valid(target):
		return

	var distance_to_player: float = (
		global_position.distance_to(
			target.global_position
		)
	)

	if distance_to_player <= special_attack_radius:

		if target.has_method("take_damage"):

			target.take_damage(
				get_special_damage()
			)


# ============================================================
# RESET
# ============================================================

func reset_states() -> void:

	is_busy = false
	is_attacking = false
	is_using_skill = false
	is_roaring = false
	is_special_jumping = false
	special_attack_hit_done = false


# ============================================================
# HEALTH BAR SETUP
# ============================================================

func setup_health_bar() -> void:

	for child in get_children():

		if child is Sprite3D and child.name != "HealthBar3D":
			child.visible = false

		elif child is SubViewport and child.name != "HealthBarViewport":
			child.visible = false

	var existing_bar = find_child(
		"HealthBar3D",
		true,
		false
	)

	if existing_bar != null:
		existing_bar.queue_free()

	health_bar_node = Sprite3D.new()
	health_bar_node.name = "HealthBar3D"
	health_bar_node.position = Vector3(0, 2.8, 0)
	health_bar_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_node.visible = false

	add_child(health_bar_node)

	var sub_viewport = SubViewport.new()
	sub_viewport.name = "HealthBarViewport"
	sub_viewport.size = Vector2i(240, 45)
	sub_viewport.transparent_bg = true

	health_bar_node.add_child(sub_viewport)

	var panel = PanelContainer.new()
	panel.size = Vector2(240, 45)

	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.75)
	style_box.corner_radius_top_left = 6
	style_box.corner_radius_top_right = 6
	style_box.corner_radius_bottom_left = 6
	style_box.corner_radius_bottom_right = 6

	panel.add_theme_stylebox_override(
		"panel",
		style_box
	)

	sub_viewport.add_child(panel)

	health_progress_bar = ProgressBar.new()
	health_progress_bar.size = Vector2(230, 35)
	health_progress_bar.position = Vector2(5, 5)
	health_progress_bar.max_value = max_health
	health_progress_bar.value = current_health
	health_progress_bar.show_percentage = false

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.85, 0.1, 0.1, 1.0)
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4

	health_progress_bar.add_theme_stylebox_override(
		"background",
		bg_style
	)

	health_progress_bar.add_theme_stylebox_override(
		"fill",
		fill_style
	)

	panel.add_child(health_progress_bar)

	health_text_label = Label.new()
	health_text_label.size = Vector2(230, 35)
	health_text_label.position = Vector2(5, 5)

	health_text_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	health_text_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	health_text_label.text = (
		str(int(current_health)) +
		" / " +
		str(int(max_health))
	)

	panel.add_child(health_text_label)

	health_bar_node.texture = sub_viewport.get_texture()


# ============================================================
# DAMAGE
# ============================================================

func take_damage(amount: float) -> void:

	if is_dead:
		return

	if amount <= 0.0:
		return

	current_health = clamp(
		current_health - amount,
		0.0,
		max_health
	)

	if (
		health_progress_bar != null
		and health_text_label != null
		and health_bar_node != null
	):

		health_progress_bar.value = current_health

		health_text_label.text = (
			str(int(current_health)) +
			" / " +
			str(int(max_health))
		)

		health_bar_node.visible = true
		health_bar_timer = 5.0

	if target != null:

		var dir: Vector3 = (
			global_position -
			target.global_position
		).normalized()

		knockback_velocity += Vector3(
			dir.x,
			0.0,
			dir.z
		) * knockback_distance

		stun_timer = stun_time_after_hit

	add_anger(anger_gain_per_hit)

	if current_health <= 0.0:
		die()


func is_dead_now() -> bool:
	return is_dead


# ============================================================
# DEATH
# ============================================================

func die() -> void:

	if is_dead:
		return

	is_dead = true

	if health_bar_node != null:
		health_bar_node.visible = false

	reset_states()
	calm_down()

	returning_to_boundary = false

	velocity = Vector3.ZERO

	play_animation("Dead")

	disable_boss_collision()

	get_tree().create_timer(
		1.5,
		false
	).timeout.connect(
		func():

			if is_inside_tree():
				spawn_boss_rewards()
	)


func disable_boss_collision() -> void:

	collision_layer = 0
	collision_mask = 0


# ============================================================
# REWARDS
# ============================================================

func spawn_boss_rewards() -> void:

	if not is_inside_tree():
		return

	for i in range(diamond_count):

		var diamond: Node3D = create_reward_object(
			diamond_scene
		)

		if diamond != null:

			prepare_pickup(
				diamond,
				true
			)

			diamond.global_position = (
				global_position +
				Vector3(
					0.0,
					0.35,
					0.0
				)
			)

	for i in range(coin_count):

		var coin: Node3D = create_reward_object(
			coin_scene
		)

		if coin != null:

			var angle: float = (
				TAU /
				float(max(coin_count, 1))
			) * float(i)

			var radius: float = randf_range(
				1.2,
				coin_spread_radius
			)

			var target_pos: Vector3 = (
				global_position +
				Vector3(
					cos(angle) * radius,
					0.15,
					sin(angle) * radius
				)
			)

			prepare_pickup(
				coin,
				false
			)

			coin.global_position = target_pos


func create_reward_object(
	scene: PackedScene
) -> Node3D:

	if scene == null:
		return null

	var instance: Node = scene.instantiate()

	if not instance is Node3D:
		return null

	var reward: Node3D = instance as Node3D

	var parent_node: Node = get_parent()

	if parent_node == null:
		return null

	parent_node.add_child(reward)

	return reward


func prepare_pickup(
	reward: Node3D,
	is_diamond: bool
) -> void:

	if reward == null:
		return

	var area: Area3D = reward as Area3D

	if area == null:

		area = reward.find_child(
			"Area3D",
			true,
			false
		) as Area3D

	if area == null:
		return

	area.monitoring = true
	area.monitorable = true

	var pickup_is_diamond: bool = is_diamond

	area.body_entered.connect(
		func(body: Node3D) -> void:

			if body == null:
				return

			if not body.is_in_group("player"):
				return

			if pickup_is_diamond:

				if body.has_method("add_diamond"):
					body.add_diamond(1)

				reward.queue_free()

			else:

				if body.has_method("add_coin"):
					body.add_coin(1)

				reward.queue_free()
	)


# ============================================================
# HAMMER SETUP
# ============================================================

func setup_hammer() -> void:

	if skeleton == null:
		return

	var bone_index: int = skeleton.find_bone(
		hammer_bone_name
	)

	if bone_index < 0:
		return

	var existing = skeleton.find_child(
		"HammerAttachment",
		true,
		false
	)

	if existing == null:

		hammer_attachment = BoneAttachment3D.new()

		hammer_attachment.name = "HammerAttachment"

		hammer_attachment.bone_name = (
			hammer_bone_name
		)

		skeleton.add_child(
			hammer_attachment
		)

		if hammer_scene != null:

			var hammer = hammer_scene.instantiate()

			if hammer:

				hammer_attachment.add_child(
					hammer
				)


# ============================================================
# GRAVITY
# ============================================================

func apply_gravity(delta: float) -> void:

	if not is_on_floor():

		velocity.y -= gravity * delta

	elif velocity.y < 0.0:

		velocity.y = -0.5


func apply_dead_gravity(delta: float) -> void:

	if not is_on_floor():

		velocity.y -= gravity * delta


# ============================================================
# KNOCKBACK
# ============================================================

func apply_knockback(delta: float) -> void:

	if knockback_velocity.length_squared() <= 0.0001:
		return

	velocity.x += knockback_velocity.x
	velocity.z += knockback_velocity.z

	knockback_velocity = knockback_velocity.move_toward(
		Vector3.ZERO,
		5.0 * delta
	)


func apply_special_knockback(
	direction: Vector3,
	distance: float
) -> void:

	if is_dead:
		return

	direction.y = 0.0

	if direction.length_squared() <= 0.0001:
		return

	direction = direction.normalized()

	global_position += direction * distance

	knockback_velocity = Vector3.ZERO

	stun_timer = max(
		stun_timer,
		stun_time_after_hit
	)

	is_attacking = false
	is_using_skill = false
	is_busy = false
	is_special_jumping = false
	special_attack_hit_done = false

	velocity.x = 0.0
	velocity.z = 0.0


# ============================================================
# ANIMATION
# ============================================================

func play_animation(
	requested_name: String
) -> void:

	if animation_player == null:
		return

	if animation_player.has_animation(
		requested_name
	):

		if animation_player.current_animation != requested_name:

			animation_player.play(
				requested_name,
				0.15
			)


# ============================================================
# BOUNDARY HELPERS
# ============================================================

func is_inside_boundary(point: Vector3) -> bool:

	var half: float = boundary_size * 0.5

	return (
		absf(point.x - home_position.x) <= half
		and
		absf(point.z - home_position.z) <= half
	)


func clamp_to_boundary(point: Vector3) -> Vector3:

	var half: float = boundary_size * 0.5

	point.x = clampf(
		point.x,
		home_position.x - half,
		home_position.x + half
	)

	point.z = clampf(
		point.z,
		home_position.z - half,
		home_position.z + half
	)

	return point


# ============================================================
# BOUNDARY DEBUG
# ============================================================

func create_boundary_debug() -> void:

	if find_child(
		"BossBoundaryDebug",
		false,
		false
	) != null:
		return

	var half: float = boundary_size * 0.5

	var mesh := ImmediateMesh.new()

	mesh.surface_begin(
		Mesh.PRIMITIVE_LINE_STRIP
	)

	mesh.surface_add_vertex(
		Vector3(-half, 0.1, -half)
	)

	mesh.surface_add_vertex(
		Vector3(half, 0.1, -half)
	)

	mesh.surface_add_vertex(
		Vector3(half, 0.1, half)
	)

	mesh.surface_add_vertex(
		Vector3(-half, 0.1, half)
	)

	mesh.surface_add_vertex(
		Vector3(-half, 0.1, -half)
	)

	mesh.surface_end()

	var material := StandardMaterial3D.new()

	material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)

	material.albedo_color = Color(
		1.0,
		0.15,
		0.15
	)

	var boundary_line := MeshInstance3D.new()

	boundary_line.name = "BossBoundaryDebug"

	boundary_line.mesh = mesh
	boundary_line.material_override = material
	boundary_line.top_level = true

	add_child(boundary_line)

	boundary_line.global_position = home_position


# ============================================================
# BOSS ANGER
# ============================================================

func update_anger(delta: float) -> void:

	if target == null or not is_instance_valid(target):
		return

	var player_is_jumping_near: bool = false

	var distance_to_player: float = (
		global_position.distance_to(
			target.global_position
		)
	)

	if distance_to_player <= provoke_distance:

		var player_body: CharacterBody3D = (
			target as CharacterBody3D
		)

		if (
			player_body != null
			and not player_body.is_on_floor()
		):

			player_is_jumping_near = true

	if player_is_jumping_near:

		anger_level += (
			anger_gain_per_second_jumping *
			delta
		)

	else:

		anger_level -= (
			anger_decay_per_second *
			delta
		)

	anger_level = clampf(
		anger_level,
		0.0,
		anger_max
	)

	if (
		not is_angry
		and anger_level >= anger_enrage_threshold
	):

		set_angry(true)

	elif (
		is_angry
		and anger_level <= anger_calm_threshold
	):

		set_angry(false)


func add_anger(amount: float) -> void:

	if is_dead or target == null:
		return

	anger_level = clampf(
		anger_level + amount,
		0.0,
		anger_max
	)

	if (
		not is_angry
		and anger_level >= anger_enrage_threshold
	):

		set_angry(true)


func set_angry(value: bool) -> void:

	is_angry = value

	if animation_player != null:

		if value:

			animation_player.speed_scale = (
				anger_animation_speed
			)

		else:

			animation_player.speed_scale = 1.0


func calm_down() -> void:

	anger_level = 0.0

	set_angry(false)


# ============================================================
# ANGER MULTIPLIERS
# ============================================================

func get_run_speed() -> float:

	if is_angry:

		return (
			run_speed *
			anger_run_speed_multiplier
		)

	return run_speed


func get_attack_cooldown() -> float:

	if is_angry:

		return (
			attack_cooldown *
			anger_attack_cooldown_multiplier
		)

	return attack_cooldown


func get_special_cooldown() -> float:

	if is_angry:

		return (
			special_attack_cooldown *
			anger_special_cooldown_multiplier
		)

	return special_attack_cooldown


func get_attack_damage() -> float:

	if is_angry:

		return (
			attack_damage *
			anger_damage_multiplier
		)

	return attack_damage


func get_special_damage() -> float:

	if is_angry:

		return (
			special_attack_damage *
			anger_damage_multiplier
		)

	return special_attack_damage


func get_special_trigger_distance() -> float:

	if is_angry:
		return angry_special_trigger_distance

	return special_trigger_distance


func get_anim_speed() -> float:

	if is_angry:
		return anger_animation_speed

	return 1.0
