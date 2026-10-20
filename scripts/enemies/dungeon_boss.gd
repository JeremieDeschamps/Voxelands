class_name DungeonBoss
extends CharacterBody3D

## Boss de donjon souterrain : Titan imposant avec attaques de zone, invocations et barre de vie épique.

const DeathParticles = preload("res://scripts/enemies/death_particles.gd")
const DamageLabel3D = preload("res://scripts/ui/damage_label_3d.gd")
const ItemData = preload("res://scripts/items/item_data.gd")
const LootDrop = preload("res://scripts/items/loot_drop.gd")
const SkeletonEnemy = preload("res://scripts/enemies/skeleton.gd")

enum State {
	IDLE,
	CHASE,
	ATTACK_SMASH,
	ATTACK_SHOCKWAVE
}

@export var boss_name: String = "Titan Gorgaroth - Gardien des Cryptes"
@export var boss_level: int = 3

var state: State = State.IDLE
var player_ref: CharacterBody3D = null

# Stats
var max_health: float = 550.0
var current_health: float = 550.0
var attack_damage: float = 34.0
var move_speed: float = 5.2
var attack_range: float = 3.6
var attack_cooldown: float = 1.8
var attack_timer: float = 0.0

var shockwave_cooldown: float = 8.0
var shockwave_timer: float = 4.0
var has_summoned_minions: bool = false

# Visuels
var visuals_node: Node3D = null
var right_arm_pivot: Node3D = null
var hammer_node: Node3D = null
var leg_l: Node3D = null
var leg_r: Node3D = null

var walk_phase: float = 0.0
var gravity: float = 19.6
var is_active: bool = false


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	_init_stats()
	_build_boss_mesh()


func _init_stats() -> void:
	var lvl_mult: float = 1.0 + (float(boss_level - 1) * 0.25)
	max_health = 550.0 * lvl_mult
	current_health = max_health
	attack_damage = 34.0 * lvl_mult


func _create_voxel_cube(size: Vector3, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	box.material = mat
	inst.mesh = box
	return inst


func _build_boss_mesh() -> void:
	visuals_node = Node3D.new()
	visuals_node.name = "Visuals"
	add_child(visuals_node)

	var stone_dark := Color(0.18, 0.20, 0.24)
	var rune_cyan := Color(0.20, 0.85, 0.95)
	var iron_metal := Color(0.45, 0.45, 0.48)

	# 1. Torse titanesque
	var torso := _create_voxel_cube(Vector3(1.6, 2.0, 1.1), stone_dark)
	torso.position = Vector3(0, 2.4, 0)
	visuals_node.add_child(torso)

	# Cœur runique luisant au centre du torse
	var rune_core := _create_voxel_cube(Vector3(0.5, 0.5, 0.15), rune_cyan)
	rune_core.position = Vector3(0, 2.5, -0.58)
	visuals_node.add_child(rune_core)

	# 2. Épaulettes massives
	var shoulder_l := _create_voxel_cube(Vector3(0.7, 0.7, 0.8), iron_metal)
	shoulder_l.position = Vector3(-1.15, 3.2, 0)
	visuals_node.add_child(shoulder_l)

	var shoulder_r := _create_voxel_cube(Vector3(0.7, 0.7, 0.8), iron_metal)
	shoulder_r.position = Vector3(1.15, 3.2, 0)
	visuals_node.add_child(shoulder_r)

	# 3. Tête casquée avec cornes de titan
	var head := _create_voxel_cube(Vector3(0.8, 0.9, 0.8), stone_dark)
	head.position = Vector3(0, 3.75, 0)
	visuals_node.add_child(head)

	var eye_l := _create_voxel_cube(Vector3(0.15, 0.1, 0.08), rune_cyan)
	eye_l.position = Vector3(-0.22, 3.75, -0.42)
	visuals_node.add_child(eye_l)

	var eye_r := _create_voxel_cube(Vector3(0.15, 0.1, 0.08), rune_cyan)
	eye_r.position = Vector3(0.22, 3.75, -0.42)
	visuals_node.add_child(eye_r)

	# Cornes de pierre
	var horn_l := _create_voxel_cube(Vector3(0.2, 0.6, 0.2), iron_metal)
	horn_l.position = Vector3(-0.48, 4.35, 0)
	horn_l.rotation.z = deg_to_rad(-25.0)
	visuals_node.add_child(horn_l)

	var horn_r := _create_voxel_cube(Vector3(0.2, 0.6, 0.2), iron_metal)
	horn_r.position = Vector3(0.48, 4.35, 0)
	horn_r.rotation.z = deg_to_rad(25.0)
	visuals_node.add_child(horn_r)

	# 4. Bras droit avec Masse de guerre titanique
	right_arm_pivot = Node3D.new()
	right_arm_pivot.position = Vector3(1.2, 3.1, 0)
	visuals_node.add_child(right_arm_pivot)

	var arm_r := _create_voxel_cube(Vector3(0.45, 1.5, 0.45), stone_dark)
	arm_r.position = Vector3(0, -0.7, 0)
	right_arm_pivot.add_child(arm_r)

	# Marteau de titan
	hammer_node = Node3D.new()
	hammer_node.position = Vector3(0, -1.3, -0.2)
	right_arm_pivot.add_child(hammer_node)

	var h_shaft := _create_voxel_cube(Vector3(0.15, 2.4, 0.15), Color(0.35, 0.25, 0.15))
	h_shaft.position = Vector3(0, 0.2, 0)
	hammer_node.add_child(h_shaft)

	var h_head := _create_voxel_cube(Vector3(0.9, 0.9, 1.4), iron_metal)
	h_head.position = Vector3(0, 1.2, 0)
	hammer_node.add_child(h_head)

	# 5. Bras gauche
	var arm_l := _create_voxel_cube(Vector3(0.45, 1.5, 0.45), stone_dark)
	arm_l.position = Vector3(-1.2, 2.4, 0)
	visuals_node.add_child(arm_l)

	# 6. Jambes
	leg_l = _create_voxel_cube(Vector3(0.55, 1.4, 0.55), stone_dark)
	leg_l.position = Vector3(-0.45, 0.7, 0)
	visuals_node.add_child(leg_l)

	leg_r = _create_voxel_cube(Vector3(0.55, 1.4, 0.55), stone_dark)
	leg_r.position = Vector3(0.45, 0.7, 0)
	visuals_node.add_child(leg_r)

	# 7. Collision solide
	var col := CollisionShape3D.new()
	var cap := BoxShape3D.new()
	cap.size = Vector3(2.0, 4.4, 1.8)
	col.shape = cap
	col.position = Vector3(0, 2.2, 0)
	add_child(col)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if attack_timer > 0.0:
		attack_timer -= delta
	if shockwave_timer > 0.0:
		shockwave_timer -= delta

	if player_ref == null or not is_instance_valid(player_ref):
		var p_list: Array[Node] = get_tree().get_nodes_in_group("player")
		if not p_list.is_empty():
			player_ref = p_list[0] as CharacterBody3D

	if player_ref != null and is_instance_valid(player_ref):
		var dist: float = global_position.distance_to(player_ref.global_position)
		if dist <= 24.0:
			if not is_active:
				is_active = true
				_notify_hud_boss(true)

			_ai_combat(delta, dist)
		elif is_active and dist > 36.0:
			is_active = false
			_notify_hud_boss(false)
			velocity.x = 0.0
			velocity.z = 0.0

	move_and_slide()
	_animate(delta)


func _ai_combat(delta: float, dist: float) -> void:
	var dir: Vector3 = (player_ref.global_position - global_position).normalized()
	dir.y = 0.0
	var look_t: Vector3 = global_position + dir
	visuals_node.look_at(Vector3(look_t.x, global_position.y, look_t.z), Vector3.UP)

	# Invocation d'alliés à 50% de vie
	if not has_summoned_minions and current_health <= (max_health * 0.5):
		has_summoned_minions = true
		_summon_minions()

	# Compétence Onde de Choc
	if shockwave_timer <= 0.0 and dist <= 8.0:
		shockwave_timer = shockwave_cooldown
		_trigger_shockwave()
		return

	# Poursuite et frappe normale
	if dist > attack_range:
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		if is_on_floor() and is_on_wall():
			velocity.y = 7.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 6.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 6.0)

		if attack_timer <= 0.0:
			attack_timer = attack_cooldown
			_perform_smash()


func _perform_smash() -> void:
	# Animation frappe marteau
	if right_arm_pivot != null:
		right_arm_pivot.rotation.x = deg_to_rad(-70.0)

	var dist: float = global_position.distance_to(player_ref.global_position)
	if dist <= attack_range + 1.2 and player_ref.has_method("take_damage"):
		player_ref.take_damage(attack_damage)


func _trigger_shockwave() -> void:
	# Bond colossal
	velocity.y = 8.0
	if right_arm_pivot != null:
		right_arm_pivot.rotation.x = deg_to_rad(-90.0)

	# Dégâts de zone à l'atterrissage
	get_tree().create_timer(0.6).timeout.connect(func():
		var targets: Array[Node] = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("companions")
		for t in targets:
			if t is CharacterBody3D and is_instance_valid(t):
				var d: float = global_position.distance_to(t.global_position)
				if d <= 9.0 and t.has_method("take_damage"):
					t.take_damage(attack_damage * 1.3)
					DamageLabel3D.spawn(get_parent(), t.global_position + Vector3(0, 1.5, 0), attack_damage * 1.3, true)
	)


func _summon_minions() -> void:
	for i in range(2):
		var skel := SkeletonEnemy.new()
		skel.level = boss_level
		var off := Vector3(randf_range(-3, 3), 0.5, randf_range(-3, 3))
		skel.position = global_position + off
		get_parent().add_child(skel)


func take_damage(dmg: float) -> void:
	current_health = maxf(current_health - dmg, 0.0)
	_update_hud_hp()

	if current_health <= 0.0:
		_die()


func _notify_hud_boss(active: bool) -> void:
	if player_ref != null and "hud" in player_ref and player_ref.hud != null:
		var boss_bar = player_ref.hud.get_node_or_null("BossBarUI")
		if boss_bar != null:
			if active:
				boss_bar.show_boss(boss_name, current_health, max_health)
			else:
				boss_bar.hide_boss()


func _update_hud_hp() -> void:
	if player_ref != null and "hud" in player_ref and player_ref.hud != null:
		var boss_bar = player_ref.hud.get_node_or_null("BossBarUI")
		if boss_bar != null:
			boss_bar.update_hp(current_health, max_health)


func _die() -> void:
	_notify_hud_boss(false)
	DeathParticles.spawn(get_parent(), global_position + Vector3(0, 2.0, 0))

	# Progression quête & XP massif
	if player_ref != null:
		if "quest_system" in player_ref and player_ref.quest_system != null:
			player_ref.quest_system.notify_boss_killed()
		if "add_xp" in player_ref:
			player_ref.add_xp(500)

	# Butin d'exception : 3 à 4 objets Légendaires / Épiques
	for i in range(randi_range(3, 4)):
		var item: RefCounted = ItemData.generate_random_item(boss_level + 1)
		item.rarity = ItemData.Rarity.LEGENDARY
		item.attack_bonus = int(round(item.attack_bonus * 1.8))
		item.defense_bonus = int(round(item.defense_bonus * 1.8))
		item.health_bonus = int(round(item.health_bonus * 1.8))

		var drop_pos: Vector3 = global_position + Vector3(randf_range(-1.5, 1.5), 1.0, randf_range(-1.5, 1.5))
		LootDrop.spawn(get_parent(), drop_pos, item)

	queue_free()


func _animate(delta: float) -> void:
	var h_vel := Vector2(velocity.x, velocity.z).length()
	if h_vel > 0.2:
		walk_phase += h_vel * delta * 2.0
		var swing: float = sin(walk_phase) * 0.4
		if leg_l != null:
			leg_l.rotation.x = swing
		if leg_r != null:
			leg_r.rotation.x = -swing
	else:
		if leg_l != null:
			leg_l.rotation.x = lerp_angle(leg_l.rotation.x, 0.0, delta * 6.0)
		if leg_r != null:
			leg_r.rotation.x = lerp_angle(leg_r.rotation.x, 0.0, delta * 6.0)

	if right_arm_pivot != null and right_arm_pivot.rotation.x != 0.0:
		right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, 0.0, delta * 4.0)
