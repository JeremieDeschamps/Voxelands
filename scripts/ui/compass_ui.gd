class_name CompassUI
extends Control

## Boussole horizontale affichée en haut de l'écran avec points cardinaux et marqueurs d'objectifs (Villages, Donjons, Compagnon).

var compass_panel: Panel = null
var center_arrow: Label = null
var tape_control: Control = null
var markers_control: Control = null

var camera_yaw: float = 0.0
var village_pos: Vector3 = Vector3.ZERO
var village_name: String = ""
var dungeon_pos: Vector3 = Vector3.ZERO
var dungeon_name: String = ""
var pet_pos: Vector3 = Vector3.ZERO
var player_pos: Vector3 = Vector3.ZERO

const COMPASS_WIDTH: float = 380.0
const COMPASS_HEIGHT: float = 34.0
const PIXELS_PER_DEGREE: float = 2.4 # Étalement angulaire sur la boussole


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = Vector2(COMPASS_WIDTH, COMPASS_HEIGHT)
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	position = Vector2((1280.0 - COMPASS_WIDTH) * 0.5, 12.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Cadre de fond
	compass_panel = Panel.new()
	compass_panel.size = Vector2(COMPASS_WIDTH, COMPASS_HEIGHT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.14, 0.85)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.35, 0.45, 0.60)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	compass_panel.add_theme_stylebox_override("panel", sb)
	add_child(compass_panel)

	# Conteneur découpé pour le ruban
	tape_control = Control.new()
	tape_control.size = Vector2(COMPASS_WIDTH, COMPASS_HEIGHT)
	tape_control.clip_contents = true
	compass_panel.add_child(tape_control)

	# Flèche indicatrice centrale
	center_arrow = Label.new()
	center_arrow.text = "▼"
	center_arrow.position = Vector2(COMPASS_WIDTH * 0.5 - 6.0, -4.0)
	center_arrow.add_theme_color_override("font_color", Color(0.95, 0.82, 0.22))
	add_child(center_arrow)

	# Conteneur des marqueurs
	markers_control = Control.new()
	markers_control.size = Vector2(COMPASS_WIDTH, COMPASS_HEIGHT)
	tape_control.add_child(markers_control)


func update_data(p_pos: Vector3, cam_yaw_rad: float, v_pos: Vector3, v_name: String, d_pos: Vector3, d_name: String, c_pos: Vector3) -> void:
	player_pos = p_pos
	camera_yaw = cam_yaw_rad
	village_pos = v_pos
	village_name = v_name
	dungeon_pos = d_pos
	dungeon_name = d_name
	pet_pos = c_pos

	_redraw_compass()


func _redraw_compass() -> void:
	for child in markers_control.get_children():
		child.queue_free()

	# Orientation en degrés (0 à 360)
	var player_deg: float = wrapf(rad_to_deg(camera_yaw), 0.0, 360.0)
	var center_x: float = COMPASS_WIDTH * 0.5

	# Points cardinaux
	var points: Array[Dictionary] = [
		{"text": "N", "deg": 0.0, "color": Color(0.95, 0.35, 0.35)},
		{"text": "NE", "deg": 45.0, "color": Color(0.7, 0.7, 0.75)},
		{"text": "E", "deg": 90.0, "color": Color(0.85, 0.85, 0.9)},
		{"text": "SE", "deg": 135.0, "color": Color(0.7, 0.7, 0.75)},
		{"text": "S", "deg": 180.0, "color": Color(0.85, 0.85, 0.9)},
		{"text": "SW", "deg": 225.0, "color": Color(0.7, 0.7, 0.75)},
		{"text": "W", "deg": 270.0, "color": Color(0.85, 0.85, 0.9)},
		{"text": "NW", "deg": 315.0, "color": Color(0.7, 0.7, 0.75)}
	]

	for pt in points:
		var diff: float = _angle_diff_deg(pt["deg"], player_deg)
		var x: float = center_x + (diff * PIXELS_PER_DEGREE)
		if x >= 10.0 and x <= COMPASS_WIDTH - 25.0:
			var lbl := Label.new()
			lbl.text = pt["text"]
			lbl.position = Vector2(x - 10.0, 6.0)
			lbl.add_theme_color_override("font_color", pt["color"])
			markers_control.add_child(lbl)

	# Marqueur Village
	if village_pos != Vector3.ZERO:
		var dist_v: float = player_pos.distance_to(village_pos)
		var deg_v: float = _bearing_deg(player_pos, village_pos)
		var diff_v: float = _angle_diff_deg(deg_v, player_deg)
		var xv: float = center_x + (diff_v * PIXELS_PER_DEGREE)
		if xv >= 12.0 and xv <= COMPASS_WIDTH - 28.0:
			var v_lbl := Label.new()
			v_lbl.text = "🏠%dm" % int(dist_v)
			v_lbl.position = Vector2(xv - 16.0, 6.0)
			v_lbl.add_theme_color_override("font_color", Color(0.35, 0.90, 0.50))
			markers_control.add_child(v_lbl)

	# Marqueur Donjon
	if dungeon_pos != Vector3.ZERO:
		var dist_d: float = player_pos.distance_to(dungeon_pos)
		var deg_d: float = _bearing_deg(player_pos, dungeon_pos)
		var diff_d: float = _angle_diff_deg(deg_d, player_deg)
		var xd: float = center_x + (diff_d * PIXELS_PER_DEGREE)
		if xd >= 12.0 and xd <= COMPASS_WIDTH - 28.0:
			var d_lbl := Label.new()
			d_lbl.text = "💀%dm" % int(dist_d)
			d_lbl.position = Vector2(xd - 16.0, 6.0)
			d_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
			markers_control.add_child(d_lbl)

	# Marqueur Compagnon
	if pet_pos != Vector3.ZERO:
		var deg_c: float = _bearing_deg(player_pos, pet_pos)
		var diff_c: float = _angle_diff_deg(deg_c, player_deg)
		var xc: float = center_x + (diff_c * PIXELS_PER_DEGREE)
		if xc >= 12.0 and xc <= COMPASS_WIDTH - 28.0:
			var c_lbl := Label.new()
			c_lbl.text = "🐾"
			c_lbl.position = Vector2(xc - 8.0, 6.0)
			c_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 0.95))
			markers_control.add_child(c_lbl)


func _bearing_deg(from_p: Vector3, to_p: Vector3) -> float:
	var delta: Vector3 = to_p - from_p
	# L'angle polaire où le Nord est l'axe -Z (ou +Z selon convenance Godot)
	# Dans Godot : -Z est l'avant, +X est la droite
	var rad: float = atan2(delta.x, -delta.z)
	return wrapf(rad_to_deg(rad), 0.0, 360.0)


func _angle_diff_deg(target: float, source: float) -> float:
	var d: float = wrapf(target - source, -180.0, 180.0)
	return d
