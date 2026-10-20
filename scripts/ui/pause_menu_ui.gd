class_name PauseMenuUI
extends CanvasLayer

## Menu Pause (Touche Echap) et panneau complet de réglages (Distance de rendu, Volume, Ombres, Brouillard, FPS).

signal game_resumed
signal return_to_main_menu

var player_ref: CharacterBody3D = null
var sound_gen: Node = null
var world_ref: Node3D = null

var is_open: bool = false
var is_in_settings: bool = false

# Panels
var main_pause_panel: Panel = null
var settings_panel: Panel = null

# Main pause widgets
var resume_btn: Button = null
var settings_btn: Button = null
var save_btn: Button = null
var main_menu_btn: Button = null
var quit_btn: Button = null
var save_feedback_label: Label = null

# Settings widgets
var render_dist_slider: HSlider = null
var render_dist_label: Label = null
var volume_slider: HSlider = null
var volume_label: Label = null
var shadows_check: CheckBox = null
var fog_check: CheckBox = null
var fps_option: OptionButton = null
var back_btn: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func setup(player: CharacterBody3D, world_node: Node3D, s_gen: Node) -> void:
	player_ref = player
	world_ref = world_node
	sound_gen = s_gen


func _build_ui() -> void:
	var screen_sz := Vector2(1280.0, 720.0)

	# 1. Panneau Principal de Pause
	main_pause_panel = Panel.new()
	main_pause_panel.name = "PausePanel"
	main_pause_panel.size = Vector2(360.0, 420.0)
	main_pause_panel.position = (screen_sz - main_pause_panel.size) * 0.5

	var p_sb := StyleBoxFlat.new()
	p_sb.bg_color = Color(0.08, 0.10, 0.14, 0.94)
	p_sb.border_width_left = 2
	p_sb.border_width_top = 2
	p_sb.border_width_right = 2
	p_sb.border_width_bottom = 2
	p_sb.border_color = Color(0.85, 0.70, 0.25)
	p_sb.corner_radius_top_left = 8
	p_sb.corner_radius_top_right = 8
	p_sb.corner_radius_bottom_left = 8
	p_sb.corner_radius_bottom_right = 8
	main_pause_panel.add_theme_stylebox_override("panel", p_sb)
	add_child(main_pause_panel)

	var title := Label.new()
	title.text = "⏸️ JEU EN PAUSE"
	title.position = Vector2(0.0, 24.0)
	title.size = Vector2(360.0, 30.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	main_pause_panel.add_child(title)

	var btn_vbox := VBoxContainer.new()
	btn_vbox.position = Vector2(36.0, 75.0)
	btn_vbox.size = Vector2(288.0, 260.0)
	btn_vbox.add_theme_constant_override("separation", 14)
	main_pause_panel.add_child(btn_vbox)

	resume_btn = _create_menu_button("▶ Reprendre la Partie")
	resume_btn.pressed.connect(resume_game)
	btn_vbox.add_child(resume_btn)

	settings_btn = _create_menu_button("⚙️ Paramètres & Réglages")
	settings_btn.pressed.connect(_open_settings)
	btn_vbox.add_child(settings_btn)

	save_btn = _create_menu_button("💾 Sauvegarder la Partie")
	save_btn.pressed.connect(_on_save_pressed)
	btn_vbox.add_child(save_btn)

	main_menu_btn = _create_menu_button("🏠 Écran Titre")
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	btn_vbox.add_child(main_menu_btn)

	quit_btn = _create_menu_button("🚪 Quitter le Jeu")
	quit_btn.pressed.connect(_on_quit_pressed)
	btn_vbox.add_child(quit_btn)

	save_feedback_label = Label.new()
	save_feedback_label.position = Vector2(0.0, 375.0)
	save_feedback_label.size = Vector2(360.0, 24.0)
	save_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_feedback_label.text = ""
	save_feedback_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
	main_pause_panel.add_child(save_feedback_label)

	# 2. Panneau des Réglages
	_build_settings_panel(screen_sz)


func _build_settings_panel(screen_sz: Vector2) -> void:
	settings_panel = Panel.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.size = Vector2(460.0, 480.0)
	settings_panel.position = (screen_sz - settings_panel.size) * 0.5
	settings_panel.visible = false

	var s_sb := StyleBoxFlat.new()
	s_sb.bg_color = Color(0.08, 0.10, 0.14, 0.96)
	s_sb.border_width_left = 2
	s_sb.border_width_top = 2
	s_sb.border_width_right = 2
	s_sb.border_width_bottom = 2
	s_sb.border_color = Color(0.35, 0.65, 0.95)
	s_sb.corner_radius_top_left = 8
	s_sb.corner_radius_top_right = 8
	s_sb.corner_radius_bottom_left = 8
	s_sb.corner_radius_bottom_right = 8
	settings_panel.add_theme_stylebox_override("panel", s_sb)
	add_child(settings_panel)

	var s_title := Label.new()
	s_title.text = "⚙️ RÉGLAGES & OPTIONS"
	s_title.position = Vector2(0.0, 20.0)
	s_title.size = Vector2(460.0, 30.0)
	s_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_title.add_theme_color_override("font_color", Color(0.35, 0.85, 0.95))
	settings_panel.add_child(s_title)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(36.0, 68.0)
	vbox.size = Vector2(388.0, 340.0)
	vbox.add_theme_constant_override("separation", 16)
	settings_panel.add_child(vbox)

	# Distance de rendu
	var r_box := VBoxContainer.new()
	render_dist_label = Label.new()
	render_dist_label.text = "Distance de rendu : 4 chunks (64 blocs)"
	r_box.add_child(render_dist_label)
	render_dist_slider = HSlider.new()
	render_dist_slider.min_value = 2
	render_dist_slider.max_value = 8
	render_dist_slider.step = 1
	render_dist_slider.value = 4
	render_dist_slider.value_changed.connect(_on_render_dist_changed)
	r_box.add_child(render_dist_slider)
	vbox.add_child(r_box)

	# Volume sonore
	var v_box := VBoxContainer.new()
	volume_label = Label.new()
	volume_label.text = "Volume Général : 80%"
	v_box.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = 0.8
	volume_slider.value_changed.connect(_on_volume_changed)
	v_box.add_child(volume_slider)
	vbox.add_child(v_box)

	# Ombres dynamiques
	shadows_check = CheckBox.new()
	shadows_check.text = " Ombres Solaires Dynamiques"
	shadows_check.button_pressed = true
	shadows_check.toggled.connect(_on_shadows_toggled)
	vbox.add_child(shadows_check)

	# Brouillard volumétrique
	fog_check = CheckBox.new()
	fog_check.text = " Brouillard Atmosphérique"
	fog_check.button_pressed = true
	fog_check.toggled.connect(_on_fog_toggled)
	vbox.add_child(fog_check)

	# Limite de FPS
	var f_box := HBoxContainer.new()
	var f_lbl := Label.new()
	f_lbl.text = "Limite de Fréquence : "
	f_box.add_child(f_lbl)
	fps_option = OptionButton.new()
	fps_option.add_item("60 FPS", 0)
	fps_option.add_item("120 FPS", 1)
	fps_option.add_item("Illimité", 2)
	fps_option.select(1)
	fps_option.item_selected.connect(_on_fps_selected)
	f_box.add_child(fps_option)
	vbox.add_child(f_box)

	# Bouton Retour
	back_btn = _create_menu_button("← Retour au Menu Pause")
	back_btn.position = Vector2(90.0, 424.0)
	back_btn.size = Vector2(280.0, 36.0)
	back_btn.pressed.connect(_close_settings)
	settings_panel.add_child(back_btn)


func _create_menu_button(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(240.0, 38.0)
	return btn


func toggle_pause() -> void:
	if is_open:
		resume_game()
	else:
		open_pause()


func open_pause() -> void:
	is_open = true
	visible = true
	is_in_settings = false
	main_pause_panel.visible = true
	settings_panel.visible = false
	save_feedback_label.text = ""
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func resume_game() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	game_resumed.emit()


func _open_settings() -> void:
	is_in_settings = true
	main_pause_panel.visible = false
	settings_panel.visible = true


func _close_settings() -> void:
	is_in_settings = false
	settings_panel.visible = false
	main_pause_panel.visible = true


func _on_save_pressed() -> void:
	if player_ref != null and player_ref.has_method("_save_current_game"):
		player_ref._save_current_game()
		save_feedback_label.text = "✓ Partie sauvegardée avec succès !"
		if sound_gen != null and sound_gen.has_method("play_chest"):
			sound_gen.play_chest()


func _on_main_menu_pressed() -> void:
	if player_ref != null and player_ref.has_method("_save_current_game"):
		player_ref._save_current_game()
	resume_game()
	return_to_main_menu.emit()


func _on_quit_pressed() -> void:
	if player_ref != null and player_ref.has_method("_save_current_game"):
		player_ref._save_current_game()
	get_tree().quit()


func _on_render_dist_changed(val: float) -> void:
	var dist: int = int(val)
	render_dist_label.text = "Distance de rendu : %d chunks (%d blocs)" % [dist, dist * 16]
	if world_ref != null and ("render_distance" in world_ref):
		world_ref.render_distance = dist
		if world_ref.has_method("_update_chunks_around_target"):
			world_ref._update_chunks_around_target()


func _on_volume_changed(val: float) -> void:
	volume_label.text = "Volume Général : %d%%" % int(round(val * 100.0))
	if sound_gen != null and sound_gen.has_method("set_volume"):
		sound_gen.set_volume(val)


func _on_shadows_toggled(toggled: bool) -> void:
	var lights: Array[Node] = get_tree().get_nodes_in_group("sun_light")
	for l in lights:
		if l is DirectionalLight3D:
			l.shadow_enabled = toggled


func _on_fog_toggled(toggled: bool) -> void:
	var env_node = get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if env_node != null and env_node.environment != null:
		env_node.environment.fog_enabled = toggled


func _on_fps_selected(idx: int) -> void:
	match idx:
		0: Engine.max_fps = 60
		1: Engine.max_fps = 120
		2: Engine.max_fps = 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_open:
				if is_in_settings:
					_close_settings()
				else:
					resume_game()
