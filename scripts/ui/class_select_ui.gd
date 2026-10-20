class_name ClassSelectUI
extends CanvasLayer

## Interface de sélection des 4 classes au démarrage du jeu.

const PlayerClassData = preload("res://scripts/player/player_class_data.gd")

signal class_selected(class_type: int)

var is_open: bool = false


func _ready() -> void:
	visible = false
	_build_ui()


func open_selection() -> void:
	is_open = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_selection() -> void:
	is_open = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _build_ui() -> void:
	# Fond obscurci
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.09, 0.92)
	add_child(bg)

	# Titre général
	var title := Label.new()
	title.text = "CHOISISSEZ VOTRE CLASSE"
	title.position = Vector2(0.0, 40.0)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Chaque classe possède son style de combat, son attaque de base et 3 compétences uniques."
	subtitle.position = Vector2(0.0, 85.0)
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
	add_child(subtitle)

	# Conteneur des 4 cartes de classes
	var cards_container := HBoxContainer.new()
	cards_container.set_anchors_preset(Control.PRESET_CENTER)
	cards_container.custom_minimum_size = Vector2(1100.0, 480.0)
	cards_container.position = Vector2(-550.0, -210.0)
	cards_container.add_theme_constant_override("separation", 20)
	add_child(cards_container)

	for i in range(4):
		var card := _create_class_card(i)
		cards_container.add_child(card)


func _create_class_card(c_type: int) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(260.0, 460.0)

	var col: Color = PlayerClassData.CLASS_COLORS[c_type]

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_left = 2
	sb.border_width_top = 4
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = col
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(16.0, 16.0)
	vbox.custom_minimum_size = Vector2(228.0, 428.0)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Nom de la classe
	var name_lbl := Label.new()
	name_lbl.text = PlayerClassData.CLASS_NAMES[c_type].to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", col)
	vbox.add_child(name_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = PlayerClassData.CLASS_DESCRIPTIONS[c_type]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	vbox.add_child(desc_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Liste des 4 compétences
	var skills_title := Label.new()
	skills_title.text = "COMPÉTENCES :"
	skills_title.add_theme_font_size_override("font_size", 13)
	skills_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	vbox.add_child(skills_title)

	var skills: Array[Dictionary] = PlayerClassData.get_skills_for_class(c_type)
	for s in skills:
		var s_lbl := Label.new()
		s_lbl.text = "• [%s] %s (%.0f dégâts)" % [s["key"], s["name"], s["damage"]]
		s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		s_lbl.add_theme_font_size_override("font_size", 11)
		s_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		vbox.add_child(s_lbl)

	# Espaceur
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Bouton de sélection
	var select_btn := Button.new()
	select_btn.text = "CHOISIR CETTE CLASSE"
	select_btn.custom_minimum_size = Vector2(228.0, 42.0)
	select_btn.add_theme_color_override("font_color", col)
	select_btn.pressed.connect(func(): _on_select_pressed(c_type))
	vbox.add_child(select_btn)

	return panel


func _on_select_pressed(c_type: int) -> void:
	class_selected.emit(c_type)
	close_selection()
