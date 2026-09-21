extends Area3D

# ============================================================
# COIN SCRIPT (Pure CylinderMesh Version) - Godot 4
# ============================================================

@export_category("Coin Settings")
@export var coin_value: int = 1
@export var rotation_speed: float = 3.0
@export var hover_offset: float = 0.6  # মাটির ওপর ভেসে থাকার সঠিক উচ্চতা

# সিলিন্ডার মেশ দিয়ে ছোট, পাতলা ও নিখুঁত গোল কয়েনের সাইজ
var coin_radius: float = 0.35      # সুন্দর ছোট গোল ব্যাসার্ধ
var coin_thickness: float = 0.03   # পাতলা কয়েনের পুরুত্ব (Thickness)

var collision_radius: float = 0.25
var collision_height: float = 0.08

var base_y: float = 0.0
var time_passed: float = 0.0


func _ready() -> void:
	# স্কেল ডিফল্ট (1, 1, 1) রাখা হলো
	scale = Vector3.ONE

	add_to_group("pickup")
	set_meta("pickup_type", "coin")
	set_meta("pickup_value", float(coin_value))

	base_y = global_position.y + hover_offset
	global_position.y = base_y

	setup_mesh_via_code()
	setup_collision_via_code()

	body_entered.connect(_on_body_entered)


func setup_mesh_via_code() -> void:
	var mesh_instance: MeshInstance3D
	if has_node("MeshInstance3D"):
		mesh_instance = get_node("MeshInstance3D") as MeshInstance3D
	else:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)

	mesh_instance.scale = Vector3.ONE

	# বিশুদ্ধ CylinderMesh তৈরি
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = coin_radius
	cylinder.bottom_radius = coin_radius
	cylinder.height = coin_thickness
	mesh_instance.mesh = cylinder

	# কয়েনকে খাড়া দাঁড়িয়ে রাখার জন্য X-অক্ষে ৯০ ডিগ্রি ঘোরানো হলো
	mesh_instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	# উজ্জ্বল গোল্ডেন মেটেরিয়াল
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.84, 0.0)
	gold_mat.metallic = 0.9
	gold_mat.roughness = 0.2
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(0.9, 0.7, 0.1)
	gold_mat.emission_energy_multiplier = 0.4
	mesh_instance.material_override = gold_mat


func setup_collision_via_code() -> void:
	var col_shape: CollisionShape3D
	if has_node("CollisionShape3D"):
		col_shape = get_node("CollisionShape3D") as CollisionShape3D
	else:
		col_shape = CollisionShape3D.new()
		col_shape.name = "CollisionShape3D"
		add_child(col_shape)

	col_shape.scale = Vector3.ONE

	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = collision_radius
	cylinder_shape.height = collision_height
	col_shape.shape = cylinder_shape
	col_shape.rotation_degrees = Vector3(90.0, 0.0, 0.0)


func _process(delta: float) -> void:
	rotate_y(rotation_speed * delta)
	time_passed += delta * 4.0
	global_position.y = base_y + sin(time_passed) * 0.08


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		# প্লেয়ারের পয়েন্ট যোগ ও সাউন্ড প্লে হওয়ার ফাংশন
		if body.has_method("collect_pickup"):
			body.collect_pickup(self)
		queue_free()
