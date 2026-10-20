class_name PlayerHUD
extends CanvasLayer

## Interface tête haute (HUD) avec barres de vie, d'endurance, réticule et compteur FPS.

const SkillBarUI = preload("res://scripts/ui/skill_bar_ui.gd")
const CompassUI = preload("res://scripts/ui/compass_ui.gd")
const BossBarUI = preload("res://scripts/ui/boss_bar_ui.gd")

var health_bar: ProgressBar = null
var stamina_bar: ProgressBar = null
var fps_label: Label = null
var hurt_flash: ColorRect = null
var skill_bar: SkillBarUI = null
var compass_bar: CompassUI = null
var boss_bar: BossBarUI = null

# Widget Compagnon
var pet_container: Panel = null
var pet_name_label: Label = null
var pet_hp_bar: ProgressBar = null
var pet_command_label: Label = null

# Traqueur de Quêtes
var quest_container: Panel = null
var quest_list_label: Label = null

var flash_timer: float = 0.0


func _ready() -> void:
	_create_ui_elements()


func _create_ui_elements() -> void:
	# 1. Compteur FPS en haut à gauche
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.position = Vector2(16.0, 16.0)
	fps_label.text = "FPS: 0"
	fps_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	add_child(fps_label)

	# 2. Réticule central
	var crosshair := Control.new()
	crosshair.name = "Crosshair"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	add_child(crosshair)

	var dot := ColorRect.new()
	dot.size = Vector2(4.0, 4.0)
	dot.position = Vector2(-2.0, -2.0)
	dot.color = Color(1.0, 1.0, 1.0, 0.75)
	crosshair.add_child(dot)

	# 3. Conteneur des jauges en bas à gauche
	var stats_container := VBoxContainer.new()
	stats_container.name = "StatsContainer"
	stats_container.position = Vector2(24.0, 620.0)
	stats_container.custom_minimum_size = Vector2(240.0, 60.0)
	stats_container.add_theme_constant_override("separation", 8)
	add_child(stats_container)

	# Barre de vie
	health_bar = _create_styled_bar(Color(0.85, 0.18, 0.18), Color(0.18, 0.12, 0.12), "Santé")
	stats_container.add_child(health_bar)

	# Barre d'endurance
	stamina_bar = _create_styled_bar(Color(0.20, 0.75, 0.35), Color(0.12, 0.18, 0.12), "Endurance")
	stats_container.add_child(stamina_bar)

	# 4. Écran de flash rouge lors d'un coup reçu
	hurt_flash = ColorRect.new()
	hurt_flash.name = "HurtFlash"
	hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_flash.color = Color(0.9, 0.1, 0.1, 0.0)
	add_child(hurt_flash)

	# 5. Barre de compétences au centre en bas
	skill_bar = SkillBarUI.new()
	skill_bar.name = "SkillBarUI"
	add_child(skill_bar)

	# 6. Boussole en haut au centre
	compass_bar = CompassUI.new()
	compass_bar.name = "CompassUI"
	add_child(compass_bar)

	# 7. Jauge de Boss de donjon
	boss_bar = BossBarUI.new()
	boss_bar.name = "BossBarUI"
	add_child(boss_bar)

	# 8. Widget Compagnon au-dessus des jauges du joueur
	pet_container = Panel.new()
	pet_container.name = "PetWidget"
	pet_container.size = Vector2(240.0, 52.0)
	pet_container.position = Vector2(24.0, 560.0)
	var pet_sb := StyleBoxFlat.new()
	pet_sb.bg_color = Color(0.10, 0.14, 0.18, 0.85)
	pet_sb.border_width_left = 2
	pet_sb.border_width_top = 2
	pet_sb.border_width_right = 2
	pet_sb.border_width_bottom = 2
	pet_sb.border_color = Color(0.35, 0.85, 0.95)
	pet_sb.corner_radius_top_left = 4
	pet_sb.corner_radius_top_right = 4
	pet_sb.corner_radius_bottom_left = 4
	pet_sb.corner_radius_bottom_right = 4
	pet_container.add_theme_stylebox_override("panel", pet_sb)
	pet_container.visible = false
	add_child(pet_container)

	pet_name_label = Label.new()
	pet_name_label.position = Vector2(8.0, 4.0)
	pet_name_label.text = "🐾 Compagnon"
	pet_name_label.add_theme_color_override("font_color", Color(0.35, 0.90, 0.95))
	pet_container.add_child(pet_name_label)

	pet_command_label = Label.new()
	pet_command_label.position = Vector2(160.0, 4.0)
	pet_command_label.text = "[G: Ordre]"
	pet_command_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	pet_container.add_child(pet_command_label)

	pet_hp_bar = _create_styled_bar(Color(0.25, 0.85, 0.45), Color(0.12, 0.16, 0.14), "Compagnon")
	pet_hp_bar.custom_minimum_size = Vector2(224.0, 14.0)
	pet_hp_bar.position = Vector2(8.0, 28.0)
	pet_container.add_child(pet_hp_bar)

	# 9. Traqueur de Quêtes en haut à droite
	quest_container = Panel.new()
	quest_container.name = "QuestTracker"
	quest_container.size = Vector2(280.0, 140.0)
	quest_container.position = Vector2(976.0, 20.0)
	var q_sb := StyleBoxFlat.new()
	q_sb.bg_color = Color(0.08, 0.10, 0.14, 0.82)
	q_sb.border_width_left = 2
	q_sb.border_width_top = 2
	q_sb.border_width_right = 2
	q_sb.border_width_bottom = 2
	q_sb.border_color = Color(0.75, 0.65, 0.25)
	q_sb.corner_radius_top_left = 6
	q_sb.corner_radius_top_right = 6
	q_sb.corner_radius_bottom_left = 6
	q_sb.corner_radius_bottom_right = 6
	quest_container.add_theme_stylebox_override("panel", q_sb)
	add_child(quest_container)

	var q_title := Label.new()
	q_title.position = Vector2(10.0, 6.0)
	q_title.text = "📜 OBJECTIFS ACTIFS"
	q_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	quest_container.add_child(q_title)

	quest_list_label = Label.new()
	quest_list_label.position = Vector2(10.0, 32.0)
	quest_list_label.size = Vector2(260.0, 100.0)
	quest_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_list_label.text = "Aucune quête active.\nVisitez un village pour en obtenir !"
	quest_list_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	quest_container.add_child(quest_list_label)

	# Rendre l'intégralité du HUD non cliquable et transparent aux entrées souris
	_set_ignore_mouse_recursive(self)


func _set_ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_set_ignore_mouse_recursive(child)


func update_companion_hud(pet_node: Node) -> void:
	if pet_node == null or not is_instance_valid(pet_node):
		if pet_container != null:
			pet_container.visible = false
		return

	if pet_container != null:
		pet_container.visible = true

	var cur_hp: float = pet_node.current_health if "current_health" in pet_node else 100.0
	var max_hp: float = pet_node.max_health if "max_health" in pet_node else 100.0
	var sp_type: int = pet_node.species_type if "species_type" in pet_node else 0
	var p_lvl: int = pet_node.pet_level if "pet_level" in pet_node else 1

	var c_cfg: Dictionary = pet_node.CompanionData.get_config(sp_type) if ("CompanionData" in pet_node and pet_node.CompanionData != null) else {}
	var pet_n: String = c_cfg.get("name", "Animal")

	if pet_name_label != null:
		pet_name_label.text = "🐾 %s (Niv.%d)" % [pet_n, p_lvl]

	if pet_hp_bar != null:
		pet_hp_bar.max_value = max_hp
		pet_hp_bar.value = cur_hp


func update_quest_tracker(active_quests: Array[Dictionary]) -> void:
	if quest_list_label == null:
		return

	if active_quests.is_empty():
		quest_list_label.text = "Aucune quête active.\nVisitez un village pour en obtenir !"
		return

	var txt: String = ""
	for q in active_quests:
		var status: String = " ✅ Terminée !" if q.get("is_completed", false) else " (%d/%d)" % [q.get("current_count", 0), q.get("required_count", 1)]
		txt += "• %s%s\n" % [q.get("title", "Quête"), status]

	quest_list_label.text = txt


func setup_skill_bar(c_type: int) -> void:
	if skill_bar != null:
		skill_bar.setup_skills(c_type)


func update_skill_cooldowns(cds: Array[float], max_cds: Array[float]) -> void:
	if skill_bar != null:
		skill_bar.update_cooldowns(cds, max_cds)


func _create_styled_bar(fill_color: Color, bg_color: Color, _label_name: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(240.0, 20.0)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0

	# Style Arrière-plan
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = bg_color
	sb_bg.corner_radius_top_left = 4
	sb_bg.corner_radius_top_right = 4
	sb_bg.corner_radius_bottom_left = 4
	sb_bg.corner_radius_bottom_right = 4
	sb_bg.border_width_left = 2
	sb_bg.border_width_top = 2
	sb_bg.border_width_right = 2
	sb_bg.border_width_bottom = 2
	sb_bg.border_color = Color(0.25, 0.25, 0.28)
	bar.add_theme_stylebox_override("background", sb_bg)

	# Style Jauge pleine
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = fill_color
	sb_fill.corner_radius_top_left = 3
	sb_fill.corner_radius_top_right = 3
	sb_fill.corner_radius_bottom_left = 3
	sb_fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", sb_fill)

	return bar


func _process(delta: float) -> void:
	# Compteur FPS
	if fps_label != null:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	# Résorption du flash de dégâts
	if flash_timer > 0.0:
		flash_timer = maxf(flash_timer - delta, 0.0)
		if hurt_flash != null:
			hurt_flash.color.a = clampf(flash_timer * 1.5, 0.0, 0.35)


func update_health(current: float, maximum: float) -> void:
	if health_bar != null:
		health_bar.max_value = maximum
		health_bar.value = current


func update_stamina(current: float, maximum: float) -> void:
	if stamina_bar != null:
		stamina_bar.max_value = maximum
		stamina_bar.value = current


func trigger_damage_flash() -> void:
	flash_timer = 0.3
