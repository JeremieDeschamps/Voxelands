class_name BossBarUI
extends Control

## Jauge de vie majestueuse affichée en haut de l'écran lors d'un combat contre un Boss de donjon.

var container: VBoxContainer = null
var boss_title_label: Label = null
var boss_progress_bar: ProgressBar = null
var hp_detail_label: Label = null


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	container = VBoxContainer.new()
	container.name = "BossContainer"
	container.custom_minimum_size = Vector2(540.0, 50.0)
	container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	container.position = Vector2((1280.0 - 540.0) * 0.5, 24.0)
	container.add_theme_constant_override("separation", 4)
	add_child(container)

	# Titre du Boss
	boss_title_label = Label.new()
	boss_title_label.text = "👑 TITAN GORGAROTH - GARDIEN DES CRYPTES"
	boss_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_title_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	container.add_child(boss_title_label)

	# Jauge
	boss_progress_bar = ProgressBar.new()
	boss_progress_bar.custom_minimum_size = Vector2(540.0, 22.0)
	boss_progress_bar.show_percentage = false
	boss_progress_bar.max_value = 500.0
	boss_progress_bar.value = 500.0

	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.12, 0.08, 0.08, 0.9)
	bg_sb.border_width_left = 2
	bg_sb.border_width_top = 2
	bg_sb.border_width_right = 2
	bg_sb.border_width_bottom = 2
	bg_sb.border_color = Color(0.65, 0.20, 0.20)
	bg_sb.corner_radius_top_left = 4
	bg_sb.corner_radius_top_right = 4
	bg_sb.corner_radius_bottom_left = 4
	bg_sb.corner_radius_bottom_right = 4
	boss_progress_bar.add_theme_stylebox_override("background", bg_sb)

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.92, 0.18, 0.18)
	fill_sb.corner_radius_top_left = 3
	fill_sb.corner_radius_top_right = 3
	fill_sb.corner_radius_bottom_left = 3
	fill_sb.corner_radius_bottom_right = 3
	boss_progress_bar.add_theme_stylebox_override("fill", fill_sb)

	container.add_child(boss_progress_bar)

	# Détails PV
	hp_detail_label = Label.new()
	hp_detail_label.text = "500 / 500 (100%)"
	hp_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_detail_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	container.add_child(hp_detail_label)

	_set_ignore_mouse_recursive(self)


func _set_ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_set_ignore_mouse_recursive(child)


func show_boss(b_name: String, cur_hp: float, m_hp: float) -> void:
	boss_title_label.text = "👑 " + b_name
	boss_progress_bar.max_value = m_hp
	boss_progress_bar.value = cur_hp
	var pct: int = int(round((cur_hp / maxf(m_hp, 1.0)) * 100.0))
	hp_detail_label.text = "%d / %d (%d%%)" % [int(cur_hp), int(m_hp), pct]
	visible = true


func update_hp(cur_hp: float, m_hp: float) -> void:
	boss_progress_bar.max_value = m_hp
	boss_progress_bar.value = cur_hp
	var pct: int = int(round((cur_hp / maxf(m_hp, 1.0)) * 100.0))
	hp_detail_label.text = "%d / %d (%d%%)" % [int(cur_hp), int(m_hp), pct]


func hide_boss() -> void:
	visible = false
