extends CharacterBody3D

# ============================================================
# KOTARO - PLAYER CONTROLLER (Full Mission, Timer, HUD & Collectibles)
# ============================================================

@export_category("Movement")
@export var walk_speed: float = 3.0
@export var run_speed: float = 5.4
@export var acceleration: float = 12.0
@export var air_control: float = 6.0
@export var jump_velocity: float = 5.5
@export var gravity: float = 16.0

@export_category("Health")
@export var max_health: float = 500.0
@export var blood_damage_threshold: float = 80.0
@export var blood_cooldown: float = 0.25

@export_category("Combat")
@export var sword_damage: float = 50.0
@export var skill_damage: float = 100.0
@export var attack_range: float = 2.0
@export var attack_angle_degrees: float = 50.0
@export var skill_range: float = 2.3
@export var skill_angle_degrees: float = 60.0
@export var attack_hit_start: float = 0.12
@export var skill_hit_start: float = 0.20

@export_category("Special Power")
@export var special_power_charge_time: float = 30.0
@export var special_power_radius: float = 1.8
@export var special_power_push_distance: float = 5.0
@export var special_power_damage: float = 20.0

@export_category("Pickup & Mission Goals")
@export var pickup_range: float = 1.4       # সংগ্রাহক রেঞ্জ
@export var target_coins: int = 20         # মোট ২০টি কয়েন
@export var target_diamonds: int = 1       # মোট ১টি ডায়মন্ড

@export_category("Timer")
@export var level_time: float = 900.0      # ১৫ মিনিট

@export_category("Camera")
@export var camera_distance: float = 4.0
@export var camera_height: float = 1.5
@export var camera_sensitivity: float = 0.20
@export var camera_min_pitch: float = -45.0
@export var camera_max_pitch: float = 60.0
@export var camera_collision_mask: int = 1

@export_category("UI Media Effects")
@export var victory_sfx: AudioStream
@export var game_over_sfx: AudioStream
@export var skull_icon: Texture2D
@export var flower_particle_icon: Texture2D

@export_category("Kotaro Action Logos")
@export var attack_logo: Texture2D
@export var jump_logo: Texture2D
@export var skill_logo: Texture2D
@export var power_logo: Texture2D
@export var sword_logo: Texture2D
@export var sword_draw_logo: Texture2D
@export_range(0.40, 0.90, 0.01) var action_logo_scale: float = 0.72

# --- Variables ---
var animation_player: AnimationPlayer
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D

var sword_back: BoneAttachment3D
var sword_hand: BoneAttachment3D

# --- Sound Variables ---
var sword_sound: AudioStreamPlayer
var sword_draw_sound: AudioStreamPlayer
var sword_hit_sound: AudioStreamPlayer
var hit_sound: AudioStreamPlayer
var skill_sound: AudioStreamPlayer
var walk_sound: AudioStreamPlayer
var run_sound: AudioStreamPlayer
var pickup_sound: AudioStreamPlayer
var special_power_sound: AudioStreamPlayer

var current_health: float = 500.0
var damage_accumulator: float = 0.0
var blood_timer: float = 0.0
var is_dead: bool = false
var is_attacking: bool = false
var is_using_skill: bool = false
var is_combat_stance: bool = false

# Score & Collectible Counts
var current_coins: int = 0
var current_diamonds: int = 0

var camera_yaw: float = 0.0
var camera_pitch: float = -10.0
var camera_touch_id: int = -1
var last_stance_toggle_time: int = 0

var special_power_charge: float = 0.0

var joystick_value: Vector2 = Vector2.ZERO
var joystick_touch_id: int = -1
var joystick_active: bool = false
var joystick_base: Control
var joystick_knob: Control

var mobile_jump_requested: bool = false
var mobile_attack_requested: bool = false
var mobile_skill_requested: bool = false
var mobile_special_requested: bool = false

var hud_layer: CanvasLayer
var hud_root: Control
var attack_button: Button
var jump_button: Button
var skill_button: Button
var special_button: Button
var weapon_slot_button: Button
var edit_button: Button
var done_button: Button
var reset_button: Button
var hud_buttons: Array[Control] = []
var hud_edit_mode: bool = false
var dragging_control: Control = null
var dragging_touch_id: int = -1
var selected_resize_control: Control = null
var resize_step: float = 10.0

const HUD_SAVE_PATH: String = "user://kotaro_hud_layout.cfg"

const ACTION_RESIZE_MIN: float = 45.0
const ACTION_RESIZE_MAX: float = 180.0


# 3D Target Ring Indicator
var target_indicator_3d: MeshInstance3D
var target_indicator_mat: StandardMaterial3D

# UI Elements
var health_bar_bg: Control
var health_bar_fill: Control
var health_bar_label: Label

var timer_label: Label
var coin_label: Label
var diamond_label: Label
var coin_icon: Control
var diamond_icon: Control

var victory_label: Label
var game_over_panel: ColorRect
var game_over_box: VBoxContainer
var game_over_label: Label
var skull_rect: TextureRect
var game_ended: bool = false

var ui_audio_player: AudioStreamPlayer
var flower_particles: GPUParticles2D

@onready var sword_trail: GPUParticles3D = find_child("SwordTrail", true, false) as GPUParticles3D
@onready var sword_aura: GPUParticles3D = find_child("SwordAura", true, false)


func _ready() -> void:
	add_to_group("player")
	current_health = max_health

	find_player_nodes()
	start_aura_cycle()
	setup_camera()
	setup_audio()
	setup_mobile_hud()
	setup_3d_target_indicator()
	create_health_bar()
	setup_game_state_ui()
	set_combat_stance(false)

	get_viewport().size_changed.connect(_on_viewport_resized)
	camera_yaw = rotation_degrees.y
	camera_pitch = -10.0
	update_camera()
	play_animation("Idle")


func find_player_nodes() -> void:
	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	camera_pivot = find_child("CameraPivot", true, false) as Node3D
	spring_arm = find_child("SpringArm3D", true, false) as SpringArm3D
	camera = find_child("Camera3D", true, false) as Camera3D

	sword_back = find_child("SwordBack", true, false) as BoneAttachment3D
	sword_hand = find_child("SwordHand", true, false) as BoneAttachment3D

	sword_sound = find_child("SwordSound", true, false) as AudioStreamPlayer
	sword_draw_sound = find_child("SwordDrawSound", true, false) as AudioStreamPlayer
	sword_hit_sound = find_child("SwordHitSound", true, false) as AudioStreamPlayer
	hit_sound = find_child("HitSound", true, false) as AudioStreamPlayer
	skill_sound = find_child("SkillSound", true, false) as AudioStreamPlayer
	walk_sound = find_child("WalkSound", true, false) as AudioStreamPlayer
	run_sound = find_child("RunSound", true, false) as AudioStreamPlayer
	pickup_sound = find_child("PickupSound", true, false) as AudioStreamPlayer
	special_power_sound = find_child("SpecialPowerSound", true, false) as AudioStreamPlayer


func setup_camera() -> void:
	if camera_pivot != null:
		camera_pivot.top_level = true
	if spring_arm != null:
		spring_arm.spring_length = camera_distance
		spring_arm.margin = 0.15
		spring_arm.collision_mask = camera_collision_mask
		spring_arm.add_excluded_object(get_rid())
	if camera != null:
		camera.current = true


func setup_audio() -> void:
	pass


func update_camera() -> void:
	if camera_pivot == null:
		return
	camera_pivot.global_position = global_position + Vector3(0.0, camera_height, 0.0)
	camera_pivot.rotation_degrees.x = camera_pitch
	camera_pivot.rotation_degrees.y = camera_yaw


# ============================================================
# GAME STATE UI & ICONS
# ============================================================

func setup_game_state_ui() -> void:
	if hud_root == null: return

	ui_audio_player = AudioStreamPlayer.new()
	add_child(ui_audio_player)

	var screen_size: Vector2 = get_viewport().get_visible_rect().size

	timer_label = Label.new()
	timer_label.position = Vector2(screen_size.x / 2.0 - 60, 15)
	timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.text = "Time: 15:00"
	hud_root.add_child(timer_label)

	coin_icon = Control.new()
	coin_icon.custom_minimum_size = Vector2(20, 20)
	coin_icon.position = Vector2(115, 55)
	coin_icon.draw.connect(_on_coin_icon_draw)
	hud_root.add_child(coin_icon)

	coin_label = Label.new()
	coin_label.position = Vector2(140, 55)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	coin_label.add_theme_font_size_override("font_size", 18)
	coin_label.text = "Coins: 0 / %d" % target_coins
	hud_root.add_child(coin_label)

	diamond_icon = Control.new()
	diamond_icon.custom_minimum_size = Vector2(20, 20)
	diamond_icon.position = Vector2(115, 80)
	diamond_icon.draw.connect(_on_diamond_icon_draw)
	hud_root.add_child(diamond_icon)

	diamond_label = Label.new()
	diamond_label.position = Vector2(140, 80)
	diamond_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	diamond_label.add_theme_font_size_override("font_size", 18)
	diamond_label.text = "Diamonds: 0 / %d" % target_diamonds
	hud_root.add_child(diamond_label)

	victory_label = Label.new()
	victory_label.text = "VICTORY"
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory_label.set_anchors_preset(Control.PRESET_CENTER)
	victory_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	victory_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	victory_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	victory_label.add_theme_font_size_override("font_size", 72)
	victory_label.visible = false
	hud_root.add_child(victory_label)

	flower_particles = GPUParticles2D.new()
	flower_particles.amount = 35
	flower_particles.lifetime = 3.0
	flower_particles.position = Vector2(screen_size.x / 2.0, -20)
	if flower_particle_icon != null:
		flower_particles.texture = flower_particle_icon

	var p_mat := ParticleProcessMaterial.new()
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 80.0
	p_mat.initial_velocity_min = 100.0
	p_mat.initial_velocity_max = 250.0
	p_mat.gravity = Vector3(0, 120, 0)
	flower_particles.process_material = p_mat
	flower_particles.emitting = false
	hud_root.add_child(flower_particles)

	game_over_panel = ColorRect.new()
	game_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_panel.color = Color(0.0, 0.0, 0.0, 1.0)
	game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_panel.visible = false
	hud_root.add_child(game_over_panel)

	game_over_box = VBoxContainer.new()
	game_over_box.set_anchors_preset(Control.PRESET_CENTER)
	game_over_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	game_over_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	game_over_box.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_box.add_theme_constant_override("separation", 20)
	game_over_panel.add_child(game_over_box)

	skull_rect = TextureRect.new()
	if skull_icon != null:
		skull_rect.texture = skull_icon
	skull_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skull_rect.custom_minimum_size = Vector2(140, 140)
	skull_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game_over_box.add_child(skull_rect)

	game_over_label = Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	game_over_label.add_theme_font_size_override("font_size", 64)
	game_over_box.add_child(game_over_label)


func _on_coin_icon_draw() -> void:
	if coin_icon == null: return
	var center := Vector2(10, 10)
	coin_icon.draw_circle(center, 7.5, Color(1.0, 0.84, 0.0))
	coin_icon.draw_arc(center, 7.5, 0, TAU, 24, Color(0.85, 0.65, 0.0), 1.5)

func _on_diamond_icon_draw() -> void:
	if diamond_icon == null: return
	var points := PackedVector2Array([
		Vector2(10, 2),
		Vector2(18, 10),
		Vector2(10, 18),
		Vector2(2, 10)
	])
	diamond_icon.draw_colored_polygon(points, Color(0.2, 0.8, 1.0))
	diamond_icon.draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0.0, 0.5, 0.95), 1.5)


# ============================================================
# VICTORY CONDITION
# ============================================================

func check_victory_condition() -> void:
	if game_ended or is_dead:
		return

	var enemies := get_tree().get_nodes_in_group("enemy")
	var alive_count: int = 0

	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy):
			if enemy.has_method("is_dead_now"):
				if not enemy.is_dead_now():
					alive_count += 1
			else:
				alive_count += 1

	var all_enemies_defeated: bool = (enemies.size() > 0 and alive_count == 0) or (enemies.size() == 0)
	var coins_collected: bool = (current_coins >= target_coins)
	var diamonds_collected: bool = (current_diamonds >= target_diamonds)

	if all_enemies_defeated and coins_collected and diamonds_collected:
		show_victory()


func show_victory() -> void:
	if game_ended: return
	game_ended = true
	
	if victory_label != null:
		victory_label.visible = true
		
	if flower_particles != null:
		flower_particles.emitting = true
		
	if ui_audio_player != null and victory_sfx != null:
		ui_audio_player.stream = victory_sfx
		ui_audio_player.play()


func show_game_over() -> void:
	if game_ended: return
	game_ended = true
	
	if game_over_panel != null:
		game_over_panel.visible = true
		
	if ui_audio_player != null and game_over_sfx != null:
		ui_audio_player.stream = game_over_sfx
		ui_audio_player.play()


# ============================================================
# 3D TARGET RING & STANCE
# ============================================================

func setup_3d_target_indicator() -> void:
	target_indicator_3d = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.04
	torus.outer_radius = 0.07

	target_indicator_mat = StandardMaterial3D.new()
	target_indicator_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	target_indicator_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	target_indicator_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.8)

	target_indicator_3d.mesh = torus
	target_indicator_3d.material_override = target_indicator_mat
	target_indicator_3d.rotation_degrees.x = 90.0
	
	add_child(target_indicator_3d)
	target_indicator_3d.top_level = true


func update_3d_target_indicator(delta: float) -> void:
	if target_indicator_3d == null:
		return
		
	if is_dead or not is_combat_stance or hud_edit_mode:
		target_indicator_3d.visible = false
		return
	else:
		target_indicator_3d.visible = true

	var target := find_auto_target(attack_range + 0.5, attack_angle_degrees + 10.0)
	var dest_pos: Vector3

	if target != null:
		target_indicator_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.9)
		dest_pos = target.global_position + Vector3(0.0, 0.2, 0.0)
	else:
		target_indicator_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
		dest_pos = global_position + (global_transform.basis.z * 1.5) + Vector3(0.0, 1.1, 0.0)

	target_indicator_3d.global_position = target_indicator_3d.global_position.lerp(dest_pos, 25.0 * delta)
	target_indicator_3d.rotation_degrees.y = rotation_degrees.y


func set_combat_stance(enabled: bool) -> void:
	is_combat_stance = enabled
	
	if sword_back != null:
		sword_back.visible = not enabled
		for child in sword_back.get_children():
			if child is Node3D:
				child.visible = not enabled
				
	if sword_hand != null:
		sword_hand.visible = enabled
		for child in sword_hand.get_children():
			if child is Node3D:
				child.visible = enabled

	if weapon_slot_button != null:
		if sword_logo == null and sword_draw_logo == null:
			weapon_slot_button.text = "[ SWORD ]" if enabled else "SWORD"
		update_sword_logo()
	if enabled and sword_draw_sound != null:
		sword_draw_sound.play()


func toggle_combat_stance() -> void:
	if hud_edit_mode or is_dead:
		return
	var now: int = Time.get_ticks_msec()
	if now - last_stance_toggle_time < 300:
		return
	last_stance_toggle_time = now
	set_combat_stance(not is_combat_stance)


# ============================================================
# PHYSICS & GAME LOOP
# ============================================================

func _physics_process(delta: float) -> void:
	if current_health <= 0.0 and not is_dead:
		die()

	if blood_timer > 0.0:
		blood_timer -= delta

	if special_power_charge < special_power_charge_time:
		special_power_charge = min(special_power_charge_time, special_power_charge + delta)

	check_victory_condition()

	if not game_ended and not is_dead and not hud_edit_mode:
		if level_time > 0.0:
			level_time -= delta
			var mins: int = int(level_time / 60.0)
			var secs: int = int(level_time) % 60
			if timer_label != null:
				timer_label.text = "Time: %02d:%02d" % [mins, secs]
		else:
			level_time = 0.0
			if timer_label != null:
				timer_label.text = "Time: 00:00"
			show_game_over()

	if is_dead or hud_edit_mode:
		velocity.x = 0.0
		velocity.z = 0.0
		handle_gravity(delta)
		update_ui(delta)
		move_and_slide()
		return

	handle_gravity(delta)
	handle_jump()
	handle_movement(delta)
	handle_mobile_actions()
	update_camera()
	update_animation()
	update_footstep_sound()
	update_ui(delta)
	update_3d_target_indicator(delta)
	update_pickups()
	move_and_slide()


func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func handle_jump() -> void:
	if hud_edit_mode:
		mobile_jump_requested = false
		return
	if mobile_jump_requested and is_on_floor() and not is_attacking and not is_using_skill:
		velocity.y = jump_velocity
		
		if has_node("JumpSound") and $JumpSound is AudioStreamPlayer:
			$JumpSound.play()
			
		mobile_jump_requested = false


func handle_movement(delta: float) -> void:
	if hud_edit_mode or is_attacking or is_using_skill:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		return

	var pull: float = joystick_value.length()
	var input_vector: Vector2 = joystick_value.limit_length(1.0)
	var direction: Vector3 = Vector3.ZERO

	if pull > 0.05 and camera_pivot != null:
		var forward: Vector3 = -camera_pivot.global_transform.basis.z
		var right: Vector3 = camera_pivot.global_transform.basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()
		direction = (right * input_vector.x + forward * -input_vector.y).normalized()

	var speed: float = lerp(walk_speed, run_speed, clamp(pull, 0.0, 1.0))
	var target_velocity: Vector3 = direction * speed

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if direction.length() > 0.05:
		var target_angle: float = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 12.0 * delta)


func update_footstep_sound() -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var moving_on_ground: bool = is_on_floor() and horizontal_speed > 0.3 and not is_attacking and not is_using_skill

	if not moving_on_ground:
		if walk_sound != null and walk_sound.playing: walk_sound.stop()
		if run_sound != null and run_sound.playing: run_sound.stop()
		return

	if horizontal_speed > walk_speed * 1.2:
		if run_sound != null and not run_sound.playing: run_sound.play()
		if walk_sound != null and walk_sound.playing: walk_sound.stop()
	else:
		if walk_sound != null and not walk_sound.playing: walk_sound.play()
		if run_sound != null and run_sound.playing: run_sound.stop()


# ============================================================
# ANIMATION & DEATH SYSTEM
# ============================================================

func update_animation() -> void:
	if is_dead or hud_edit_mode:
		return

	if is_attacking or is_using_skill:
		return

	if not is_on_floor():
		play_animation("Sword_Idle" if is_combat_stance else "Idle")
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()

	if horizontal_speed < 0.2:
		play_animation("Sword_Idle" if is_combat_stance else "Idle")
	elif horizontal_speed > walk_speed * 1.2:
		play_animation("Sword_Run" if is_combat_stance else "Run")
	else:
		play_animation("Sword_Walk" if is_combat_stance else "Walk")


func play_animation(requested_name: String) -> void:
	if animation_player == null:
		return
	if is_dead and requested_name != "Dead":
		return
		
	var actual_name: String = resolve_animation_name(requested_name)
	if actual_name != "" and animation_player.current_animation != actual_name:
		animation_player.play(actual_name, 0.16)


func resolve_animation_name(requested_name: String) -> String:
	if animation_player == null:
		return ""
		
	if animation_player.has_animation(requested_name):
		return requested_name

	var list: PackedStringArray = animation_player.get_animation_list()
	var req_lower: String = requested_name.to_lower()

	for anim_name in list:
		if anim_name.to_lower() == req_lower:
			return anim_name

	for anim_name in list:
		var clean_name: String = anim_name
		if "|" in clean_name:
			clean_name = clean_name.split("|")[-1]
		elif "/" in clean_name:
			clean_name = clean_name.split("/")[-1]
		if clean_name.to_lower() == req_lower:
			return anim_name

	for anim_name in list:
		if req_lower in anim_name.to_lower():
			return anim_name

	return ""


func get_animation_length(requested_name: String) -> float:
	if animation_player == null:
		return 0.0
	var actual_name: String = resolve_animation_name(requested_name)
	if actual_name == "":
		return 0.0
	var animation: Animation = animation_player.get_animation(actual_name)
	return animation.length if animation != null else 0.0


func die() -> void:
	if is_dead: return
	
	if current_health > 0.0:
		return
		
	is_dead = true
	current_health = 0.0
	update_ui(0.0)
	
	is_attacking = false
	is_using_skill = false
	velocity = Vector3.ZERO
	
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	
	if target_indicator_3d != null:
		target_indicator_3d.visible = false
		
	if animation_player != null:
		var dead_anim: String = resolve_animation_name("Dead")
		if dead_anim == "":
			dead_anim = resolve_animation_name("Die")
		if dead_anim == "":
			dead_anim = resolve_animation_name("Death")
			
		if dead_anim != "":
			animation_player.stop()
			var anim_obj: Animation = animation_player.get_animation(dead_anim)
			if anim_obj != null:
				anim_obj.loop_mode = Animation.LOOP_NONE
			animation_player.play(dead_anim, 0.1)

	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(self):
		var fall_tween := create_tween()
		fall_tween.tween_property(self, "rotation:x", deg_to_rad(85.0), 0.55)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fall_tween.parallel().tween_property(self, "global_position:y", global_position.y - 0.30, 0.55)

	await get_tree().create_timer(10.0).timeout
	if is_instance_valid(self):
		show_game_over()


# ============================================================
# COMBAT & DAMAGE SYSTEM
# ============================================================

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0 or hud_edit_mode:
		return

	current_health = clamp(current_health - amount, 0.0, max_health)
	damage_accumulator += amount

	if damage_accumulator >= blood_damage_threshold:
		damage_accumulator -= blood_damage_threshold
		if hit_sound != null: hit_sound.play()

	if blood_timer <= 0.0:
		blood_timer = blood_cooldown
		var particle_amount: int = 5
		if current_health <= 100.0:
			particle_amount = 18
		elif current_health <= 300.0:
			particle_amount = 12
		spawn_blood_effect(particle_amount)

	if current_health <= 0.0:
		die()


func attack() -> void:
	if hud_edit_mode or is_dead or is_attacking or is_using_skill:
		return
	if not is_combat_stance:
		toggle_combat_stance()
		return

	is_attacking = true
	play_animation("Sword_Attack")
	
	if sword_sound != null: 
		sword_sound.play()

	activate_sword_trail(true)

	var attack_length: float = get_animation_length("Sword_Attack")
	if attack_length <= 0.0: attack_length = 0.6

	await get_tree().create_timer(attack_hit_start).timeout
	if not is_inside_tree() or is_dead or hud_edit_mode:
		is_attacking = false
		activate_sword_trail(false)
		return

	if perform_auto_target_hit(sword_damage, attack_range, attack_angle_degrees):
		if sword_hit_sound != null: 
			sword_hit_sound.play()

	var remaining: float = max(0.0, attack_length - attack_hit_start)
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout
		
	is_attacking = false
	activate_sword_trail(false)


func use_skill() -> void:
	if hud_edit_mode or is_dead or is_attacking or is_using_skill:
		return
	if not is_combat_stance:
		toggle_combat_stance()
		return

	is_using_skill = true
	play_animation("Sword_Skill")
	if skill_sound != null: 
		skill_sound.play()

	activate_sword_trail(true)

	var skill_length: float = get_animation_length("Sword_Skill")
	if skill_length <= 0.0: skill_length = 1.0

	await get_tree().create_timer(skill_hit_start).timeout
	if not is_inside_tree() or is_dead or hud_edit_mode:
		is_using_skill = false
		activate_sword_trail(false)
		return

	if perform_auto_target_hit(skill_damage, skill_range, skill_angle_degrees):
		if sword_hit_sound != null: 
			sword_hit_sound.play()

	var remaining: float = max(0.0, skill_length - skill_hit_start)
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout
		
	is_using_skill = false
	activate_sword_trail(false)


func activate_sword_trail(enable: bool) -> void:
	if sword_trail != null and is_instance_valid(sword_trail):
		sword_trail.emitting = enable
	else:
		if sword_hand != null:
			var trail_node := sword_hand.find_child("SwordTrail", true, false) as GPUParticles3D
			if trail_node != null:
				trail_node.emitting = enable


func find_auto_target(max_range: float, max_angle_degrees: float) -> Node3D:
	var forward: Vector3 = global_transform.basis.z 
	forward.y = 0.0
	forward = forward.normalized()
	
	var best_target: Node3D = null
	var best_distance: float = INF

	for node in get_tree().get_nodes_in_group("enemy"):
		var target := node as Node3D
		if target == null or target == self:
			continue
		if target.has_method("is_dead_now") and target.is_dead_now():
			continue

		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		var distance: float = to_target.length()
		if distance > max_range:
			continue

		var angle: float = rad_to_deg(forward.angle_to(to_target.normalized()))
		if angle > max_angle_degrees:
			continue

		if distance < best_distance:
			best_distance = distance
			best_target = target

	return best_target


func perform_auto_target_hit(damage: float, max_range: float, max_angle_degrees: float) -> bool:
	var target := find_auto_target(max_range, max_angle_degrees)
	if target != null and target.has_method("take_damage"):
		target.take_damage(damage)
		return true
	return false


# ============================================================
# SPECIAL POWER & BLAST
# ============================================================

func try_special_power() -> void:
	if hud_edit_mode or is_dead:
		return
	if special_power_charge < special_power_charge_time:
		return

	special_power_charge = 0.0
	if special_power_sound != null:
		special_power_sound.play()

	spawn_red_power_blast_effect()

	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node3D
		if enemy == null:
			continue
		if enemy.has_method("is_dead_now") and enemy.is_dead_now():
			continue

		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		var distance: float = offset.length()
		
		if distance > special_power_radius:
			continue

		var direction: Vector3 = offset.normalized() if distance > 0.01 else global_transform.basis.z

		if enemy.has_method("take_damage"):
			enemy.take_damage(special_power_damage)

		if enemy.has_method("apply_special_knockback"):
			enemy.apply_special_knockback(direction, special_power_push_distance)
		elif enemy.has_method("apply_knockback"):
			enemy.apply_knockback(direction, special_power_push_distance)
		else:
			enemy.global_position = global_position + (direction * special_power_push_distance)


func spawn_red_power_blast_effect() -> void:
	var blast_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.05, 0.05, 0.85)

	blast_mesh.mesh = sphere
	blast_mesh.material_override = mat
	add_child(blast_mesh)
	blast_mesh.global_position = global_position + Vector3(0, 1.0, 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(blast_mesh, "scale", Vector3(3.6, 3.6, 3.6), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)

	await tween.finished
	if is_instance_valid(blast_mesh):
		blast_mesh.queue_free()


# ============================================================
# MANUAL PICKUP COLLECTION SYSTEM
# ============================================================

func update_pickups() -> void:
	if hud_edit_mode or is_dead:
		return

	for node in get_tree().get_nodes_in_group("pickup"):
		var pickup := node as Node3D
		if pickup == null or not is_instance_valid(pickup):
			continue

		# প্লেয়ার থেকে আইটেমের দূরত্ব নির্ণয়
		var distance: float = global_position.distance_to(pickup.global_position)
		if distance <= pickup_range:
			collect_pickup(pickup)


func collect_pickup(pickup: Node3D) -> void:
	if not pickup.has_meta("pickup_type"):
		return

	var pickup_type: String = pickup.get_meta("pickup_type")
	var pickup_value: float = pickup.get_meta("pickup_value") if pickup.has_meta("pickup_value") else 1.0
	
	match pickup_type.to_lower():
		"hp", "health":
			add_health(pickup_value)
		"coin", "coins":
			current_coins += int(max(1, pickup_value))
			if has_node("CoinSound") and $CoinSound is AudioStreamPlayer:
				$CoinSound.play()
		"diamond", "diamonds", "gem":
			current_diamonds += int(max(1, pickup_value))

	if pickup_sound != null:
		pickup_sound.play()

	# সংগ্রহ করার পর বস্তুটি দৃশ্যপট থেকে মুছে দেওয়া
	pickup.queue_free()


func add_health(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = min(max_health, current_health + amount)


# ============================================================
# UI UPDATE
# ============================================================

func create_health_bar() -> void:
	health_bar_bg = Control.new()
	health_bar_bg.name = "HealthBarBG"
	health_bar_bg.size = Vector2(220, 28)
	health_bar_bg.position = Vector2(140, 20)
	health_bar_bg.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg_panel := Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	health_bar_bg.add_child(bg_panel)

	health_bar_fill = Control.new()
	health_bar_fill.name = "HealthBarFill"
	health_bar_fill.position = Vector2(3, 3)
	health_bar_fill.size = Vector2(214, 22)
	health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar_fill.draw.connect(_on_health_bar_draw)
	health_bar_bg.add_child(health_bar_fill)

	health_bar_label = Label.new()
	health_bar_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_bar_label.add_theme_color_override("font_color", Color(1, 1, 1))
	health_bar_bg.add_child(health_bar_label)

	hud_root.add_child(health_bar_bg)
	health_bar_bg.gui_input.connect(_on_hud_control_input.bind(health_bar_bg))
	hud_buttons.append(health_bar_bg)


func _on_health_bar_draw() -> void:
	var fraction: float = clamp(current_health / max_health, 0.0, 1.0)
	var color: Color
	if fraction > 0.5:
		color = Color(0.2, 0.8, 0.2)
	elif fraction > 0.2:
		color = Color(0.9, 0.8, 0.1)
	else:
		color = Color(0.85, 0.15, 0.15)
	var width: float = health_bar_fill.size.x * fraction
	health_bar_fill.draw_rect(Rect2(Vector2.ZERO, Vector2(width, health_bar_fill.size.y)), color)


func update_ui(_delta: float) -> void:
	if health_bar_fill != null:
		health_bar_fill.queue_redraw()
	if health_bar_label != null:
		health_bar_label.text = "%d / %d" % [int(ceil(current_health)), int(max_health)]
	
	if coin_label != null:
		coin_label.text = "Coins: %d / %d" % [current_coins, target_coins]
	if diamond_label != null:
		diamond_label.text = "Diamonds: %d / %d" % [current_diamonds, target_diamonds]

	if special_button != null:
		var charged: bool = special_power_charge >= special_power_charge_time
		special_button.modulate = Color(0.4, 1.0, 0.4) if charged else Color(0.6, 0.6, 0.6)
		var percent: int = int((special_power_charge / special_power_charge_time) * 100.0)
		if power_logo == null:
			special_button.text = "POWER" if charged else ("%d%%" % percent)
		else:
			special_button.text = ""


func is_dead_now() -> bool:
	return is_dead


func spawn_blood_effect(particle_amount: int) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = particle_amount
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.35

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.direction = Vector3.UP
	process_material.spread = 35.0
	process_material.initial_velocity_min = 2.0
	process_material.initial_velocity_max = 5.0
	process_material.gravity = Vector3(0.0, -8.0, 0.0)
	particles.process_material = process_material

	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.02, 0.02, 1.0)
	sphere.material = material
	particles.draw_pass_1 = sphere

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0.0, 1.0, 0.0)
	particles.restart()

	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(particles): particles.queue_free()


# ============================================================
# MOBILE CONTROLS & HUD
# ============================================================

func handle_mobile_actions() -> void:
	if hud_edit_mode:
		mobile_jump_requested = false
		mobile_attack_requested = false
		mobile_skill_requested = false
		mobile_special_requested = false
		return

	if mobile_attack_requested:
		mobile_attack_requested = false
		attack()
	if mobile_skill_requested:
		mobile_skill_requested = false
		use_skill()
	if mobile_special_requested:
		mobile_special_requested = false
		try_special_power()


func setup_mobile_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "MobileHUD"
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.name = "HUDRoot"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_layer.add_child(hud_root)

	var screen_size: Vector2 = get_viewport().get_visible_rect().size

	joystick_base = create_hud_control("JoystickBase", Vector2(160, 160))
	joystick_base.position = Vector2(40, screen_size.y - 200)
	joystick_base.draw.connect(_on_joystick_base_draw)
	hud_root.add_child(joystick_base)

	joystick_knob = create_hud_control("JoystickKnob", Vector2(50, 50))
	joystick_knob.position = (joystick_base.size * 0.5) - (joystick_knob.size * 0.5)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.draw.connect(_on_joystick_knob_draw)
	joystick_base.add_child(joystick_knob)
	joystick_knob.visible = false
	
	joystick_base.gui_input.connect(_on_joystick_input)

	attack_button = create_button("ATTACK", Vector2(85, 85))
	make_action_button_round(attack_button)
	attack_button.position = Vector2(screen_size.x - 120, screen_size.y - 130)
	attack_button.pressed.connect(func(): if not hud_edit_mode: mobile_attack_requested = true)

	jump_button = create_button("JUMP", Vector2(70, 70))
	make_action_button_round(jump_button)
	jump_button.position = Vector2(screen_size.x - 210, screen_size.y - 190)
	jump_button.pressed.connect(func(): if not hud_edit_mode: mobile_jump_requested = true)

	skill_button = create_button("SKILL", Vector2(75, 75))
	make_action_button_round(skill_button)
	skill_button.position = Vector2(screen_size.x - 130, screen_size.y - 230)
	skill_button.pressed.connect(func(): if not hud_edit_mode: mobile_skill_requested = true)

	special_button = create_button("0%", Vector2(70, 70))
	make_action_button_round(special_button)
	special_button.position = Vector2(screen_size.x - 220, screen_size.y - 105)
	special_button.pressed.connect(func(): if not hud_edit_mode: mobile_special_requested = true)

	# Put Kotaro action logos inside the circular buttons when textures are assigned in the Inspector.
	setup_kotaro_action_logos()

	weapon_slot_button = create_button("SWORD", Vector2(140, 65))
	weapon_slot_button.position = Vector2(screen_size.x - 160, 20)
	weapon_slot_button.pressed.connect(func(): if not hud_edit_mode: toggle_combat_stance())

	edit_button = create_button("EDIT", Vector2(90, 60))
	edit_button.position = Vector2(20, 20)
	edit_button.pressed.connect(enter_hud_edit_mode)

	reset_button = create_button("RESET", Vector2(90, 60))
	reset_button.position = Vector2(20, 20)
	reset_button.pressed.connect(reset_hud_layout)
	reset_button.visible = false

	done_button = create_button("DONE", Vector2(90, 60))
	done_button.position = Vector2(20, 90)
	done_button.pressed.connect(exit_hud_edit_mode)
	done_button.visible = false

	# Size controls: only the four circular action buttons can be resized.
	var size_plus_button := create_button("+", Vector2(55, 55))
	size_plus_button.name = "HUDSizePlus"
	size_plus_button.position = Vector2(20, 165)
	size_plus_button.pressed.connect(func(): resize_selected_action(1.0))
	size_plus_button.visible = false

	var size_minus_button := create_button("-", Vector2(55, 55))
	size_minus_button.name = "HUDSizeMinus"
	size_minus_button.position = Vector2(20, 230)
	size_minus_button.pressed.connect(func(): resize_selected_action(-1.0))
	size_minus_button.visible = false

	hud_buttons = [attack_button, jump_button, skill_button, special_button, weapon_slot_button]
	for button in hud_buttons:
		button.gui_input.connect(_on_hud_control_input.bind(button))

	load_hud_layout()
	setup_kotaro_action_logos()


func _on_joystick_base_draw() -> void:
	if joystick_base == null: return
	var center: Vector2 = joystick_base.size / 2.0
	var radius: float = joystick_base.size.x / 2.0
	joystick_base.draw_circle(center, radius, Color(0, 0, 0, 0.3))
	joystick_base.draw_arc(center, radius, 0, TAU, 32, Color(1, 1, 1, 0.5), 3.0)


func _on_joystick_knob_draw() -> void:
	if joystick_knob == null: return
	var center: Vector2 = joystick_knob.size / 2.0
	var radius: float = joystick_knob.size.x / 2.0
	joystick_knob.draw_circle(center, radius, Color(1, 1, 1, 0.85))


func setup_kotaro_action_logos() -> void:
	set_action_logo(attack_button, attack_logo, "ATTACK")
	set_action_logo(jump_button, jump_logo, "JUMP")
	set_action_logo(skill_button, skill_logo, "SKILL")
	set_action_logo(special_button, power_logo, "POWER")
	update_sword_logo()


func set_action_logo(button: Button, texture: Texture2D, fallback_text: String) -> void:
	if button == null:
		return

	if texture != null:
		button.icon = texture
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", int(min(button.size.x, button.size.y) * action_logo_scale))
		button.add_theme_constant_override("icon_max_height", int(min(button.size.x, button.size.y) * action_logo_scale))
		button.text = ""
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		button.icon = null
		button.text = fallback_text


func update_action_logo_size(button: Button) -> void:
	if button == null or button.icon == null:
		return
	var icon_side: int = int(min(button.size.x, button.size.y) * action_logo_scale)
	button.add_theme_constant_override("icon_max_width", icon_side)
	button.add_theme_constant_override("icon_max_height", icon_side)


func update_sword_logo() -> void:
	if weapon_slot_button == null:
		return

	var sword_texture: Texture2D = sword_logo if is_combat_stance else sword_draw_logo
	if sword_texture == null:
		sword_texture = sword_logo if sword_logo != null else sword_draw_logo

	if sword_texture != null:
		weapon_slot_button.icon = sword_texture
		weapon_slot_button.expand_icon = true
		weapon_slot_button.add_theme_constant_override("icon_max_width", int(min(weapon_slot_button.size.x * 0.55, weapon_slot_button.size.y * 0.75)))
		weapon_slot_button.add_theme_constant_override("icon_max_height", int(min(weapon_slot_button.size.x * 0.55, weapon_slot_button.size.y * 0.75)))
		weapon_slot_button.text = ""
		weapon_slot_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		weapon_slot_button.icon = null
		weapon_slot_button.text = "[ SWORD ]" if is_combat_stance else "SWORD"


func create_hud_control(control_name: String, control_size: Vector2) -> Control:
	var control := Control.new()
	control.name = control_name
	control.size = control_size
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	return control


func is_resizable_action(control: Control) -> bool:
	return control == attack_button or control == jump_button or control == skill_button or control == special_button


func make_action_button_round(button: Button) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.08, 0.08, 0.72)
	normal.corner_radius_top_left = 100
	normal.corner_radius_top_right = 100
	normal.corner_radius_bottom_left = 100
	normal.corner_radius_bottom_right = 100

	var hover := normal.duplicate()
	hover.bg_color = Color(0.16, 0.16, 0.16, 0.82)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.03, 0.03, 0.03, 0.92)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", normal)


func update_action_round_shape(button: Button) -> void:
	if button == null:
		return
	var radius: int = int(min(button.size.x, button.size.y) * 0.5)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := button.get_theme_stylebox(state)
		if style is StyleBoxFlat:
			var flat: StyleBoxFlat = style.duplicate()
			flat.corner_radius_top_left = radius
			flat.corner_radius_top_right = radius
			flat.corner_radius_bottom_left = radius
			flat.corner_radius_bottom_right = radius
			button.add_theme_stylebox_override(state, flat)


func resize_selected_action(direction: float) -> void:
	if not hud_edit_mode or selected_resize_control == null:
		return
	if not is_resizable_action(selected_resize_control):
		return

	var old_size: Vector2 = selected_resize_control.size
	var new_side: float = clamp(old_size.x + (resize_step * direction), ACTION_RESIZE_MIN, ACTION_RESIZE_MAX)
	var new_size := Vector2(new_side, new_side)
	var center: Vector2 = selected_resize_control.position + old_size * 0.5
	selected_resize_control.size = new_size
	selected_resize_control.position = center - new_size * 0.5
	update_action_round_shape(selected_resize_control)
	update_action_logo_size(selected_resize_control as Button)
	clamp_control_to_screen(selected_resize_control)


func set_size_controls_visible(visible_state: bool) -> void:
	var plus := hud_root.get_node_or_null("HUDSizePlus") as Button
	var minus := hud_root.get_node_or_null("HUDSizeMinus") as Button
	if plus != null:
		plus.visible = visible_state
	if minus != null:
		minus.visible = visible_state


func create_button(text_value: String, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.size = button_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_root.add_child(button)
	return button


func _on_joystick_input(event: InputEvent) -> void:
	if hud_edit_mode:
		_on_hud_control_input(event, joystick_base)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			joystick_active = true
			joystick_touch_id = event.index
			update_joystick_global(event.position)
		elif event.index == joystick_touch_id:
			reset_joystick()


func update_joystick_global(global_touch_pos: Vector2) -> void:
	if joystick_base == null: return
	var center: Vector2 = joystick_base.global_position + (joystick_base.size * 0.5)
	var offset: Vector2 = global_touch_pos - center
	var radius: float = 65.0
	if offset.length() > radius:
		offset = offset.normalized() * radius
	joystick_value = offset / radius
	joystick_knob.position = (joystick_base.size * 0.5) - (joystick_knob.size * 0.5) + offset
	joystick_knob.visible = true


func reset_joystick() -> void:
	joystick_active = false
	joystick_touch_id = -1
	joystick_value = Vector2.ZERO
	if joystick_knob != null and joystick_base != null:
		joystick_knob.position = (joystick_base.size * 0.5) - (joystick_knob.size * 0.5)
		if not hud_edit_mode:
			joystick_knob.visible = false


func _input(event: InputEvent) -> void:
	if joystick_active and not hud_edit_mode:
		if event is InputEventScreenDrag and event.index == joystick_touch_id:
			update_joystick_global(event.position)
		elif event is InputEventScreenTouch and event.index == joystick_touch_id and not event.pressed:
			reset_joystick()


func _unhandled_input(event: InputEvent) -> void:
	if hud_edit_mode:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if is_position_over_hud(event.position):
				return
			var screen_width: float = get_viewport().get_visible_rect().size.x
			if event.position.x > screen_width / 2.0:
				camera_touch_id = event.index
		else:
			if event.index == camera_touch_id:
				camera_touch_id = -1
	elif event is InputEventScreenDrag:
		if event.index == camera_touch_id:
			camera_yaw -= event.relative.x * camera_sensitivity
			camera_pitch -= event.relative.y * camera_sensitivity
			camera_pitch = clamp(camera_pitch, camera_min_pitch, camera_max_pitch)
			update_camera()


func is_position_over_hud(screen_position: Vector2) -> bool:
	for control in hud_buttons:
		if control != null and control.visible and control.get_global_rect().has_point(screen_position):
			return true
	if joystick_base != null and joystick_base.get_global_rect().has_point(screen_position):
		return true
	return false


func enter_hud_edit_mode() -> void:
	hud_edit_mode = true
	reset_joystick()
	if joystick_knob != null:
		joystick_knob.visible = true
	mobile_jump_requested = false
	mobile_attack_requested = false
	mobile_skill_requested = false
	mobile_special_requested = false
	
	edit_button.visible = false
	reset_button.visible = true
	done_button.visible = true
	set_size_controls_visible(true)


func exit_hud_edit_mode() -> void:
	hud_edit_mode = false
	if joystick_knob != null and not joystick_active:
		joystick_knob.visible = false
	edit_button.visible = true
	reset_button.visible = false
	done_button.visible = false
	set_size_controls_visible(false)
	selected_resize_control = null
	save_hud_layout()


func _on_hud_control_input(event: InputEvent, control: Control) -> void:
	if not hud_edit_mode:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if is_resizable_action(control):
				selected_resize_control = control
				update_action_round_shape(control)
			dragging_control = control
			dragging_touch_id = event.index
		elif event.index == dragging_touch_id:
			dragging_control = null
			dragging_touch_id = -1
			clamp_control_to_screen(control)
	elif event is InputEventScreenDrag:
		if control == dragging_control and event.index == dragging_touch_id:
			control.position += event.relative


func clamp_control_to_screen(control: Control) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	control.position.x = clamp(control.position.x, 0.0, viewport_size.x - control.size.x)
	control.position.y = clamp(control.position.y, 0.0, viewport_size.y - control.size.y)


func save_hud_layout() -> void:
	var config := ConfigFile.new()
	if joystick_base != null:
		config.set_value("hud", "joystick_base", joystick_base.position)
	for button in hud_buttons:
		config.set_value("hud", button.name, button.position)
		if is_resizable_action(button):
			config.set_value("hud", button.name + "_size", button.size)
	config.save(HUD_SAVE_PATH)


func load_hud_layout() -> void:
	var config := ConfigFile.new()
	if config.load(HUD_SAVE_PATH) != OK:
		return
	if joystick_base != null and config.has_section_key("hud", "joystick_base"):
		joystick_base.position = config.get_value("hud", "joystick_base")
	for button in hud_buttons:
		if config.has_section_key("hud", button.name):
			button.position = config.get_value("hud", button.name)
		if is_resizable_action(button) and config.has_section_key("hud", button.name + "_size"):
			button.size = config.get_value("hud", button.name + "_size")
			update_action_round_shape(button)


func reset_hud_layout() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("kotaro_hud_layout.cfg"):
		dir.remove("kotaro_hud_layout.cfg")
	selected_resize_control = null
	_on_viewport_resized()


func config_has_saved_hud_size(button_name: String) -> bool:
	var config := ConfigFile.new()
	if config.load(HUD_SAVE_PATH) != OK:
		return false
	return config.has_section_key("hud", button_name + "_size")


func _on_viewport_resized() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	if timer_label != null:
		timer_label.position = Vector2(screen_size.x / 2.0 - 60, 15)
	if joystick_base != null: joystick_base.position = Vector2(40, screen_size.y - 200)
	if attack_button != null:
		if not config_has_saved_hud_size("attack_button"):
			attack_button.size = Vector2(85, 85)
		attack_button.position = Vector2(screen_size.x - 120, screen_size.y - 130)
		update_action_round_shape(attack_button)
		update_action_logo_size(attack_button)
	if jump_button != null:
		if not config_has_saved_hud_size("jump_button"):
			jump_button.size = Vector2(70, 70)
		jump_button.position = Vector2(screen_size.x - 210, screen_size.y - 190)
		update_action_round_shape(jump_button)
		update_action_logo_size(jump_button)
	if skill_button != null:
		if not config_has_saved_hud_size("skill_button"):
			skill_button.size = Vector2(75, 75)
		skill_button.position = Vector2(screen_size.x - 130, screen_size.y - 230)
		update_action_round_shape(skill_button)
		update_action_logo_size(skill_button)
	if special_button != null:
		if not config_has_saved_hud_size("special_button"):
			special_button.size = Vector2(70, 70)
		special_button.position = Vector2(screen_size.x - 220, screen_size.y - 105)
		update_action_round_shape(special_button)
		update_action_logo_size(special_button)
	if weapon_slot_button != null: weapon_slot_button.position = Vector2(screen_size.x - 160, 20)
	if flower_particles != null: flower_particles.position = Vector2(screen_size.x / 2.0, -20)


func start_aura_cycle():
	while true:
		if sword_aura != null:
			sword_aura.emitting = false
		await get_tree().create_timer(40.0).timeout
		if sword_aura != null:
			sword_aura.emitting = true
		await get_tree().create_timer(10.0).timeout
