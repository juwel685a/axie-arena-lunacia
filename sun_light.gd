extends Node3D
func _ready():
	# =========================
	# ☀️ SUN / DAY LIGHT
	# =========================
	var sun = self
	
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	
	sun.directional_shadow_max_distance = 50.0
	
	# =========================
	# 🌤️ DAY SKY
	# =========================
	var world = WorldEnvironment.new()
	world.name = "WorldEnvironment"
	add_child(world)
	
	var environment = Environment.new()
	
	# Background
	environment.background_mode = Environment.BG_SKY
	
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	
	sky_material.sky_top_color = Color(0.25, 0.55, 0.95)
	
	sky_material.sky_horizon_color = Color(0.75, 0.90, 1.0)
	
	sky_material.ground_bottom_color = Color(0.35, 0.50, 0.30)
	   
	sky_material.ground_horizon_color = Color(0.70, 0.80, 0.65)
	
	sky.sky_material = sky_material
	environment.sky = sky
	
	# =========================
	# 💡 AMBIENT / NATURAL LIGHT
	# =========================
	   
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	
	# =========================
	# 🌍 TONEMAPPING
	# =========================
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = environment
