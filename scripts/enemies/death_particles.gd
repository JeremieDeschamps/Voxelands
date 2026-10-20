class_name DeathParticles
extends CPUParticles3D

## Particules procédurales d'éclatement de cubes voxel à la mort d'une entité.

var timer: float = 0.0
var max_lifetime: float = 0.8


func _ready() -> void:
	emitting = true
	one_shot = true
	explosiveness = 0.95
	amount = 24
	lifetime = 0.6

	# Direction et dispersion 3D en sphère
	direction = Vector3.UP
	spread = 180.0
	gravity = Vector3(0.0, -18.0, 0.0)
	initial_velocity_min = 3.5
	initial_velocity_max = 7.0
	damping_min = 2.0
	damping_max = 4.0

	# Maillage cubique voxel
	var cube_mesh := BoxMesh.new()
	cube_mesh.size = Vector3(0.14, 0.14, 0.14)
	mesh = cube_mesh


static func spawn(parent: Node, spawn_pos: Vector3, debris_color: Color) -> CPUParticles3D:
	var script: GDScript = load("res://scripts/enemies/death_particles.gd")
	var particles: CPUParticles3D = script.new()
	particles.position = spawn_pos
	particles.color = debris_color

	var mat := StandardMaterial3D.new()
	mat.albedo_color = debris_color
	mat.roughness = 0.85
	particles.material_override = mat

	parent.add_child(particles)
	return particles


func _process(delta: float) -> void:
	timer += delta
	if timer >= max_lifetime:
		queue_free()
