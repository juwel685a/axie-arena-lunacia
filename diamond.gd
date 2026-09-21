extends Area3D

# ============================================================
# LOW-POLY PROCEDURAL DIAMOND SCRIPT (With Sound) - Godot 4
# ============================================================

@export_category("Diamond Settings")
@export var diamond_value: int = 1
@export var rotation_speed: float = 3.0
@export var hover_offset: float = 0.5  # মাটির ওপর ভেসে থাকার উচ্চতা

# সাউন্ড এফেক্ট ফাইল (Inspector থেকে আপনার পিকআপ সাউন্ডটি দিয়ে দিতে পারেন)
@export var pickup_sound: AudioStream

# ডায়মন্ডের পরিমাপ/সাইজ
@export var diamond_radius: float = 0.25      # ব্যাসার্ধ
@export var crown_height: float = 0.12        # ওপরের অংশের উচ্চতা
@export var pavilion_depth: float = 0.22      # নিচের খাঁজকাটা অংশের গভীরতা
@export var table_radius: float = 0.14        # ওপরের একদম চ্যাপ্টা অংশের সাইজ
@export var num_sides: int = 8                # ৮ কোণযুক্ত লো-পলি লুক

var base_y: float = 0.0
var time_passed: float = 0.0


func _ready() -> void:
	# Jolt Physics scale error এড়াতে স্কেল সরাসরি Vector3.ONE করা হলো
	scale = Vector3.ONE

	add_to_group("pickup")
	set_meta("pickup_type", "diamond")
	set_meta("pickup_value", float(diamond_value))

	base_y = global_position.y + hover_offset
	global_position.y = base_y

	setup_diamond_mesh()
	setup_collision_shape()

	body_entered.connect(_on_body_entered)


func setup_diamond_mesh() -> void:
	var mesh_instance: MeshInstance3D
	if has_node("MeshInstance3D"):
		mesh_instance = get_node("MeshInstance3D") as MeshInstance3D
	else:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)

	mesh_instance.scale = Vector3.ONE
	mesh_instance.mesh = generate_diamond_array_mesh()

	# ছবিটির মতো সুন্দর উজ্জ্বল সায়ান/নীল ডায়মন্ড মেটেরিয়াল
	var diamond_mat := StandardMaterial3D.new()
	diamond_mat.albedo_color = Color(0.1, 0.7, 1.0, 0.9) # চকচকে সায়ান নীল
	diamond_mat.metallic = 0.85
	diamond_mat.roughness = 0.1
	diamond_mat.emission_enabled = true
	diamond_mat.emission = Color(0.1, 0.75, 1.0)
	diamond_mat.emission_energy_multiplier = 0.5
	
	# লো-পলি ডায়মন্ডের প্রতিটি ফেস স্পষ্ট দেখানোর জন্য ফ্ল্যাট শেডিং
	diamond_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX

	mesh_instance.material_override = diamond_mat


func generate_diamond_array_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top_flat_pts: Array[Vector3] = []
	var girdle_pts: Array[Vector3] = []
	var bottom_tip := Vector3(0, -pavilion_depth, 0)

	for i in range(num_sides):
		var angle := float(i) * TAU / float(num_sides)
		var cos_a := cos(angle)
		var sin_a := sin(angle)

		top_flat_pts.append(Vector3(cos_a * table_radius, crown_height, sin_a * table_radius))
		girdle_pts.append(Vector3(cos_a * diamond_radius, 0.0, sin_a * diamond_radius))

	# ১. ওপরের চ্যাপ্টা ফেস (Table Top)
	for i in range(1, num_sides - 1):
		st.add_vertex(top_flat_pts[0])
		st.add_vertex(top_flat_pts[i])
		st.add_vertex(top_flat_pts[i + 1])

	# ২. ওপরের খাঁজকাটা ফেস (Crown Upper Facets)
	for i in range(num_sides):
		var next_i := (i + 1) % num_sides

		st.add_vertex(top_flat_pts[i])
		st.add_vertex(girdle_pts[i])
		st.add_vertex(top_flat_pts[next_i])

		st.add_vertex(top_flat_pts[next_i])
		st.add_vertex(girdle_pts[i])
		st.add_vertex(girdle_pts[next_i])

	# ৩. নিচের অংশ (Pavilion Bottom Cone)
	for i in range(num_sides):
		var next_i := (i + 1) % num_sides
		st.add_vertex(girdle_pts[i])
		st.add_vertex(bottom_tip)
		st.add_vertex(girdle_pts[next_i])

	st.generate_normals()
	return st.commit()


func setup_collision_shape() -> void:
	var col_shape: CollisionShape3D
	if has_node("CollisionShape3D"):
		col_shape = get_node("CollisionShape3D") as CollisionShape3D
	else:
		col_shape = CollisionShape3D.new()
		col_shape.name = "CollisionShape3D"
		add_child(col_shape)

	col_shape.scale = Vector3.ONE

	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = diamond_radius + 0.1
	col_shape.shape = sphere_shape


func _process(delta: float) -> void:
	if scale != Vector3.ONE:
		scale = Vector3.ONE

	rotate_y(rotation_speed * delta)
	time_passed += delta * 4.0
	global_position.y = base_y + sin(time_passed) * 0.06


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		# ১. প্লেয়ারের পয়েন্ট যোগ
		if body.has_method("collect_pickup"):
			body.collect_pickup(self)

		# ২. অডিও প্লে করার ব্যবস্থা
		play_pickup_sound()

		# ৩. মেস ও কলিশন বন্ধ করে দেওয়া যেন ২বার টাচ না হয়
		visible = false
		$CollisionShape3D.set_deferred("disabled", true)


func play_pickup_sound() -> void:
	if pickup_sound:
		# অস্থায়ী অডিও প্লেয়ার তৈরি যাতে ডায়মন্ড গায়েব হলেও সাউন্ড শেষ পর্যন্ত বাজে
		var audio_player := AudioStreamPlayer.new()
		audio_player.stream = pickup_sound
		get_tree().root.add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)
	
	# সাউন্ড শুরুর পর ডায়মন্ডটি রিমুভ করে দেওয়া
	queue_free()
