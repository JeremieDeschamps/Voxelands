class_name Player
extends CharacterBody3D

## Contrôleur de joueur voxel : 4 classes (Guerrier, Mage, Rôdeur, Voleur), 4 compétences, arbre de talents, inventaire et sauvegarde.

const VoxelCharacter = preload("res://scripts/player/voxel_character.gd")
const Chunk = preload("res://scripts/world/chunk.gd")
const PlayerHUD = preload("res://scripts/ui/player_hud.gd")
const DeathParticles = preload("res://scripts/enemies/death_particles.gd")
const DamageLabel3D = preload("res://scripts/ui/damage_label_3d.gd")
const InventoryManager = preload("res://scripts/items/inventory_manager.gd")
const InventoryUI = preload("res://scripts/ui/inventory_ui.gd")
const SaveSystem = preload("res://scripts/player/save_system.gd")
const PlayerClassData = preload("res://scripts/player/player_class_data.gd")
const TalentTree = preload("res://scripts/player/talent_tree.gd")
const ClassSelectUI = preload("res://scripts/ui/class_select_ui.gd")
const QuestSystem = preload("res://scripts/player/quest_system.gd")
const DialogUI = preload("res://scripts/ui/dialog_ui.gd")
const WorldMapUI = preload("res://scripts/ui/world_map_ui.gd")
const PetCompanion = preload("res://scripts/player/pet_companion.gd")
const CompanionData = preload("res://scripts/player/companion_data.gd")
const SoundGenerator = preload("res://scripts/audio/sound_generator.gd")
const PauseMenuUI = preload("res://scripts/ui/pause_menu_ui.gd")
const MainMenuUI = preload("res://scripts/ui/main_menu_ui.gd")

# Caractéristiques physiques
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var swim_speed: float = 4.5
@export var jump_velocity: float = 8.0
@export var glide_fall_speed: float = -2.2
@export var mouse_sensitivity: float = 0.003

# Statistiques RPG de base
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 18.0
@export var sprint_stamina_cost: float = 16.0

# Classe & Compétences
var player_class: int = PlayerClassData.ClassType.WARRIOR
var skill_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var skill_max_cooldowns: Array[float] = [0.35, 3.0, 5.0, 10.0]

# Progression XP & Arbre de Talents
var level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 100
var talent_tree: TalentTree = null

@export var min_zoom: float = 1.8
@export var max_zoom: float = 9.0
@export var zoom_step: float = 0.6

var current_health: float = 100.0
var current_stamina: float = 100.0

# Références aux sous-noeuds
var character_model: VoxelCharacter = null
var camera_pivot: Node3D = null
var spring_arm: SpringArm3D = null
var camera: Camera3D = null
var hud: PlayerHUD = null
var inventory: InventoryManager = null
var inventory_ui: InventoryUI = null
var class_select_ui: ClassSelectUI = null
var quest_system: QuestSystem = null
var dialog_ui: DialogUI = null
var world_map_ui: WorldMapUI = null
var active_companion: PetCompanion = null
var sound_generator: SoundGenerator = null
var pause_menu_ui: PauseMenuUI = null
var main_menu_ui: MainMenuUI = null
var footstep_timer: float = 0.0

# États du joueur
var is_gliding: bool = false
var is_swimming: bool = false
var is_mouse_captured: bool = false

# Invincibilité temporaire (i-frames)
var invincibility_timer: float = 0.0
var invincibility_duration: float = 0.55

# Orientation de la caméra
var cam_yaw: float = 0.0
var cam_pitch: float = -0.2

var gravity: float = 19.6


func _ready() -> void:
	add_to_group("player")
	talent_tree = TalentTree.new()

	_setup_inputs_if_missing()
	_build_player_components()

	current_health = get_effective_max_health()
	current_stamina = get_effective_max_stamina()

	# Afficher le menu principal au démarrage
	if main_menu_ui != null:
		main_menu_ui.open_main_menu()


func _on_start_game_from_menu(is_new_game: bool) -> void:
	if is_new_game:
		if FileAccess.file_exists("user://save.json"):
			DirAccess.remove_absolute("user://save.json")
		class_select_ui.open_selection()
	else:
		var saved_data: Dictionary = SaveSystem.load_game(self)
		if saved_data.is_empty():
			class_select_ui.open_selection()
		else:
			_apply_class_visuals()

	current_health = get_effective_max_health()
	current_stamina = get_effective_max_stamina()
	_capture_mouse()


func _setup_inputs_if_missing() -> void:
	_register_key_action("move_forward", [KEY_W, KEY_Z, KEY_UP])
	_register_key_action("move_back", [KEY_S, KEY_DOWN])
	_register_key_action("move_left", [KEY_A, KEY_Q, KEY_LEFT])
	_register_key_action("move_right", [KEY_D, KEY_RIGHT])
	_register_key_action("jump", [KEY_SPACE])
	_register_key_action("sprint", [KEY_SHIFT])
	_register_key_action("skill_2", [KEY_E])
	_register_key_action("skill_3", [KEY_R])
	_register_key_action("interact", [KEY_F])
	_register_key_action("open_map", [KEY_M])
	_register_key_action("pet_command", [KEY_G])


func _register_key_action(action: String, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		for code in keycodes:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)


func _build_player_components() -> void:
	# 1. Capsule de collision
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	col_shape.shape = capsule
	col_shape.position = Vector3(0.0, 0.88, 0.0)
	add_child(col_shape)

	# 2. Modèle voxel
	character_model = VoxelCharacter.new()
	character_model.name = "CharacterModel"
	add_child(character_model)

	# 3. Pivot et caméra orbitale
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0.0, 1.4, 0.0)
	add_child(camera_pivot)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = 5.0
	spring_arm.margin = 0.25
	camera_pivot.add_child(spring_arm)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	spring_arm.add_child(camera)

	# 4. HUD
	hud = PlayerHUD.new()
	hud.name = "PlayerHUD"
	add_child(hud)
	hud.setup_skill_bar(player_class)

	# 5. Inventaire & Interface
	inventory = InventoryManager.new()
	inventory.name = "InventoryManager"
	add_child(inventory)

	inventory_ui = InventoryUI.new()
	inventory_ui.name = "InventoryUI"
	add_child(inventory_ui)
	inventory_ui.setup(self, inventory)

	# 6. Écran de sélection de classe
	class_select_ui = ClassSelectUI.new()
	class_select_ui.name = "ClassSelectUI"
	add_child(class_select_ui)
	class_select_ui.class_selected.connect(set_player_class)

	# 7. Système de Quêtes
	quest_system = QuestSystem.new()
	quest_system.quest_added.connect(func(_q): if hud != null: hud.update_quest_tracker(quest_system.active_quests))
	quest_system.quest_updated.connect(func(_q): if hud != null: hud.update_quest_tracker(quest_system.active_quests))
	quest_system.quest_completed.connect(func(_q): if hud != null: hud.update_quest_tracker(quest_system.active_quests))
	quest_system.quest_claimed.connect(func(_q): if hud != null: hud.update_quest_tracker(quest_system.active_quests))

	# 8. Interface de Dialogue PNJ
	dialog_ui = DialogUI.new()
	dialog_ui.name = "DialogUI"
	add_child(dialog_ui)

	# 9. Carte du Monde
	world_map_ui = WorldMapUI.new()
	world_map_ui.name = "WorldMapUI"
	add_child(world_map_ui)
	var world_node = get_node_or_null("../World")
	world_map_ui.setup(self, world_node)

	# 10. Synthétiseur Audio Procédural
	sound_generator = SoundGenerator.new()
	sound_generator.name = "SoundGenerator"
	add_child(sound_generator)

	# 11. Menu Pause & Réglages
	pause_menu_ui = PauseMenuUI.new()
	pause_menu_ui.name = "PauseMenuUI"
	add_child(pause_menu_ui)
	pause_menu_ui.setup(self, world_node, sound_generator)
	pause_menu_ui.return_to_main_menu.connect(func(): if main_menu_ui != null: main_menu_ui.open_main_menu())

	# 12. Menu Principal
	main_menu_ui = MainMenuUI.new()
	main_menu_ui.name = "MainMenuUI"
	add_child(main_menu_ui)
	main_menu_ui.setup(pause_menu_ui)
	main_menu_ui.start_game_requested.connect(_on_start_game_from_menu)


func set_player_class(c_type: int, save: bool = true) -> void:
	player_class = c_type
	var skills: Array[Dictionary] = PlayerClassData.get_skills_for_class(player_class)
	for i in range(4):
		if i < skills.size():
			skill_max_cooldowns[i] = skills[i]["cooldown"]
			skill_cooldowns[i] = 0.0

	_apply_class_visuals()

	if hud != null:
		hud.setup_skill_bar(player_class)

	if save:
		_save_current_game()


func _apply_class_visuals() -> void:
	if character_model != null and character_model.has_method("set_tunic_color"):
		character_model.set_tunic_color(PlayerClassData.CLASS_TUNIC_COLORS[player_class])


func get_class_name_str() -> String:
	return PlayerClassData.CLASS_NAMES[player_class]


func _unhandled_input(event: InputEvent) -> void:
	if main_menu_ui != null and main_menu_ui.is_open:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if inventory_ui != null and inventory_ui.is_open:
				inventory_ui.close_inventory()
			elif world_map_ui != null and world_map_ui.is_open:
				world_map_ui.close_map()
			elif dialog_ui != null and dialog_ui.is_open:
				dialog_ui.close_dialog()
			elif class_select_ui != null and class_select_ui.is_open:
				pass
			elif pause_menu_ui != null:
				pause_menu_ui.toggle_pause()
			else:
				_release_mouse()
			return

	if (inventory_ui != null and inventory_ui.is_open) or (class_select_ui != null and class_select_ui.is_open) or (dialog_ui != null and dialog_ui.is_open) or (world_map_ui != null and world_map_ui.is_open) or (pause_menu_ui != null and pause_menu_ui.is_open):
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not is_mouse_captured:
				_capture_mouse()
			elif event.pressed:
				_use_skill(0) # Attaque de base

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and is_mouse_captured:
			_use_skill(1) # Compétence 1

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if spring_arm != null:
				spring_arm.spring_length = clampf(spring_arm.spring_length - zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if spring_arm != null:
				spring_arm.spring_length = clampf(spring_arm.spring_length + zoom_step, min_zoom, max_zoom)

	elif event is InputEventKey and event.pressed and not event.echo:
		if is_mouse_captured:
			if event.is_action_pressed("skill_2"):
				_use_skill(2) # Compétence 2 (E)
			elif event.is_action_pressed("skill_3"):
				_use_skill(3) # Compétence 3 (R)
			elif event.is_action_pressed("interact"):
				_interact_with_target() # Interaction (F)
			elif event.is_action_pressed("open_map"):
				if world_map_ui != null:
					world_map_ui.toggle_map() # Carte (M)
			elif event.is_action_pressed("pet_command"):
				if active_companion != null and is_instance_valid(active_companion):
					active_companion.toggle_command() # Ordre (G)

	elif event is InputEventMouseMotion and is_mouse_captured:
		cam_yaw -= event.relative.x * mouse_sensitivity
		cam_pitch = clampf(cam_pitch - (event.relative.y * mouse_sensitivity), -deg_to_rad(75.0), deg_to_rad(65.0))
		_update_camera_rotation()


func _update_camera_rotation() -> void:
	if camera_pivot != null and spring_arm != null:
		camera_pivot.rotation.y = cam_yaw
		spring_arm.rotation.x = cam_pitch


## Exécute l'une des 4 compétences de la classe
func _use_skill(idx: int) -> void:
	if idx < 0 or idx >= 4:
		return

	if skill_cooldowns[idx] > 0.0:
		return

	var skills: Array[Dictionary] = PlayerClassData.get_skills_for_class(player_class)
	if idx >= skills.size():
		return

	var s_info: Dictionary = skills[idx]
	var sta_cost: float = s_info["stamina"]

	if current_stamina < sta_cost:
		return

	current_stamina -= sta_cost

	# Calcul du temps de recharge atténué par les talents
	var cd_mult: float = talent_tree.get_cooldown_multiplier() if talent_tree != null else 1.0
	skill_cooldowns[idx] = s_info["cooldown"] * cd_mult
	skill_max_cooldowns[idx] = s_info["cooldown"] * cd_mult

	# Animation du bras droit
	if character_model != null and character_model.right_arm_pivot != null:
		character_model.right_arm_pivot.rotation.x = -deg_to_rad(90.0)

	if sound_generator != null:
		var is_magic: bool = (player_class == PlayerClassData.ClassType.MAGE)
		sound_generator.play_attack(is_magic)

	# Calcul des dégâts et du critique
	var bonus_atk: float = inventory.get_total_attack_bonus() if inventory != null else 0.0
	var talent_dmg_mult: float = talent_tree.get_damage_multiplier() if talent_tree != null else 1.0
	var is_crit: bool = (randf() < (talent_tree.get_crit_chance() if talent_tree != null else 0.0))
	var crit_mult: float = 1.8 if is_crit else 1.0

	var base_dmg: float = s_info["damage"] + bonus_atk
	var final_damage: float = base_dmg * talent_dmg_mult * crit_mult

	var s_range: float = s_info["range"]
	var cam_forward := -Vector3(sin(cam_yaw), 0, cos(cam_yaw)).normalized()

	# Effets spécifiques par classe et compétence
	_execute_skill_effects(idx, final_damage, s_range, cam_forward, is_crit)


func _execute_skill_effects(idx: int, dmg: float, reach: float, forward_dir: Vector3, is_crit: bool) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")

	match player_class:
		PlayerClassData.ClassType.WARRIOR:
			if idx == 0: # Coup d'épée
				_hit_enemies_in_cone(enemies, dmg, reach, forward_dir, 0.2, is_crit)
			elif idx == 1: # Tourbillon 360
				DeathParticles.spawn(get_parent(), global_position + Vector3(0.0, 0.5, 0.0), Color(0.9, 0.3, 0.2))
				_hit_enemies_in_radius(enemies, dmg, reach, is_crit)
			elif idx == 2: # Charge
				velocity += forward_dir * 14.0
				_hit_enemies_in_cone(enemies, dmg, reach, forward_dir, 0.4, is_crit)
			elif idx == 3: # Cri de guerre
				current_health = minf(current_health + 25.0, get_effective_max_health())
				DeathParticles.spawn(get_parent(), global_position + Vector3(0.0, 1.2, 0.0), Color(1.0, 0.85, 0.2))
				_hit_enemies_in_radius(enemies, dmg, reach, is_crit)

		PlayerClassData.ClassType.MAGE:
			if idx == 0: # Éclair arcanique
				DeathParticles.spawn(get_parent(), global_position + forward_dir * 2.0, Color(0.3, 0.6, 1.0))
				_hit_enemies_in_cone(enemies, dmg, reach, forward_dir, 0.7, is_crit)
			elif idx == 1: # Boule de feu
				DeathParticles.spawn(get_parent(), global_position + forward_dir * 4.0, Color(1.0, 0.4, 0.1))
				_hit_enemies_in_cone(enemies, dmg, reach, forward_dir, 0.4, is_crit)
			elif idx == 2: # Nova de givre
				DeathParticles.spawn(get_parent(), global_position + Vector3(0.0, 0.2, 0.0), Color(0.6, 0.9, 1.0))
				_hit_enemies_in_radius(enemies, dmg, reach, is_crit)
			elif idx == 3: # Tempête d'étoiles
				DeathParticles.spawn(get_parent(), global_position + Vector3(0.0, 2.0, 0.0), Color(0.7, 0.3, 1.0))
				_hit_enemies_in_radius(enemies, dmg, reach, is_crit)

		PlayerClassData.ClassType.RANGER:
			if idx == 0: # Tir rapide
				_hit_enemies_in_cone(enemies, dmg, reach, forward_dir, 0.75, is_crit)
			elif idx == 1: # Flèche perforante
				DeathParticles.spawn(get_parent(), global_position + forward_dir * 3.0, Color(0.3, 1.0, 0.5))
				_hit_enemies_in_cone(enemies, dmg, reach, forward_dir, 0.6, is_crit)
			elif idx == 2: # Pluie de flèches
				DeathParticles.spawn(get_parent(), global_position + forward_dir * 5.0, Color(0.8, 1.0, 0.3))
				_hit_enemies_in_cone(enemies, dmg, reach, forward_dir, 0.3, is_crit)
			elif idx == 3: # Bond évasif
				velocity -= forward_dir * 12.0
				velocity.y = 6.0
				_hit_enemies_in_radius(enemies, dmg, reach, is_crit)

		PlayerClassData.ClassType.ROGUE:
			if idx == 0: # Coup de dague
				_hit_enemies_in_cone(enemies, dmg, reach, forward_dir, 0.3, is_crit)
			elif idx == 1: # Frappe dans l'ombre (téléportation derrière l'ennemi)
				var closest_enemy: Node3D = _get_closest_enemy(enemies, reach * 2.0)
				if closest_enemy != null:
					global_position = closest_enemy.global_position - closest_enemy.global_transform.basis.z * 1.5
					DeathParticles.spawn(get_parent(), global_position, Color(0.3, 0.1, 0.4))
				_hit_enemies_in_cone(enemies, dmg, reach, forward_dir, 0.2, is_crit)
			elif idx == 2: # Lames empoisonnées
				DeathParticles.spawn(get_parent(), global_position, Color(0.4, 0.9, 0.2))
				_hit_enemies_in_radius(enemies, dmg, reach, is_crit)
			elif idx == 3: # Exécution
				DeathParticles.spawn(get_parent(), global_position + forward_dir * 1.5, Color(0.9, 0.1, 0.1))
				_hit_enemies_in_cone(enemies, dmg, reach, forward_dir, 0.4, is_crit)


func _hit_enemies_in_cone(enemies: Array, dmg: float, reach: float, forward_dir: Vector3, min_dot: float, is_crit: bool) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			var to_enemy: Vector3 = enemy.global_position - global_position
			if to_enemy.length() <= reach:
				var dir := to_enemy.normalized()
				if forward_dir.dot(dir) >= min_dot:
					if enemy.has_method("take_damage"):
						enemy.take_damage(dmg, global_position)
						if is_crit:
							DamageLabel3D.spawn(get_parent(), enemy.global_position + Vector3(0.0, 1.4, 0.0), int(dmg), true)


func _hit_enemies_in_radius(enemies: Array, dmg: float, reach: float, is_crit: bool) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			if global_position.distance_to(enemy.global_position) <= reach:
				if enemy.has_method("take_damage"):
					enemy.take_damage(dmg, global_position)
					if is_crit:
						DamageLabel3D.spawn(get_parent(), enemy.global_position + Vector3(0.0, 1.4, 0.0), int(dmg), true)


func _get_closest_enemy(enemies: Array, max_dist: float) -> Node3D:
	var closest: Node3D = null
	var min_d: float = max_dist
	for enemy in enemies:
		if is_instance_valid(enemy):
			var d: float = global_position.distance_to(enemy.global_position)
			if d < min_d:
				min_d = d
				closest = enemy
	return closest


func _physics_process(delta: float) -> void:
	# Réduction des cooldowns
	for i in range(4):
		skill_cooldowns[i] = maxf(skill_cooldowns[i] - delta, 0.0)

	if invincibility_timer > 0.0:
		invincibility_timer = maxf(invincibility_timer - delta, 0.0)
		if character_model != null:
			character_model.visible = (int(invincibility_timer * 20.0) % 2 == 0)
	else:
		if character_model != null:
			character_model.visible = true

	var water_surface_y: float = float(Chunk.SEA_LEVEL) + 0.5
	is_swimming = (global_position.y <= water_surface_y)

	if is_swimming or is_on_floor():
		is_gliding = false

	if not is_on_floor() and not is_swimming:
		if Input.is_action_just_pressed("jump"):
			is_gliding = not is_gliding

	if is_swimming:
		if Input.is_action_pressed("jump"):
			velocity.y = swim_speed
		elif Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C):
			velocity.y = -swim_speed
		else:
			velocity.y = lerp(velocity.y, 1.0, delta * 3.0)

	elif is_gliding:
		velocity.y = lerp(velocity.y, glide_fall_speed, delta * 8.0)

	elif not is_on_floor():
		velocity.y -= gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		if sound_generator != null:
			sound_generator.play_jump()

	var input_dir := Vector2.ZERO
	if (inventory_ui == null or not inventory_ui.is_open) and (class_select_ui == null or not class_select_ui.is_open):
		if Input.is_action_pressed("move_forward"):
			input_dir.y -= 1.0
		if Input.is_action_pressed("move_back"):
			input_dir.y += 1.0
		if Input.is_action_pressed("move_left"):
			input_dir.x -= 1.0
		if Input.is_action_pressed("move_right"):
			input_dir.x += 1.0
		input_dir = input_dir.normalized()

	var is_sprinting: bool = Input.is_action_pressed("sprint") and is_on_floor() and input_dir != Vector2.ZERO and current_stamina > 2.0

	var max_sta: float = get_effective_max_stamina()
	var regen_mult: float = talent_tree.get_stamina_regen_multiplier() if talent_tree != null else 1.0

	if is_sprinting:
		current_stamina = maxf(current_stamina - (sprint_stamina_cost * delta), 0.0)
	else:
		current_stamina = minf(current_stamina + (stamina_regen * regen_mult * delta), max_sta)

	var target_speed: float = walk_speed
	if is_swimming:
		target_speed = swim_speed
	elif is_gliding:
		target_speed = sprint_speed * 1.15
	elif is_sprinting:
		target_speed = sprint_speed

	var cam_forward := -Vector3(sin(cam_yaw), 0, cos(cam_yaw)).normalized()
	var cam_right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw)).normalized()
	var move_direction := (cam_forward * -input_dir.y) + (cam_right * input_dir.x)

	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * target_speed
		velocity.z = move_direction.z * target_speed

		var target_angle: float = atan2(-move_direction.x, -move_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_angle, delta * 12.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, target_speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, target_speed * delta * 8.0)

	move_and_slide()

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if character_model != null:
		character_model.update_animation(horizontal_speed, delta, is_on_floor(), is_gliding, is_swimming)

	# Bruit de pas procédural
	if is_on_floor() and horizontal_speed > 0.8:
		footstep_timer += delta * (horizontal_speed / 4.0)
		if footstep_timer >= 0.45:
			footstep_timer = 0.0
			if sound_generator != null:
				sound_generator.play_footstep()
	else:
		footstep_timer = 0.0

	if hud != null:
		hud.update_health(current_health, get_effective_max_health())
		hud.update_stamina(current_stamina, get_effective_max_stamina())
		hud.update_skill_cooldowns(skill_cooldowns, skill_max_cooldowns)
		_update_hud_navigation()


func add_xp(amount: int) -> void:
	current_xp += amount

	var label: Label3D = DamageLabel3D.spawn(get_parent(), global_position + Vector3(0.0, 1.2, 0.0), 0)
	label.text = "+%d XP" % amount
	label.modulate = Color(0.4, 0.8, 1.0)

	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(float(xp_to_next_level) * 1.45)
		max_health += 12.0
		max_stamina += 6.0
		current_health = get_effective_max_health()
		current_stamina = get_effective_max_stamina()

		# Attribution du point de talent
		if talent_tree != null:
			talent_tree.on_level_up(level)

		if sound_generator != null:
			sound_generator.play_level_up()

		var lvl_label: Label3D = DamageLabel3D.spawn(get_parent(), global_position + Vector3(0.0, 1.9, 0.0), 0, true)
		lvl_label.text = "★ NIVEAU %d ATTEINT ! (+1 Talent) ★" % level
		lvl_label.modulate = Color(1.0, 0.85, 0.2)
		DeathParticles.spawn(get_parent(), global_position + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.85, 0.2))

		_save_current_game()


func take_damage(amount: float, from_position: Vector3 = Vector3.ZERO) -> void:
	if invincibility_timer > 0.0 or current_health <= 0.0:
		return

	var def_bonus: float = inventory.get_total_defense_bonus() if inventory != null else 0.0
	var final_amount: float = maxf(amount * (100.0 / (100.0 + def_bonus)), 2.0)

	current_health = maxf(current_health - final_amount, 0.0)
	invincibility_timer = invincibility_duration

	if sound_generator != null:
		sound_generator.play_hit()

	if hud != null:
		hud.trigger_damage_flash()

	if from_position != Vector3.ZERO:
		var knock_dir := (global_position - from_position).normalized()
		knock_dir.y = 0.15
		velocity += knock_dir * 6.0

	if current_health <= 0.0:
		_respawn_player()


func get_effective_max_health() -> float:
	var bonus: float = inventory.get_total_health_bonus() if inventory != null else 0.0
	var talent_hp: float = talent_tree.get_bonus_health() if talent_tree != null else 0.0
	return max_health + bonus + talent_hp


func get_effective_max_stamina() -> float:
	var bonus: float = inventory.get_total_stamina_bonus() if inventory != null else 0.0
	var talent_sta: float = talent_tree.get_bonus_stamina() if talent_tree != null else 0.0
	return max_stamina + bonus + talent_sta


func _respawn_player() -> void:
	current_health = get_effective_max_health()
	current_stamina = get_effective_max_stamina()
	velocity = Vector3.ZERO
	global_position.y += 20.0
	invincibility_timer = 1.0


func _save_current_game() -> void:
	var world_seed: int = 1337
	var world = get_node_or_null("../World")
	if world != null and ("world_seed" in world):
		world_seed = world.world_seed
	SaveSystem.save_game(self, world_seed)


func _capture_mouse() -> void:
	if (inventory_ui != null and inventory_ui.is_open) or (class_select_ui != null and class_select_ui.is_open):
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_mouse_captured = true


func _release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_mouse_captured = false


func _update_hud_navigation() -> void:
	if hud == null or hud.compass_bar == null:
		return

	var world = get_node_or_null("../World")
	var v_pos: Vector3 = Vector3.ZERO
	var v_name: String = ""
	var d_pos: Vector3 = Vector3.ZERO
	var d_name: String = ""
	var pet_p: Vector3 = Vector3.ZERO

	if world != null:
		if ("village_generator" in world) and world.village_generator != null:
			var v_info: Dictionary = world.village_generator.get_nearest_village(global_position)
			if not v_info.is_empty():
				v_pos = v_info["position"]
				v_name = v_info["name"]

		if ("dungeon_generator" in world) and world.dungeon_generator != null:
			var d_info: Dictionary = world.dungeon_generator.get_nearest_dungeon(global_position)
			if not d_info.is_empty():
				d_pos = d_info["surface_position"]
				d_name = d_info["name"]

	if active_companion != null and is_instance_valid(active_companion):
		pet_p = active_companion.global_position
		hud.update_companion_hud(active_companion)
	else:
		hud.update_companion_hud(null)

	hud.compass_bar.update_data(global_position, cam_yaw, v_pos, v_name, d_pos, d_name, pet_p)


func _interact_with_target() -> void:
	# 1. PNJ de village
	var npcs: Array[Node] = get_tree().get_nodes_in_group("npcs")
	for n in npcs:
		if n is CharacterBody3D and is_instance_valid(n):
			if global_position.distance_to(n.global_position) <= 3.8:
				if n.has_method("interact"):
					n.interact(self)
					return

	# 2. Coffres aux trésors
	var chests: Array[Node] = get_tree().get_nodes_in_group("chests")
	for c in chests:
		if is_instance_valid(c):
			if global_position.distance_to(c.global_position) <= 3.8:
				if c.has_method("open_chest"):
					c.open_chest(self)
					return

	# 3. Animaux sauvages apprivoisables
	var animals: Array[Node] = get_tree().get_nodes_in_group("companions")
	for a in animals:
		if a is PetCompanion and is_instance_valid(a):
			if not a.is_tamed and global_position.distance_to(a.global_position) <= 4.0:
				a.tame(self)
				active_companion = a
				if sound_generator != null:
					sound_generator.play_tame()
				if hud != null:
					hud.update_companion_hud(a)
				var lbl: Label3D = DamageLabel3D.spawn(get_parent(), a.global_position + Vector3(0, 1.2, 0), 0, true)
				var cfg: Dictionary = CompanionData.get_config(a.species_type)
				lbl.text = "🐾 %s Apprivoisé !" % cfg.get("name", "Animal")
				lbl.modulate = Color(0.3, 1.0, 0.4)
				_save_current_game()
				return


func spawn_saved_companion(pet_dict: Dictionary) -> void:
	if pet_dict.is_empty():
		return
	var animal := PetCompanion.new()
	animal.species_type = int(pet_dict.get("species", 0))
	animal.pet_level = int(pet_dict.get("level", 1))
	animal.is_tamed = true
	animal.position = global_position + Vector3(1.5, 0.5, 1.5)
	get_parent().call_deferred("add_child", animal)

	animal.call_deferred("tame", self)
	animal.current_health = float(pet_dict.get("health", animal.max_health))
	active_companion = animal
	if hud != null:
		hud.update_companion_hud(animal)

