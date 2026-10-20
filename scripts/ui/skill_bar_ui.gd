class_name SkillBarUI
extends Control

## Barre d'actions et de compétences en bas de l'écran avec cooldowns et raccourcis.

const PlayerClassData = preload("res://scripts/player/player_class_data.gd")

var skill_panels: Array[Panel] = []
var cd_labels: Array[Label] = []
var name_labels: Array[Label] = []
var key_labels: Array[Label] = []
var cd_overlays: Array[ColorRect] = []

var class_skills: Array[Dictionary] = []


func _ready() -> void:
	_build_ui()


func setup_skills(c_type: int) -> void:
	class_skills = PlayerClassData.get_skills_for_class(c_type)
	for i in range(4):
		if i < class_skills.size():
			var s: Dictionary = class_skills[i]
			name_labels[i].text = s["name"]
			key_labels[i].text = "[%s]" % s["key"]
		cd_labels[i].text = ""
		cd_overlays[i].visible = false


func update_cooldowns(cooldowns: Array[float], max_cooldowns: Array[float]) -> void:
	for i in range(4):
		if i >= cooldowns.size() or i >= class_skills.size():
			continue

		var cd: float = cooldowns[i]
		var max_cd: float = max_cooldowns[i]

		if cd > 0.05:
			cd_labels[i].text = "%.1fs" % cd
			cd_overlays[i].visible = true
			var ratio: float = clampf(cd / maxf(max_cd, 0.1), 0.0, 1.0)
			cd_overlays[i].custom_minimum_size.y = 64.0 * ratio
		else:
			cd_labels[i].text = ""
			cd_overlays[i].visible = false


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	position = Vector2(-155.0, -85.0) # Centré en bas
	custom_minimum_size = Vector2(310.0, 75.0)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	add_child(hbox)

	for i in range(4):
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(66.0, 66.0)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.12, 0.15, 0.9)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.35, 0.4, 0.5)
		panel.add_theme_stylebox_override("panel", sb)

		# Overlay sombre de cooldown
		var overlay := ColorRect.new()
		overlay.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		overlay.color = Color(0.0, 0.0, 0.0, 0.65)
		overlay.visible = false
		panel.add_child(overlay)
		cd_overlays.append(overlay)

		# Nom de compétence
		var n_lbl := Label.new()
		n_lbl.position = Vector2(2.0, 4.0)
		n_lbl.custom_minimum_size = Vector2(62.0, 30.0)
		n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		n_lbl.add_theme_font_size_override("font_size", 10)
		n_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		panel.add_child(n_lbl)
		name_labels.append(n_lbl)

		# Touche de raccourci
		var k_lbl := Label.new()
		k_lbl.position = Vector2(2.0, 46.0)
		k_lbl.custom_minimum_size = Vector2(62.0, 18.0)
		k_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		k_lbl.add_theme_font_size_override("font_size", 11)
		k_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		panel.add_child(k_lbl)
		key_labels.append(k_lbl)

		# Texte du timer de cooldown
		var cd_lbl := Label.new()
		cd_lbl.set_anchors_preset(Control.PRESET_CENTER)
		cd_lbl.position = Vector2(-30.0, -12.0)
		cd_lbl.custom_minimum_size = Vector2(60.0, 24.0)
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 15)
		cd_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		panel.add_child(cd_lbl)
		cd_labels.append(cd_lbl)

		hbox.add_child(panel)
		skill_panels.append(panel)
