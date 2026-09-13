extends Node3D
class_name AudioSystem

@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer

func _ready() -> void:
	add_to_group("audio_system")
	call_deferred("_connect_sound_system")

func _connect_sound_system() -> void:
	var sound_system := get_tree().get_first_node_in_group("sound_system") as SoundSystem
	if sound_system == null:
		push_error("AudioSystem: SoundSystem não encontrado.")
		return

	if not sound_system.sound_emitted.is_connected(_on_sound_emitted):
		sound_system.sound_emitted.connect(_on_sound_emitted)

func _on_sound_emitted(sound: SoundSystem.SoundEvent) -> void:
	if sound == null:
		return

	var source_name := "Unknown"
	if sound.source != null:
		source_name = sound.source.name

	print(
		"AudioSystem: som emitido | origem=%s | categoria=%s | fonte=%s"
		% [
			str(sound.origin),
			SoundSystem.SoundCategory.keys()[sound.category],
			source_name
		]
	)

	if audio_player != null and audio_player.stream != null:
		audio_player.global_position = sound.origin
		audio_player.play()
