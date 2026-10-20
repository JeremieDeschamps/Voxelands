class_name InventoryUI
extends CanvasLayer

## Interface complète de l'inventaire (Touche I) : grille, équipement, comparaison et statistiques.

const ItemData = preload("res://scripts/items/item_data.gd")
const InventoryManager = preload("res://scripts/items/inventory_manager.gd")
const SaveSystem = preload("res://scripts/player/save_system.gd")

var player_ref: CharacterBody3D = null
var inv_manager: InventoryManager = null

var is_open: bool = false
var selected_slot: int = -1

# Éléments graphiques
var main_panel: Panel = null
var grid_container: GridContainer = null
var slot_buttons: Array[Button] = []

var equip_weapon_btn: Button = null
var equip_armor_btn: Button = null
var equip_ring_btn: Button = null

# Panneau de détails & comparaison
var detail_name_label: Label = null
var detail_type_label: Label = null
var detail_stats_label: Label = null
var detail_compare_label: Label = null
var action_equip_btn: Button = null
var action_drop_btn: Button = null

# Panneau des stats du joueur
var player_stats_label: Label = null


func _ready() -> void:
	visible = false
	_build_ui()


func setup(player: CharacterBody3D, inv: InventoryManager) -> void:
	player_ref = player
	inv_manager = inv

	inv_manager.inventory_changed.connect(_refresh_ui)
	inv_manager.equipment_changed.connect(_refresh_ui)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			toggle_inventory()
		elif event.keycode == KEY_ESCAPE and is_open:
			close_inventory()


func toggle_inventory() -> void:
	if is_open:
		close_inventory()
	else:
		open_inventory()


func open_inventory() -> void:
	is_open = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_ui()


func close_inventory() -> void:
	is_open = false
	visible = false
	selected_slot = -1
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Sauvegarde automatique à la fermeture de l'inventaire
	if player_ref != null:
		var world_seed: int = 1337
		var world = player_ref.get_node_or_null("../World")
		if world != null and ("world_seed" in world):
			world_seed = world.world_seed
		SaveSystem.save_game(player_ref, world_seed)


func _build_ui() -> void:
	# Fond obscurci
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.05, 0.08, 0.65)
	add_child(overlay)

	# Fenêtre principale centrée (880 x 520)
	main_panel = Panel.new()
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.custom_minimum_size = Vector2(880.0, 520.0)
	main_panel.position = Vector2(-440.0, -260.0)

	var sb_main := StyleBoxFlat.new()
	sb_main.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	sb_main.corner_radius_top_left = 8
	sb_main.corner_radius_top_right = 8
	sb_main.corner_radius_bottom_left = 8
	sb_main.corner_radius_bottom_right = 8
	sb_main.border_width_left = 2
	sb_main.border_width_top = 2
	sb_main.border_width_right = 2
	sb_main.border_width_bottom = 2
	sb_main.border_color = Color(0.35, 0.35, 0.42)
	main_panel.add_theme_stylebox_override("panel", sb_main)
	add_child(main_panel)

	# Barre de titre
	var title_lbl := Label.new()
	title_lbl.text = "INVENTAIRE & ÉQUIPEMENT"
	title_lbl.position = Vector2(24.0, 16.0)
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	main_panel.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(840.0, 12.0)
	close_btn.custom_minimum_size = Vector2(28.0, 28.0)
	close_btn.pressed.connect(close_inventory)
	main_panel.add_child(close_btn)

	# 1. PANNEAU GAUCHE : ÉQUIPEMENT (Arme, Armure, Anneau)
	var equip_box := VBoxContainer.new()
	equip_box.position = Vector2(24.0, 60.0)
	equip_box.custom_minimum_size = Vector2(200.0, 320.0)
	equip_box.add_theme_constant_override("separation", 16)
	main_panel.add_child(equip_box)

	var equip_title := Label.new()
	equip_title.text = "ÉQUIPEMENT ACTIF"
	equip_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	equip_box.add_child(equip_title)

	equip_weapon_btn = _create_equip_slot("⚔ Arme")
	equip_weapon_btn.pressed.connect(func(): _on_equip_slot_clicked(ItemData.ItemType.WEAPON))
	equip_box.add_child(equip_weapon_btn)

	equip_armor_btn = _create_equip_slot("🛡 Armure")
	equip_armor_btn.pressed.connect(func(): _on_equip_slot_clicked(ItemData.ItemType.ARMOR))
	equip_box.add_child(equip_armor_btn)

	equip_ring_btn = _create_equip_slot("💍 Anneau")
	equip_ring_btn.pressed.connect(func(): _on_equip_slot_clicked(ItemData.ItemType.RING))
	equip_box.add_child(equip_ring_btn)

	# 2. PANNEAU CENTRE : GRILLE 4 x 5 (20 cases)
	var grid_box := VBoxContainer.new()
	grid_box.position = Vector2(248.0, 60.0)
	grid_box.custom_minimum_size = Vector2(320.0, 320.0)
	main_panel.add_child(grid_box)

	var grid_title := Label.new()
	grid_title.text = "SAC À DOS (20 emplacements)"
	grid_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	grid_box.add_child(grid_title)

	grid_container = GridContainer.new()
	grid_container.columns = 5
	grid_container.add_theme_constant_override("h_separation", 6)
	grid_container.add_theme_constant_override("v_separation", 6)
	grid_box.add_child(grid_container)

	slot_buttons.clear()
	for i in range(20):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(58.0, 58.0)
		btn.text = ""
		var slot_idx: int = i
		btn.pressed.connect(func(): _on_slot_clicked(slot_idx))
		grid_container.add_child(btn)
		slot_buttons.append(btn)

	# 3. PANNEAU DROIT : DÉTAILS & COMPARAISON
	var detail_box := VBoxContainer.new()
	detail_box.position = Vector2(588.0, 60.0)
	detail_box.custom_minimum_size = Vector2(268.0, 320.0)
	detail_box.add_theme_constant_override("separation", 10)
	main_panel.add_child(detail_box)

	detail_name_label = Label.new()
	detail_name_label.text = "Sélectionnez un objet"
	detail_name_label.add_theme_font_size_override("font_size", 16)
	detail_box.add_child(detail_name_label)

	detail_type_label = Label.new()
	detail_type_label.text = ""
	detail_type_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	detail_box.add_child(detail_type_label)

	detail_stats_label = Label.new()
	detail_stats_label.text = ""
	detail_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_box.add_child(detail_stats_label)

	detail_compare_label = Label.new()
	detail_compare_label.text = ""
	detail_compare_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_box.add_child(detail_compare_label)

	var action_box := HBoxContainer.new()
	action_box.add_theme_constant_override("separation", 12)
	detail_box.add_child(action_box)

	action_equip_btn = Button.new()
	action_equip_btn.text = "Équiper"
	action_equip_btn.custom_minimum_size = Vector2(100.0, 36.0)
	action_equip_btn.pressed.connect(_on_equip_action_pressed)
	action_box.add_child(action_equip_btn)

	action_drop_btn = Button.new()
	action_drop_btn.text = "Jeter"
	action_drop_btn.custom_minimum_size = Vector2(100.0, 36.0)
	action_drop_btn.pressed.connect(_on_drop_action_pressed)
	action_box.add_child(action_drop_btn)

	# 4. PANNEAU DU BAS : STATS DU JOUEUR (Niveau, XP, Attaque, Défense)
	player_stats_label = Label.new()
	player_stats_label.position = Vector2(24.0, 440.0)
	player_stats_label.custom_minimum_size = Vector2(832.0, 60.0)
	player_stats_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	main_panel.add_child(player_stats_label)


func _create_equip_slot(title: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(200.0, 58.0)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = title + "\n  (Vide)"
	return btn


func _refresh_ui() -> void:
	if not is_open or inv_manager == null:
		return

	# 1. Mise à jour des slots d'équipement
	_update_equip_slot_button(equip_weapon_btn, "⚔ Arme", inv_manager.equipped_weapon)
	_update_equip_slot_button(equip_armor_btn, "🛡 Armure", inv_manager.equipped_armor)
	_update_equip_slot_button(equip_ring_btn, "💍 Anneau", inv_manager.equipped_ring)

	# 2. Mise à jour de la grille
	for i in range(20):
		var btn: Button = slot_buttons[i]
		var it: ItemData = inv_manager.items[i]
		if it != null:
			btn.text = it.name.substr(0, 10)
			var col: Color = ItemData.get_rarity_color(it.rarity)
			btn.add_theme_color_override("font_color", col)
		else:
			btn.text = ""
			btn.remove_theme_color_override("font_color")

	# 3. Mise à jour du panneau de détails
	_update_details_panel()

	# 4. Mise à jour des statistiques joueur
	_update_player_stats()


func _update_equip_slot_button(btn: Button, slot_title: String, item: ItemData) -> void:
	if item != null:
		btn.text = "%s\n  %s" % [slot_title, item.name]
		btn.add_theme_color_override("font_color", ItemData.get_rarity_color(item.rarity))
	else:
		btn.text = "%s\n  (Vide)" % slot_title
		btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))


func _on_slot_clicked(slot_idx: int) -> void:
	selected_slot = slot_idx
	_update_details_panel()


func _on_equip_slot_clicked(item_type: int) -> void:
	if inv_manager != null:
		inv_manager.unequip_item(item_type)


func _on_equip_action_pressed() -> void:
	if inv_manager != null and selected_slot != -1:
		inv_manager.equip_item(selected_slot)
		selected_slot = -1
		_refresh_ui()


func _on_drop_action_pressed() -> void:
	if inv_manager != null and selected_slot != -1:
		inv_manager.remove_item(selected_slot)
		selected_slot = -1
		_refresh_ui()


func _update_details_panel() -> void:
	if selected_slot == -1 or inv_manager == null or inv_manager.items[selected_slot] == null:
		detail_name_label.text = "Sélectionnez un objet"
		detail_name_label.add_theme_color_override("font_color", Color.WHITE)
		detail_type_label.text = ""
		detail_stats_label.text = ""
		detail_compare_label.text = ""
		action_equip_btn.disabled = true
		action_drop_btn.disabled = true
		return

	var item: ItemData = inv_manager.items[selected_slot]
	action_equip_btn.disabled = false
	action_drop_btn.disabled = false

	# Nom & Rareté
	var r_name: String = ItemData.get_rarity_name(item.rarity)
	detail_name_label.text = item.name
	detail_name_label.add_theme_color_override("font_color", ItemData.get_rarity_color(item.rarity))

	var t_name: String = "Arme" if item.item_type == ItemData.ItemType.WEAPON else ("Armure" if item.item_type == ItemData.ItemType.ARMOR else "Anneau")
	detail_type_label.text = "Type : %s | Rareté : %s | Niv. Requis : %d" % [t_name, r_name, item.level_req]

	# Statistiques
	var stat_lines: Array[String] = []
	if item.attack_bonus > 0.0:
		stat_lines.append("• Attaque : +%.0f" % item.attack_bonus)
	if item.defense_bonus > 0.0:
		stat_lines.append("• Défense : +%.0f" % item.defense_bonus)
	if item.health_bonus > 0.0:
		stat_lines.append("• PV Max : +%.0f" % item.health_bonus)
	if item.stamina_bonus > 0.0:
		stat_lines.append("• Endurance : +%.0f" % item.stamina_bonus)
	detail_stats_label.text = "\n".join(stat_lines)

	# Comparaison avec l'équipement actuel
	var current: ItemData = inv_manager.get_equipped_for_type(item.item_type)
	var comp_lines: Array[String] = ["[COMPARAISON AVEC ÉQUIPEMENT ACTUEL]"]
	if current != null:
		comp_lines.append("Remplacement de : %s" % current.name)
		var diff_atk: float = item.attack_bonus - current.attack_bonus
		var diff_def: float = item.defense_bonus - current.defense_bonus
		var diff_hp: float = item.health_bonus - current.health_bonus
		var diff_sta: float = item.stamina_bonus - current.stamina_bonus

		if diff_atk != 0.0:
			comp_lines.append("Attaque : %s%.0f" % ["+" if diff_atk > 0.0 else "", diff_atk])
		if diff_def != 0.0:
			comp_lines.append("Défense : %s%.0f" % ["+" if diff_def > 0.0 else "", diff_def])
		if diff_hp != 0.0:
			comp_lines.append("PV : %s%.0f" % ["+" if diff_hp > 0.0 else "", diff_hp])
		if diff_sta != 0.0:
			comp_lines.append("Endurance : %s%.0f" % ["+" if diff_sta > 0.0 else "", diff_sta])
	else:
		comp_lines.append("(Aucun équipement actuellement dans cet emplacement)")

	detail_compare_label.text = "\n".join(comp_lines)


func _update_player_stats() -> void:
	if player_ref == null or inv_manager == null:
		return

	var atk_bonus: float = inv_manager.get_total_attack_bonus()
	var def_bonus: float = inv_manager.get_total_defense_bonus()
	var hp_bonus: float = inv_manager.get_total_health_bonus()
	var sta_bonus: float = inv_manager.get_total_stamina_bonus()

	var total_atk: float = 22.0 + atk_bonus
	var total_hp: float = player_ref.max_health + hp_bonus
	var total_sta: float = player_ref.max_stamina + sta_bonus

	player_stats_label.text = "HÉROS - Niveau : %d | XP : %d / %d\nAttaque Totale : %.0f (+%.0f) | Défense : %.0f | PV Max : %.0f | Endurance : %.0f\n(Touche 'I' pour fermer, sauvegarde auto)" % [
		player_ref.level,
		player_ref.current_xp,
		player_ref.xp_to_next_level,
		total_atk,
		atk_bonus,
		def_bonus,
		total_hp,
		total_sta
	]
