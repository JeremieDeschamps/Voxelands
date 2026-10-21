class_name WorldMapUI
extends CanvasLayer

## Carte du monde interactive (Touche M) avec rendu 2D des biomes, position du joueur, villages et donjons.

const Chunk = preload("res://scripts/world/chunk.gd")
const BlockTypes = preload("res://scripts/world/block_types.gd")
const VoxelConstants = preload("res://scripts/world/voxel_constants.gd")

var is_open: bool = false
var player_ref: CharacterBody3D = null
var world_ref: Node3D = null

var panel: Panel = null
var map_texture_rect: TextureRect = null
var markers_overlay: Control = null
var coords_label: Label = null
var legend_container: HBoxContainer = null

var map_image: Image = null
var map_texture: ImageTexture = null

const MAP_PIXELS: int = 180 # Résolution de la minicarte
const MAP_SCALE_BLOCKS: float = 2.5 # Nombre de blocs par pixel de carte (couvre 450x450 blocs)
var last_rendered_center: Vector2 = Vector2(999999, 999999)


func _ready() -> void:
	visible = false
	_build_ui()


func setup(player: CharacterBody3D, world_node: Node3D) -> void:
	player_ref = player
	world_ref = world_node


func _build_ui() -> void:
	var screen_sz := Vector2(1280.0, 720.0)

	panel = Panel.new()
	panel.name = "MapPanel"
	panel.size = Vector2(740.0, 620.0)
	panel.position = (screen_sz - panel.size) * 0.5

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.14, 0.96)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.85, 0.70, 0.25)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	# Titre
	var title := Label.new()
	title.text = "🗺️ CARTE DU MONDE - VOXELANDS"
	title.position = Vector2(24.0, 16.0)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	panel.add_child(title)

	var close_hint := Label.new()
	close_hint.text = "[M] ou [Echap] Fermer"
	close_hint.position = Vector2(580.0, 16.0)
	close_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	panel.add_child(close_hint)

	# Affichage de la carte
	map_texture_rect = TextureRect.new()
	map_texture_rect.name = "MapTexture"
	map_texture_rect.size = Vector2(500.0, 500.0)
	map_texture_rect.position = Vector2(24.0, 52.0)
	map_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	panel.add_child(map_texture_rect)

	# Cadre fin autour de la carte
	var map_border := Panel.new()
	map_border.size = Vector2(504.0, 504.0)
	map_border.position = Vector2(22.0, 50.0)
	map_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b_sb := StyleBoxFlat.new()
	b_sb.draw_center = false
	b_sb.border_width_left = 2
	b_sb.border_width_top = 2
	b_sb.border_width_right = 2
	b_sb.border_width_bottom = 2
	b_sb.border_color = Color(0.4, 0.45, 0.55)
	map_border.add_theme_stylebox_override("panel", b_sb)
	panel.add_child(map_border)

	# Calque des marqueurs
	markers_overlay = Control.new()
	markers_overlay.name = "MarkersOverlay"
	markers_overlay.size = Vector2(500.0, 500.0)
	markers_overlay.position = Vector2(24.0, 52.0)
	panel.add_child(markers_overlay)

	# Coordonnées du joueur
	coords_label = Label.new()
	coords_label.position = Vector2(540.0, 60.0)
	coords_label.size = Vector2(180.0, 120.0)
	coords_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coords_label.text = "Position :\nX: 0\nZ: 0\nBiome : Inconnu"
	coords_label.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
	panel.add_child(coords_label)

	# Légende des biomes sur le panneau latéral
	var legend_vbox := VBoxContainer.new()
	legend_vbox.position = Vector2(540.0, 200.0)
	legend_vbox.size = Vector2(180.0, 220.0)
	legend_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(legend_vbox)

	var leg_title := Label.new()
	leg_title.text = "Légende des Biomes :"
	leg_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	legend_vbox.add_child(leg_title)

	var biomes_info: Array[Dictionary] = [
		{"name": "Prairie", "color": Color(0.40, 0.75, 0.25)},
		{"name": "Forêt", "color": Color(0.18, 0.52, 0.16)},
		{"name": "Désert", "color": Color(0.85, 0.72, 0.40)},
		{"name": "Neige", "color": Color(0.92, 0.95, 0.98)},
		{"name": "Montagne", "color": Color(0.50, 0.52, 0.56)},
		{"name": "Océan / Plage", "color": Color(0.20, 0.48, 0.85)}
	]

	for b_entry in biomes_info:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var patch := ColorRect.new()
		patch.custom_minimum_size = Vector2(14.0, 14.0)
		patch.color = b_entry["color"]
		row.add_child(patch)
		var b_lbl := Label.new()
		b_lbl.text = b_entry["name"]
		row.add_child(b_lbl)
		legend_vbox.add_child(row)

	# Instructions
	var hint := Label.new()
	hint.position = Vector2(24.0, 565.0)
	hint.text = "💡 Les icônes 🏠 indiquent les Villages et 💀 les Donjons souterrains découverts."
	hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	panel.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			toggle_map()
		elif event.keycode == KEY_ESCAPE and is_open:
			close_map()


func toggle_map() -> void:
	if is_open:
		close_map()
	else:
		open_map()


func open_map() -> void:
	is_open = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_map()


func close_map() -> void:
	is_open = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if player_ref != null and player_ref.has_method("_capture_mouse"):
		player_ref._capture_mouse()


func _process(_delta: float) -> void:
	if is_open and player_ref != null:
		_update_player_marker()


func _refresh_map() -> void:
	if player_ref == null:
		return

	var p_pos: Vector3 = player_ref.global_position
	var cur_center := Vector2(p_pos.x, p_pos.z)

	# Re-génération de l'image si déplacé de plus de 40 blocs
	if last_rendered_center.distance_to(cur_center) > 40.0 or map_texture == null:
		last_rendered_center = cur_center
		_render_map_image(cur_center)

	_update_markers(cur_center)

	# Mise à jour des coordonnées textuelles
	if coords_label != null:
		var p_x: int = int(round(p_pos.x))
		var p_z: int = int(round(p_pos.z))
		var b_name: String = _get_current_biome_name(p_x, p_z)
		coords_label.text = "Coordonnées :\nX: %d\nZ: %d\nAltitude: %dm\n\nBiome Actuel :\n%s" % [
			p_x, p_z, int(p_pos.y), b_name
		]


func _render_map_image(center: Vector2) -> void:
	map_image = Image.create(MAP_PIXELS, MAP_PIXELS, false, Image.FORMAT_RGBA8)

	var t_noise: FastNoiseLite = world_ref.terrain_noise if (world_ref != null and "terrain_noise" in world_ref) else null
	var temp_noise: FastNoiseLite = world_ref.temperature_noise if (world_ref != null and "temperature_noise" in world_ref) else null
	var hum_noise: FastNoiseLite = world_ref.humidity_noise if (world_ref != null and "humidity_noise" in world_ref) else null

	if t_noise == null:
		return

	var half_pix: float = float(MAP_PIXELS) * 0.5

	for py in range(MAP_PIXELS):
		for px in range(MAP_PIXELS):
			var wx_m: float = center.x + (float(px) - half_pix) * MAP_SCALE_BLOCKS
			var wz_m: float = center.y + (float(py) - half_pix) * MAP_SCALE_BLOCKS
			var bpos := VoxelConstants.world_to_block_2d(wx_m, wz_m)

			var h: int = Chunk.get_height_at(t_noise, bpos.x, bpos.y)
			var temp: float = temp_noise.get_noise_2d(wx_m, wz_m)
			var hum: float = hum_noise.get_noise_2d(wx_m, wz_m)
			var biome: int = Chunk.get_biome_at(temp, hum, h)

			var col: Color = _get_color_for_biome(biome, h)
			map_image.set_pixel(px, py, col)

	map_texture = ImageTexture.create_from_image(map_image)
	map_texture_rect.texture = map_texture


func _get_color_for_biome(biome: int, height: int) -> Color:
	var h_m: float = float(height) * VoxelConstants.VOXEL_SIZE
	if h_m <= VoxelConstants.SEA_LEVEL_METERS:
		return Color(0.20, 0.45, 0.85) # Océan
	if h_m <= VoxelConstants.SEA_LEVEL_METERS + 2.0:
		return Color(0.88, 0.80, 0.52) # Plage

	match biome:
		BlockTypes.Biome.DESERT:
			return Color(0.85, 0.72, 0.40)
		BlockTypes.Biome.SNOW:
			return Color(0.92, 0.95, 0.98)
		BlockTypes.Biome.MOUNTAIN:
			return Color(0.50, 0.52, 0.56)
		BlockTypes.Biome.FOREST:
			return Color(0.18, 0.52, 0.16)
		_:
			return Color(0.40, 0.75, 0.25) # Prairie


func _get_current_biome_name(wx: int, wz: int) -> String:
	if world_ref == null:
		return "Inconnu"
	var t_noise: FastNoiseLite = world_ref.terrain_noise
	var temp_noise: FastNoiseLite = world_ref.temperature_noise
	var hum_noise: FastNoiseLite = world_ref.humidity_noise

	var bpos := VoxelConstants.world_to_block_2d(float(wx), float(wz))
	var h: int = Chunk.get_height_at(t_noise, bpos.x, bpos.y)
	var temp: float = temp_noise.get_noise_2d(float(wx), float(wz))
	var hum: float = hum_noise.get_noise_2d(float(wx), float(wz))
	var biome: int = Chunk.get_biome_at(temp, hum, h)

	match biome:
		BlockTypes.Biome.OCEAN: return "Océan"
		BlockTypes.Biome.BEACH: return "Plage"
		BlockTypes.Biome.DESERT: return "Désert"
		BlockTypes.Biome.FOREST: return "Forêt"
		BlockTypes.Biome.SNOW: return "Toundra Enneigée"
		BlockTypes.Biome.MOUNTAIN: return "Montagnes"
		_: return "Prairies"


func _update_markers(center: Vector2) -> void:
	for child in markers_overlay.get_children():
		child.queue_free()

	var half_pix: float = float(MAP_PIXELS) * 0.5
	var map_display_sz: float = 500.0

	# 1. Marqueurs de Villages aux alentours
	var v_gen = world_ref.get_node_or_null("VillageGenerator") if world_ref != null else null
	if v_gen != null and v_gen.has_method("get_village_info_for_region"):
		var rx_c: int = int(floor(center.x / float(v_gen.REGION_SIZE)))
		var rz_c: int = int(floor(center.y / float(v_gen.REGION_SIZE)))
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var v_info: Dictionary = v_gen.get_village_info_for_region(rx_c + dx, rz_c + dz)
				if not v_info.is_empty():
					var v_pos: Vector3 = v_info["position"]
					var m_pos: Vector2 = _world_to_map_screen(Vector2(v_pos.x, v_pos.z), center, half_pix, map_display_sz)
					if m_pos.x >= 0 and m_pos.x <= map_display_sz and m_pos.y >= 0 and m_pos.y <= map_display_sz:
						var v_lbl := Label.new()
						v_lbl.text = "🏠 %s" % v_info["name"]
						v_lbl.position = m_pos - Vector2(16.0, 16.0)
						v_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.35))
						markers_overlay.add_child(v_lbl)

	# 2. Marqueurs de Donjons aux alentours
	var d_gen = world_ref.get_node_or_null("DungeonGenerator") if world_ref != null else null
	if d_gen != null and d_gen.has_method("get_dungeon_info_for_region"):
		var drx_c: int = int(floor(center.x / float(d_gen.DUNGEON_REGION_SIZE)))
		var drz_c: int = int(floor(center.y / float(d_gen.DUNGEON_REGION_SIZE)))
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var d_info: Dictionary = d_gen.get_dungeon_info_for_region(drx_c + dx, drz_c + dz)
				if not d_info.is_empty():
					var d_pos: Vector3 = d_info["surface_position"]
					var m_pos: Vector2 = _world_to_map_screen(Vector2(d_pos.x, d_pos.z), center, half_pix, map_display_sz)
					if m_pos.x >= 0 and m_pos.x <= map_display_sz and m_pos.y >= 0 and m_pos.y <= map_display_sz:
						var d_lbl := Label.new()
						d_lbl.text = "💀 %s" % d_info["name"]
						d_lbl.position = m_pos - Vector2(16.0, 16.0)
						d_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
						markers_overlay.add_child(d_lbl)

	# 3. Marqueur Compagnon
	var companions: Array[Node] = get_tree().get_nodes_in_group("companions")
	for c in companions:
		if c is CharacterBody3D and is_instance_valid(c):
			var c_p: Vector3 = c.global_position
			var cm_pos: Vector2 = _world_to_map_screen(Vector2(c_p.x, c_p.z), center, half_pix, map_display_sz)
			if cm_pos.x >= 0 and cm_pos.x <= map_display_sz and cm_pos.y >= 0 and cm_pos.y <= map_display_sz:
				var c_lbl := Label.new()
				c_lbl.text = "🐾"
				c_lbl.position = cm_pos - Vector2(8.0, 8.0)
				c_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 0.95))
				markers_overlay.add_child(c_lbl)

	_update_player_marker()


func _update_player_marker() -> void:
	var p_marker: Label = markers_overlay.get_node_or_null("PlayerMarker") as Label
	if p_marker == null:
		p_marker = Label.new()
		p_marker.name = "PlayerMarker"
		p_marker.text = "▲"
		p_marker.add_theme_color_override("font_color", Color(1.0, 0.20, 0.20))
		markers_overlay.add_child(p_marker)

	# Le joueur est centré sur la carte
	p_marker.position = Vector2(244.0, 240.0)
	if player_ref != null:
		p_marker.rotation = -player_ref.cam_yaw


func _world_to_map_screen(world_xz: Vector2, center: Vector2, half_pix: float, display_sz: float) -> Vector2:
	var offset: Vector2 = world_xz - center
	var pix_x: float = half_pix + (offset.x / MAP_SCALE_BLOCKS)
	var pix_y: float = half_pix + (offset.y / MAP_SCALE_BLOCKS)
	var scr_x: float = (pix_x / float(MAP_PIXELS)) * display_sz
	var scr_y: float = (pix_y / float(MAP_PIXELS)) * display_sz
	return Vector2(scr_x, scr_y)
