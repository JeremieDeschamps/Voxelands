class_name MainMenuUI
extends CanvasLayer

## Écran titre et Menu Principal de Voxelands avec Nouvelle Partie, Continuer, Réglages et Quitter.

const VoxelConstants = preload("res://scripts/world/voxel_constants.gd")
const SaveSystem = preload("res://scripts/player/save_system.gd")

signal start_game_requested(is_new_game: bool, custom_seed: int)

var is_open: bool = true
var pause_menu_ref: Node = null

var panel: Panel = null
var continue_btn: Button = null
var new_game_btn: Button = null
var seed_input: LineEdit = null
var settings_btn: Button = null
var quit_btn: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_check_save_file()


func setup(pause_menu: Node) -> void:
	pause_menu_ref = pause_menu


func _build_ui() -> void:
	var screen_sz := Vector2(1280.0, 720.0)

	panel = Panel.new()
	panel.name = "MainMenuPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	panel.add_theme_stylebox_override("panel", bg_sb)
	add_child(panel)

	# Titre du jeu
	var title_box := VBoxContainer.new()
	title_box.position = Vector2((screen_sz.x - 700.0) * 0.5, 90.0)
	title_box.size = Vector2(700.0, 120.0)
	title_box.add_theme_constant_override("separation", 8)
	panel.add_child(title_box)

	var title := Label.new()
	title.text = "⚔️ VOXELANDS 🌲"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.25))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "RPG d'Aventure & d'Exploration Voxel en Monde Ouvert"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	title_box.add_child(subtitle)

	var badges := Label.new()
	badges.text = "Moteur Godot 4 • Zéro Asset Externe • 100% Procédural"
	badges.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badges.add_theme_color_override("font_color", Color(0.45, 0.65, 0.55))
	title_box.add_child(badges)

	# Boutons du menu
	var btn_vbox := VBoxContainer.new()
	btn_vbox.position = Vector2((screen_sz.x - 300.0) * 0.5, 270.0)
	btn_vbox.size = Vector2(300.0, 260.0)
	btn_vbox.add_theme_constant_override("separation", 16)
	panel.add_child(btn_vbox)

	continue_btn = _create_menu_btn("⚔️ Continuer la Partie")
	continue_btn.pressed.connect(_on_continue_pressed)
	btn_vbox.add_child(continue_btn)

	new_game_btn = _create_menu_btn("✨ Nouvelle Aventure")
	new_game_btn.pressed.connect(_on_new_game_pressed)
	btn_vbox.add_child(new_game_btn)

	# Champ optionnel pour spécifier une graine
	var seed_box := VBoxContainer.new()
	seed_box.add_theme_constant_override("separation", 4)
	var seed_lbl := Label.new()
	seed_lbl.text = "Graine personnalisée (Optionnelle) :"
	seed_lbl.add_theme_font_size_override("font_size", 12)
	seed_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.90))
	seed_box.add_child(seed_lbl)

	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Laisser vide pour aléatoire (ex: 42)"
	seed_input.custom_minimum_size = Vector2(300.0, 32.0)
	seed_box.add_child(seed_input)
	btn_vbox.add_child(seed_box)

	settings_btn = _create_menu_btn("⚙️ Paramètres & Options")
	settings_btn.pressed.connect(_on_settings_pressed)
	btn_vbox.add_child(settings_btn)

	quit_btn = _create_menu_btn("🚪 Quitter le Jeu")
	quit_btn.pressed.connect(func(): get_tree().quit())
	btn_vbox.add_child(quit_btn)

	# Contrôles de jeu en bas
	var controls_hint := Label.new()
	controls_hint.position = Vector2(0.0, 640.0)
	controls_hint.size = Vector2(screen_sz.x, 30.0)
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint.text = "Contrôles : ZQSD/WASD • Espace : Saut/Planeur • Shift : Sprint • I : Inventaire • M : Carte • F : Interagir • F3 : Debug"
	controls_hint.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75))
	panel.add_child(controls_hint)


func _create_menu_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(300.0, 44.0)
	return btn


func _check_save_file() -> void:
	var has_save: bool = SaveSystem.has_valid_save()
	if continue_btn != null:
		continue_btn.disabled = not has_save
		if not has_save:
			if FileAccess.file_exists("user://save.json"):
				continue_btn.text = "⚔️ Continuer (Incompatible - v%d)" % VoxelConstants.SAVE_VERSION
			else:
				continue_btn.text = "⚔️ Continuer (Aucune sauvegarde)"
		else:
			continue_btn.text = "⚔️ Continuer l'Aventure"


func _on_continue_pressed() -> void:
	close_main_menu()
	start_game_requested.emit(false, -1)


func _on_new_game_pressed() -> void:
	var user_seed: int = -1
	if seed_input != null and seed_input.text.strip_edges() != "":
		var txt: String = seed_input.text.strip_edges()
		if txt.is_valid_int():
			user_seed = int(txt)
		else:
			user_seed = abs(txt.hash()) % 1000000 + 1
	close_main_menu()
	start_game_requested.emit(true, user_seed)


func _on_settings_pressed() -> void:
	if pause_menu_ref != null and pause_menu_ref.has_method("_open_settings"):
		pause_menu_ref.open_pause()
		pause_menu_ref._open_settings()


func open_main_menu() -> void:
	is_open = true
	visible = true
	_check_save_file()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_main_menu() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
