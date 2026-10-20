class_name PlayerHUD
extends CanvasLayer

## Interface tête haute (HUD) avec barres de vie, d'endurance, réticule et compteur FPS.

const SkillBarUI = preload("res://scripts/ui/skill_bar_ui.gd")

var health_bar: ProgressBar = null
var stamina_bar: ProgressBar = null
var fps_label: Label = null
var hurt_flash: ColorRect = null
var skill_bar: SkillBarUI = null
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
