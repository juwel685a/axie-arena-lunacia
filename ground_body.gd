extends StaticBody3D

func _ready():
	var shape = BoxShape3D.new()
	shape.size = Vector3(170, 1, 170)
	$CollisionShape3D.shape = shape
	$CollisionShape3D.position = Vector3(0, -0.5, 0)
