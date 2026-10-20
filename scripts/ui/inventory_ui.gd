class_name InventoryUI
extends CanvasLayer

## Interface complète : Inventaire (Touche I), Équipement, Comparaison d'objets et Arbre de Talents.

const ItemData = preload("res://scripts/items/item_data.gd")
const InventoryManager = preload("res://scripts/items/inventory_manager.gd")
const SaveSystem = preload("res://scripts/player/save_system.gd")

var player_ref: CharacterBody3D = null
var inv_manager: InventoryManager = null

var is_open: bool = false
var current_tab: int = 0 # 0: Inventaire, 1: Talents
var selected_slot: int = -1

# Éléments graphiques généraux
var main_panel: Panel = null
var tab_inv_btn: Button = null
var tab_talents_btn: Button = null

# Conteneur Inventaire
var inv_content: Control = null
var grid_container: GridContainer = null
var slot_buttons: Array[Button] = []
var equip_weapon_btn: Button = null
var equip_armor_btn: Button = null
var equip_ring_btn: Button = null
var detail_name_label: Label = null
var detail_type_label: Label = null
var detail_stats_label: Label = null
var detail_compare_label: Label = null
var action_equip_btn: Button = null
var action_drop_btn: Button = null
var player_stats_label: Label = null

# Conteneur Arbre de Talents
var talents_content: Control = null
var talent_points_label: Label = null
var talent_rows: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	_build_ui()


func setup(player: CharacterBody3D, inv: InventoryManager) -> void:
	player_ref = player
	inv_manager = inv

	inv_manager.inventory_changed.connect(_refresh_ui)
	inv_manager.equipment_changed.connect(_refresh_ui)

	if player_ref != null and ("talent_tree" in player_ref) and player_ref.talent_tree != null:
		player_ref.talent_tree.talents_updated.connect(_refresh_ui)


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
	_switch_tab(0)
	_refresh_ui()


func close_inventory() -> void:
	is_open = false
	visible = false
	selected_slot = -1
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if player_ref != null:
		var world_seed: int = 1337
		var world = player_ref.get_node_or_null("../World")
		if world != null and ("world_seed" in world):
			world_seed = world.world_seed
		SaveSystem.save_game(player_ref, world_seed)


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.05, 0.08, 0.65)
	add_child(overlay)

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

	# Boutons d'onglets (INVENTAIRE / TALENTS)
	tab_inv_btn = Button.new()
	tab_inv_btn.text = "🎒 INVENTAIRE & ÉQUIPEMENT"
	tab_inv_btn.position = Vector2(24.0, 14.0)
	tab_inv_btn.custom_minimum_size = Vector2(220.0, 32.0)
	tab_inv_btn.pressed.connect(func(): _switch_tab(0))
	main_panel.add_child(tab_inv_btn)

	tab_talents_btn = Button.new()
	tab_talents_btn.text = "⭐ ARBRE DE TALENTS"
	tab_talents_btn.position = Vector2(260.0, 14.0)
	tab_talents_btn.custom_minimum_size = Vector2(200.0, 32.0)
	tab_talents_btn.pressed.connect(func(): _switch_tab(1))
	main_panel.add_child(tab_talents_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(840.0, 12.0)
	close_btn.custom_minimum_size = Vector2(28.0, 28.0)
	close_btn.pressed.connect(close_inventory)
	main_panel.add_child(close_btn)

	# ===================== ONGLET 1 : INVENTAIRE =====================
	inv_content = Control.new()
	inv_content.position = Vector2(0.0, 50.0)
	main_panel.add_child(inv_content)

	# Panneau gauche : Équipement
	var equip_box := VBoxContainer.new()
	equip_box.position = Vector2(24.0, 10.0)
	equip_box.custom_minimum_size = Vector2(200.0, 320.0)
	equip_box.add_theme_constant_override("separation", 16)
	inv_content.add_child(equip_box)

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

	# Panneau centre : Grille 4x5
	var grid_box := VBoxContainer.new()
	grid_box.position = Vector2(248.0, 10.0)
	grid_box.custom_minimum_size = Vector2(320.0, 320.0)
	inv_content.add_child(grid_box)

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
		var slot_idx: int = i
		btn.pressed.connect(func(): _on_slot_clicked(slot_idx))
		grid_container.add_child(btn)
		slot_buttons.append(btn)

	# Panneau droit : Détails & Comparaison
	var detail_box := VBoxContainer.new()
	detail_box.position = Vector2(588.0, 10.0)
	detail_box.custom_minimum_size = Vector2(268.0, 320.0)
	detail_box.add_theme_constant_override("separation", 8)
	inv_content.add_child(detail_box)

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

	player_stats_label = Label.new()
	player_stats_label.position = Vector2(24.0, 390.0)
	player_stats_label.custom_minimum_size = Vector2(832.0, 60.0)
	player_stats_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	inv_content.add_child(player_stats_label)

	# ===================== ONGLET 2 : ARBRE DE TALENTS =====================
	talents_content = Control.new()
	talents_content.position = Vector2(0.0, 50.0)
	talents_content.visible = false
	main_panel.add_child(talents_content)

	var t_box := VBoxContainer.new()
	t_box.position = Vector2(24.0, 10.0)
	t_box.custom_minimum_size = Vector2(832.0, 440.0)
	t_box.add_theme_constant_override("separation", 14)
	talents_content.add_child(t_box)

	talent_points_label = Label.new()
	talent_points_label.text = "POINTS DISPONIBLES : 0"
	talent_points_label.add_theme_font_size_override("font_size", 18)
	talent_points_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	t_box.add_child(talent_points_label)

	talent_rows.clear()
	var talent_names: Array[String] = [
		"Puissance Martiale / Arcanique",
		"Vitalité Renforcée",
		"Vigueur & Récupération",
		"Frappe Critique",
		"Hâte & Maîtrise des Sorts"
	]
	var talent_descs: Array[String] = [
		"+8% de dégâts sur toutes les attaques par rang.",
		"+15 points de vie max par rang.",
		"+10 endurance max et +12% de régénération par rang.",
		"+6% de chance de coup critique (x1.8 dégâts) par rang.",
		"+7% de réduction du temps de recharge des compétences par rang."
	]

	for i in range(5):
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(832.0, 50.0)
		row.add_theme_constant_override("separation", 16)

		var info_box := VBoxContainer.new()
		info_box.custom_minimum_size = Vector2(620.0, 46.0)

		var t_title := Label.new()
		t_title.text = talent_names[i]
		t_title.add_theme_font_size_override("font_size", 15)
		t_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		info_box.add_child(t_title)

		var t_desc := Label.new()
		t_desc.text = talent_descs[i]
		t_desc.add_theme_font_size_override("font_size", 12)
		t_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		info_box.add_child(t_desc)
		row.add_child(info_box)

		var rank_lbl := Label.new()
		rank_lbl.text = "Rang : 0 / 5"
		rank_lbl.custom_minimum_size = Vector2(90.0, 46.0)
		rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank_lbl.add_theme_font_size_override("font_size", 14)
		rank_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		row.add_child(rank_lbl)

		var up_btn := Button.new()
		up_btn.text = "+ 1 Rang"
		up_btn.custom_minimum_size = Vector2(80.0, 36.0)
		var t_idx: int = i
		up_btn.pressed.connect(func(): _on_upgrade_talent_pressed(t_idx))
		row.add_child(up_btn)

		t_box.add_child(row)
		talent_rows.append({
			"rank_label": rank_lbl,
			"button": up_btn
		})

	var reset_btn := Button.new()
	reset_btn.text = "Réinitialiser les talents"
	reset_btn.custom_minimum_size = Vector2(180.0, 36.0)
	reset_btn.pressed.connect(_on_reset_talents_pressed)
	t_box.add_child(reset_btn)


func _switch_tab(tab: int) -> void:
	current_tab = tab
	if current_tab == 0:
		inv_content.visible = true
		talents_content.visible = false
		tab_inv_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		tab_talents_btn.remove_theme_color_override("font_color")
	else:
		inv_content.visible = false
		talents_content.visible = true
		tab_talents_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		tab_inv_btn.remove_theme_color_override("font_color")
	_refresh_ui()


func _create_equip_slot(title: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(200.0, 58.0)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = title + "\n  (Vide)"
	return btn


func _refresh_ui() -> void:
	if not is_open:
		return

	if current_tab == 0:
		_refresh_inventory_tab()
	else:
		_refresh_talents_tab()


func _refresh_inventory_tab() -> void:
	if inv_manager == null:
		return

	_update_equip_slot_button(equip_weapon_btn, "⚔ Arme", inv_manager.equipped_weapon)
	_update_equip_slot_button(equip_armor_btn, "🛡 Armure", inv_manager.equipped_armor)
	_update_equip_slot_button(equip_ring_btn, "💍 Anneau", inv_manager.equipped_ring)

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

	_update_details_panel()
	_update_player_stats()


func _refresh_talents_tab() -> void:
	if player_ref == null or not ("talent_tree" in player_ref) or player_ref.talent_tree == null:
		return

	var tt = player_ref.talent_tree
	talent_points_label.text = "POINTS DISPONIBLES : %d  (Gagnez 1 point à chaque niveau)" % tt.available_points

	for i in range(talent_rows.size()):
		var r_dict: Dictionary = talent_rows[i]
		var rank: int = tt.ranks[i]
		r_dict["rank_label"].text = "Rang : %d / 5" % rank
		r_dict["button"].disabled = not tt.can_upgrade(i)


func _on_upgrade_talent_pressed(index: int) -> void:
	if player_ref != null and ("talent_tree" in player_ref) and player_ref.talent_tree != null:
		player_ref.talent_tree.upgrade_talent(index)
		_refresh_talents_tab()


func _on_reset_talents_pressed() -> void:
	if player_ref != null and ("talent_tree" in player_ref) and player_ref.talent_tree != null:
		player_ref.talent_tree.reset_talents()
		_refresh_talents_tab()


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

	var r_name: String = ItemData.get_rarity_name(item.rarity)
	detail_name_label.text = item.name
	detail_name_label.add_theme_color_override("font_color", ItemData.get_rarity_color(item.rarity))

	var t_name: String = "Arme" if item.item_type == ItemData.ItemType.WEAPON else ("Armure" if item.item_type == ItemData.ItemType.ARMOR else "Anneau")
	detail_type_label.text = "Type : %s | Rareté : %s | Niv. Requis : %d" % [t_name, r_name, item.level_req]

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

	var current: ItemData = inv_manager.get_equipped_for_type(item.item_type)
	var comp_lines: Array[String] = ["[COMPARAISON]"]
	if current != null:
		comp_lines.append("Actuel : %s" % current.name)
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
		comp_lines.append("(Aucun équipement actuel)")

	detail_compare_label.text = "\n".join(comp_lines)


func _update_player_stats() -> void:
	if player_ref == null or inv_manager == null:
		return

	var atk_bonus: float = inv_manager.get_total_attack_bonus()
	var def_bonus: float = inv_manager.get_total_defense_bonus()
	var hp_bonus: float = inv_manager.get_total_health_bonus()
	var sta_bonus: float = inv_manager.get_total_stamina_bonus()

	var talent_mult: float = player_ref.talent_tree.get_damage_multiplier() if ("talent_tree" in player_ref and player_ref.talent_tree != null) else 1.0

	var total_atk: float = (22.0 + atk_bonus) * talent_mult
	var total_hp: float = player_ref.get_effective_max_health()
	var total_sta: float = player_ref.get_effective_max_stamina()

	player_stats_label.text = "HÉROS (%s) - Niveau : %d | XP : %d / %d\nAttaque : %.0f | Défense : %.0f | PV Max : %.0f | Endurance : %.0f\n(Touche 'I' pour fermer, sauvegarde automatique)" % [
		player_ref.get_class_name_str(),
		player_ref.level,
		player_ref.current_xp,
		player_ref.xp_to_next_level,
		total_atk,
		def_bonus,
		total_hp,
		total_sta
	]
