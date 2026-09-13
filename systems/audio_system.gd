extends Node3D
class_name AudioSystem

@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer

func _ready() -> void:
	add_to_group("audio_system")
	call_deferred("_connect_perception_system")

func _connect_perception_system() -> void:
	var perception_system := get_tree().get_first_node_in_group("perception_system") as PerceptionSystem
	if perception_system == null:
		push_error("AudioSystem: PerceptionSystem não encontrado.")
		return

	if not perception_system.sound_perceived.is_connected(_on_sound_perceived):
		perception_system.sound_perceived.connect(_on_sound_perceived)

func _on_sound_perceived(listener: CharacterEntity, sound: SoundSystem.SoundEvent) -> void:
	if listener == null or sound == null:
		return

	var source_name := "Unknown"
	if sound.source != null:
		source_name = sound.source.name

	print(
		"AudioSystem: som percebido por %s | origem=%s | categoria=%s"
		% [
			listener.name,
			source_name,
			SoundSystem.SoundCategory.keys()[sound.category]
		]
	)

	if audio_player != null and audio_player.stream != null:
		audio_player.global_position = sound.origin
		audio_player.play()
