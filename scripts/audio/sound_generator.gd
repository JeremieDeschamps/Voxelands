class_name SoundGenerator
extends Node

## Synthétiseur audio procédural 100% en code via AudioStreamGenerator (zéro asset externe).
## Génère en temps réel : bruits de pas, sauts, coups d'épée, magie, impacts, coffres, level up et musique d'ambiance.

const MIX_RATE: float = 22050.0

var sfx_player: AudioStreamPlayer = null
var sfx_playback: AudioStreamGeneratorPlayback = null

var music_player: AudioStreamPlayer = null
var music_playback: AudioStreamGeneratorPlayback = null

var master_volume: float = 0.8
var music_timer: float = 0.0
var music_chord_idx: int = 0

# Accords d'ambiance RPG (fréquences en Hz : Do, Sol, La mineur, Fa...)
const AMBIENT_CHORDS: Array[Array] = [
	[261.63, 329.63, 392.00], # Do Maj (C-E-G)
	[196.00, 246.94, 293.66], # Sol Maj (G-B-D)
	[220.00, 261.63, 329.63], # La min (A-C-E)
	[174.61, 220.00, 261.63]  # Fa Maj (F-A-C)
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_sfx_channel()
	_setup_music_channel()


func _setup_sfx_channel() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.2
	sfx_player.stream = gen
	add_child(sfx_player)
	sfx_player.play()
	sfx_playback = sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _setup_music_channel() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.4
	music_player.stream = gen
	add_child(music_player)
	music_player.play()
	music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	# Génération continue de la musique d'ambiance procédurale
	_update_ambient_music(delta)


func set_volume(vol: float) -> void:
	master_volume = clampf(vol, 0.0, 1.0)
	if sfx_player != null:
		sfx_player.volume_db = linear_to_db(maxf(master_volume, 0.0001))
	if music_player != null:
		music_player.volume_db = linear_to_db(maxf(master_volume * 0.45, 0.0001))


## Pousse un buffer stéréo dans le canal SFX
func _push_sfx_buffer(frames: PackedVector2Array) -> void:
	if sfx_playback == null or master_volume <= 0.01:
		return
	var frames_to_push: int = mini(frames.size(), sfx_playback.get_frames_available())
	for i in range(frames_to_push):
		sfx_playback.push_frame(frames[i] * master_volume)


## 1. Bruit de pas (léger souffle de terre/pierre)
func play_footstep() -> void:
	var count: int = int(MIX_RATE * 0.06)
	var frames := PackedVector2Array()
	frames.resize(count)

	for i in range(count):
		var env: float = 1.0 - (float(i) / float(count))
		var noise: float = randf_range(-1.0, 1.0) * 0.18
		var sample: float = noise * env * env
		frames[i] = Vector2(sample, sample)

	_push_sfx_buffer(frames)


## 2. Saut (glissando ascendant rapide)
func play_jump() -> void:
	var count: int = int(MIX_RATE * 0.14)
	var frames := PackedVector2Array()
	frames.resize(count)

	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var freq: float = lerp(160.0, 380.0, t)
		var env: float = 1.0 - t
		phase += (TAU * freq) / MIX_RATE
		var sample: float = sin(phase) * env * 0.28
		frames[i] = Vector2(sample, sample)

	_push_sfx_buffer(frames)


## 3. Atterrissage (impact sourd)
func play_land() -> void:
	var count: int = int(MIX_RATE * 0.12)
	var frames := PackedVector2Array()
	frames.resize(count)

	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var freq: float = lerp(120.0, 45.0, t)
		var env: float = (1.0 - t) * (1.0 - t)
		phase += (TAU * freq) / MIX_RATE
		var sample: float = (sin(phase) + randf_range(-0.1, 0.1)) * env * 0.35
		frames[i] = Vector2(sample, sample)

	_push_sfx_buffer(frames)


## 4. Coup d'arme / Attaque (swoosh tranchant ou explosion arcanique)
func play_attack(is_magic: bool = false) -> void:
	var dur: float = 0.18 if not is_magic else 0.24
	var count: int = int(MIX_RATE * dur)
	var frames := PackedVector2Array()
	frames.resize(count)

	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = sin(t * PI)
		var sample: float = 0.0

		if is_magic:
			var freq: float = lerp(550.0, 220.0, t)
			phase += (TAU * freq) / MIX_RATE
			sample = (sin(phase) + sin(phase * 1.5) * 0.5) * env * 0.32
		else:
			# Swoosh tranchant
			var noise: float = randf_range(-1.0, 1.0)
			var freq: float = lerp(800.0, 250.0, t)
			phase += (TAU * freq) / MIX_RATE
			sample = (noise * 0.6 + sin(phase) * 0.4) * env * 0.35

		frames[i] = Vector2(sample, sample)

	_push_sfx_buffer(frames)


## 5. Dégâts reçus / Impact
func play_hit() -> void:
	var count: int = int(MIX_RATE * 0.15)
	var frames := PackedVector2Array()
	frames.resize(count)

	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var freq: float = lerp(240.0, 70.0, t)
		var env: float = 1.0 - t
		phase += (TAU * freq) / MIX_RATE
		# Onde carrée douce
		var square: float = 1.0 if sin(phase) > 0.0 else -1.0
		var sample: float = square * env * 0.32
		frames[i] = Vector2(sample, sample)

	_push_sfx_buffer(frames)


## 6. Ouverture de Coffre au trésor (arpège montant cristallin)
func play_chest() -> void:
	var notes: Array[float] = [261.63, 329.63, 392.00, 523.25, 659.25]
	var note_dur: float = 0.08
	var count: int = int(MIX_RATE * note_dur * notes.size())
	var frames := PackedVector2Array()
	frames.resize(count)

	var sample_idx: int = 0
	for note in notes:
		var n_count: int = int(MIX_RATE * note_dur)
		var phase: float = 0.0
		for i in range(n_count):
			var t: float = float(i) / float(n_count)
			var env: float = 1.0 - (t * 0.6)
			phase += (TAU * note) / MIX_RATE
			var sample: float = sin(phase) * env * 0.28
			if sample_idx < count:
				frames[sample_idx] = Vector2(sample, sample)
				sample_idx += 1

	_push_sfx_buffer(frames)


## 7. Montée de niveau / Victoire (fanfare triomphante)
func play_level_up() -> void:
	var notes: Array[float] = [329.63, 392.00, 523.25, 659.25, 783.99]
	var note_dur: float = 0.1
	var count: int = int(MIX_RATE * note_dur * notes.size())
	var frames := PackedVector2Array()
	frames.resize(count)

	var sample_idx: int = 0
	for note in notes:
		var n_count: int = int(MIX_RATE * note_dur)
		var phase: float = 0.0
		for i in range(n_count):
			var t: float = float(i) / float(n_count)
			var env: float = 1.0 - t
			phase += (TAU * note) / MIX_RATE
			# Harmonies
			var s: float = (sin(phase) + sin(phase * 2.0) * 0.4) * env * 0.32
			if sample_idx < count:
				frames[sample_idx] = Vector2(s, s)
				sample_idx += 1

	_push_sfx_buffer(frames)


## 8. Apprivoisement d'un animal (gazouillis amical)
func play_tame() -> void:
	var count: int = int(MIX_RATE * 0.25)
	var frames := PackedVector2Array()
	frames.resize(count)

	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var freq: float = 440.0 + sin(t * TAU * 4.0) * 180.0
		var env: float = sin(t * PI)
		phase += (TAU * freq) / MIX_RATE
		var s: float = sin(phase) * env * 0.25
		frames[i] = Vector2(s, s)

	_push_sfx_buffer(frames)


## Musique d'ambiance procédurale en arrière-plan (Nappe d'accords doux)
func _update_ambient_music(delta: float) -> void:
	if music_playback == null or master_volume <= 0.01:
		return

	music_timer += delta
	# Changement d'accord toutes les 4.5 secondes
	if music_timer >= 4.5:
		music_timer = 0.0
		music_chord_idx = (music_chord_idx + 1) % AMBIENT_CHORDS.size()

	var avail: int = music_playback.get_frames_available()
	if avail < 128:
		return

	var chunk_size: int = mini(avail, 512)
	var chord: Array = AMBIENT_CHORDS[music_chord_idx]

	for i in range(chunk_size):
		var t_sec: float = music_timer + (float(i) / MIX_RATE)
		var chord_env: float = sin(clampf(t_sec / 4.5, 0.0, 1.0) * PI) * 0.12

		var s: float = 0.0
		for freq in chord:
			var ph: float = t_sec * TAU * float(freq)
			s += sin(ph) * 0.33

		var sample_val: float = s * chord_env * master_volume * 0.5
		music_playback.push_frame(Vector2(sample_val, sample_val))
