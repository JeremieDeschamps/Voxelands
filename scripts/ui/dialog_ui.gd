class_name DialogUI
extends CanvasLayer

## Boîte de dialogue pour interagir avec les PNJ des villages, accepter et rendre les quêtes.

signal dialog_closed

var is_open: bool = false
var current_npc: Node = null
var current_quest: Dictionary = {}

var panel: Panel = null
var name_label: Label = null
var text_label: Label = null
var quest_box: VBoxContainer = null
var quest_title: Label = null
var quest_desc: Label = null
var quest_reward: Label = null

var accept_btn: Button = null
var claim_btn: Button = null
var close_btn: Button = null


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	var screen_size := Vector2(1280.0, 720.0)

	panel = Panel.new()
	panel.name = "DialogPanel"
	panel.size = Vector2(620.0, 240.0)
	panel.position = Vector2((screen_size.x - 620.0) * 0.5, screen_size.y - 280.0)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.16, 0.95)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.35, 0.65, 0.95)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	# Nom du PNJ
	name_label = Label.new()
	name_label.position = Vector2(24.0, 14.0)
	name_label.text = "Nom du PNJ"
	name_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.22))
	panel.add_child(name_label)

	# Texte du dialogue
	text_label = Label.new()
	text_label.position = Vector2(24.0, 42.0)
	text_label.size = Vector2(572.0, 48.0)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.text = "Salutations voyageur !"
	text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	panel.add_child(text_label)

	# Zone de quête
	quest_box = VBoxContainer.new()
	quest_box.position = Vector2(24.0, 95.0)
	quest_box.size = Vector2(572.0, 85.0)
	quest_box.add_theme_constant_override("separation", 3)
	panel.add_child(quest_box)

	quest_title = Label.new()
	quest_title.text = "Quête : Titre"
	quest_title.add_theme_color_override("font_color", Color(0.35, 0.85, 0.95))
	quest_box.add_child(quest_title)

	quest_desc = Label.new()
	quest_desc.text = "Description de l'objectif."
	quest_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	quest_box.add_child(quest_desc)

	quest_reward = Label.new()
	quest_reward.text = "Récompense : +150 XP, Équipement mystère"
	quest_reward.add_theme_color_override("font_color", Color(0.45, 0.95, 0.45))
	quest_box.add_child(quest_reward)

	# Boutons d'action
	var btn_row := HBoxContainer.new()
	btn_row.position = Vector2(24.0, 192.0)
	btn_row.size = Vector2(572.0, 34.0)
	btn_row.add_theme_constant_override("separation", 16)
	panel.add_child(btn_row)

	accept_btn = Button.new()
	accept_btn.text = "Accepter la Quête"
	accept_btn.custom_minimum_size = Vector2(160.0, 32.0)
	accept_btn.pressed.connect(_on_accept_pressed)
	btn_row.add_child(accept_btn)

	claim_btn = Button.new()
	claim_btn.text = "Réclamer Récompense"
	claim_btn.custom_minimum_size = Vector2(170.0, 32.0)
	claim_btn.pressed.connect(_on_claim_pressed)
	btn_row.add_child(claim_btn)

	close_btn = Button.new()
	close_btn.text = "Fermer [Echap]"
	close_btn.custom_minimum_size = Vector2(120.0, 32.0)
	close_btn.pressed.connect(close_dialog)
	btn_row.add_child(close_btn)


func open_dialog(npc: Node, p_name: String, msg: String, quest: Dictionary, player_quests: RefCounted) -> void:
	current_npc = npc
	current_quest = quest
	is_open = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	name_label.text = "🗣️ %s" % p_name
	text_label.text = msg

	if quest.is_empty():
		quest_box.visible = false
		accept_btn.visible = false
		claim_btn.visible = false
	else:
		quest_box.visible = true
		quest_title.text = "📜 %s" % quest.get("title", "Quête")
		quest_desc.text = quest.get("desc", "")
		quest_reward.text = "🎁 Récompenses : +%d XP, Équipement Aléatoire" % quest.get("reward_xp", 100)

		# Vérifier statut dans le quest system
		var q_id: String = quest.get("id", "")
		var is_active: bool = false
		var is_done: bool = false

		if player_quests != null:
			for aq in player_quests.active_quests:
				if aq["id"] == q_id:
					is_active = true
					if aq.get("is_completed", false):
						is_done = true
					break

		if is_done:
			accept_btn.visible = false
			claim_btn.visible = true
			claim_btn.disabled = false
		elif is_active:
			accept_btn.visible = true
			accept_btn.disabled = true
			accept_btn.text = "En cours..."
			claim_btn.visible = false
		else:
			accept_btn.visible = true
			accept_btn.disabled = false
			accept_btn.text = "Accepter la Quête"
			claim_btn.visible = false


func _on_accept_pressed() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p: CharacterBody3D = players[0] as CharacterBody3D
		if "quest_system" in p and p.quest_system != null:
			p.quest_system.accept_quest(current_quest)
	close_dialog()


func _on_claim_pressed() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p: CharacterBody3D = players[0] as CharacterBody3D
		if "quest_system" in p and p.quest_system != null:
			p.quest_system.claim_reward(current_quest.get("id", ""), p)
	close_dialog()


func close_dialog() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0].has_method("_capture_mouse"):
		players[0]._capture_mouse()
	dialog_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_dialog()
