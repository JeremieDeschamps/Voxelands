class_name DayNightCycle
extends Node

## Gestionnaire de cycle jour / nuit avec rotation solaire, ciel procédural dynamique et adaptation du brouillard.

@export var day_duration_seconds: float = 360.0 # 6 minutes par cycle complet
@export_range(0.0, 1.0) var time_of_day: float = 0.35 # Démarre le matin (8h24)

@export var sun_light: DirectionalLight3D = null
@export var world_environment: WorldEnvironment = null

var sky_material: ProceduralSkyMaterial = null
var env: Environment = null


func _ready() -> void:
	if sun_light == null:
		sun_light = get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D

	if world_environment == null:
		world_environment = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment

	if world_environment != null and world_environment.environment != null:
		env = world_environment.environment
		if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
			sky_material = env.sky.sky_material as ProceduralSkyMaterial

	_update_lighting(0.0)


func _process(delta: float) -> void:
	time_of_day += delta / maxf(day_duration_seconds, 10.0)
	if time_of_day >= 1.0:
		time_of_day -= 1.0

	_update_lighting(delta)


func _update_lighting(_delta: float) -> void:
	# 1. Orientation du soleil (rotation pitch selon l'heure)
	var sun_angle_rad: float = (time_of_day - 0.25) * TAU

	if sun_light != null:
		sun_light.rotation = Vector3(-sun_angle_rad, deg_to_rad(-35.0), 0.0)

	# 2. Facteur de luminosité solaire (1.0 = plein midi, 0.0 = nuit noire)
	var sun_height: float = sin((time_of_day - 0.25) * TAU)
	var day_factor: float = clampf((sun_height + 0.15) / 0.85, 0.0, 1.0)

	# 3. Couleurs et intensité du soleil
	if sun_light != null:
		if day_factor > 0.05:
			# Jour / Aube / Crépuscule
			var noon_color := Color(1.0, 0.98, 0.92)
			var dawn_color := Color(1.0, 0.65, 0.35)
			var sunset_factor: float = 1.0 - clampf(absf(sun_height) * 2.2, 0.0, 1.0)
			sun_light.light_color = noon_color.lerp(dawn_color, sunset_factor)
			sun_light.light_energy = lerp(0.3, 1.15, day_factor)
			sun_light.shadow_enabled = true
		else:
			# Nuit (Lumière de lune argentée)
			sun_light.light_color = Color(0.40, 0.50, 0.75)
			sun_light.light_energy = 0.22
			sun_light.shadow_enabled = false

	# 4. Dégradés du ciel procédural
	if sky_material != null:
		var day_top := Color(0.35, 0.65, 0.95)
		var day_horizon := Color(0.68, 0.82, 0.95)
		var night_top := Color(0.03, 0.04, 0.10)
		var night_horizon := Color(0.08, 0.12, 0.22)
		var sunset_horizon := Color(0.85, 0.42, 0.25)

		var horizon_sunset_blend: float = clampf(1.0 - absf(sun_height) * 3.0, 0.0, 1.0)
		var cur_horizon: Color = day_horizon.lerp(night_horizon, 1.0 - day_factor)
		cur_horizon = cur_horizon.lerp(sunset_horizon, horizon_sunset_blend * day_factor)

		sky_material.sky_top_color = night_top.lerp(day_top, day_factor)
		sky_material.sky_horizon_color = cur_horizon
		sky_material.ground_bottom_color = Color(0.12, 0.10, 0.08).lerp(Color(0.20, 0.18, 0.15), day_factor)
		sky_material.ground_horizon_color = cur_horizon

	# 5. Brouillard volumétrique adapté
	if env != null and env.fog_enabled:
		var day_fog := Color(0.68, 0.82, 0.95)
		var night_fog := Color(0.06, 0.08, 0.15)
		env.fog_light_color = night_fog.lerp(day_fog, day_factor)
