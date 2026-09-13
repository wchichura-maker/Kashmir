extends Node3D
class_name SoundSystem

enum SoundVolume {
	WHISPER,
	NORMAL,
	SHOUT
}

const WHISPER_RANGE_FEET: int = 15
const NORMAL_RANGE_FEET: int = 60
const SHOUT_RANGE_FEET: int = 120

enum SoundCategory {
	SPEECH,
	FOOTSTEP,
	EQUIPMENT,
	DOOR,
	WEAPON,
	MAGIC,
	IMPACT,
	ENVIRONMENT
}

enum SoundDetectionMode {
	FIXED_DC,
	OPPOSED_STEALTH
}

enum SoundComponent {
	FOOTSTEP,
	EQUIPMENT,
	SURFACE,
	MOVEMENT,
	OTHER
}

class SoundProfile:
	var base_dc: int = 0
	var volume: SoundVolume = SoundVolume.NORMAL
	var components: Array[SoundComponent] = []

	func _init(
		initial_base_dc: int = 0,
		initial_volume: SoundVolume = SoundVolume.NORMAL
	) -> void:
		base_dc = initial_base_dc
		volume = initial_volume

	func add_component(component: SoundComponent) -> void:
		if not components.has(component):
			components.append(component)

class SoundEvent:
	var source: Node3D
	var origin: Vector3
	var category: SoundCategory
	var profile: SoundProfile
	var detection_mode: SoundDetectionMode = SoundDetectionMode.FIXED_DC
	var message: String
	var heard_by: Array[CharacterEntity] = []
	
	func _init(
		initial_source: Node3D = null,
		initial_origin: Vector3 = Vector3.ZERO,
		initial_volume: SoundVolume = SoundVolume.NORMAL,
		initial_category: SoundCategory = SoundCategory.ENVIRONMENT,
		initial_base_dc: int = 0,
		
		initial_message: String = ""
	) -> void:
		source = initial_source
		origin = initial_origin
		category = initial_category
		profile = SoundProfile.new(initial_base_dc, initial_volume)
		message = initial_message
	
signal sound_emitted(sound: SoundEvent)

var active_sounds: Array[SoundEvent] = []

func get_sound_range_feet(volume: SoundVolume) -> int:
	match volume:
		SoundVolume.WHISPER:
			return WHISPER_RANGE_FEET
		SoundVolume.NORMAL:
			return NORMAL_RANGE_FEET
		SoundVolume.SHOUT:
			return SHOUT_RANGE_FEET

	return 0


func can_reach_listener(
	sound: SoundEvent,
	listener: CharacterEntity
) -> bool:
	if sound == null or listener == null:
		return false

	var distance := sound.origin.distance_to(listener.global_position)
	var distance_feet := roundi(distance / 1.524 * 5.0)

	return distance_feet <= get_sound_range_feet(sound.volume)

func process_sound(sound: SoundEvent) -> void:
	if sound == null:
		return

	var characters := get_tree().get_nodes_in_group("combatants")

	for character_node in characters:
		var listener := character_node as CharacterEntity

		if listener == null:
			continue

		if not listener.is_alive:
			continue

		if listener == sound.source:
			continue

		if can_reach_listener(sound, listener):
			var source_name := "Unknown"

			if sound.source != null:
				source_name = sound.source.name

			print(
				"Sound Event: %s pode alcançar %s | volume=%s | categoria=%s"
				% [
					source_name,
					listener.name,
					SoundVolume.keys()[sound.volume],
					SoundCategory.keys()[sound.category]
				]
			)

func emit_sound(
	source: Node3D,
	volume: SoundVolume = SoundVolume.NORMAL,
	category: SoundCategory = SoundCategory.ENVIRONMENT,
	message: String = ""
) -> SoundEvent:
	var origin := Vector3.ZERO

	if source != null:
		origin = source.global_position

	var base_dc := get_default_sound_dc(category, volume)

	var sound := SoundEvent.new(
		source,
		origin,
		volume,
		category,
		base_dc,
		message
	)
	if category == SoundCategory.FOOTSTEP:
		sound.profile.add_component(SoundComponent.FOOTSTEP)
	elif category == SoundCategory.EQUIPMENT:
		sound.profile.add_component(SoundComponent.EQUIPMENT)
	elif category == SoundCategory.SPEECH:
		sound.profile.add_component(SoundComponent.OTHER)
	else:
		sound.profile.add_component(SoundComponent.OTHER)
		
	active_sounds.append(sound)
	sound_emitted.emit(sound)
	return sound

func get_default_sound_dc(category: SoundCategory, volume: SoundVolume) -> int:
	match category:
		SoundCategory.FOOTSTEP:
			return 10

		SoundCategory.SPEECH:
			match volume:
				SoundVolume.WHISPER:
					return 15
				SoundVolume.NORMAL:
					return 0
				SoundVolume.SHOUT:
					return -10

		SoundCategory.EQUIPMENT:
			return 5

		_:
			return 0

	return 0

func create_movement_sound_profile(
	character: CharacterEntity
) -> SoundProfile:
	var profile := SoundProfile.new(
		10,
		SoundVolume.NORMAL
	)

	profile.add_component(SoundComponent.FOOTSTEP)

	if character != null and character.equipment_sound_enabled:
		if character.equipment_sound_level != "Silent":
			profile.add_component(SoundComponent.EQUIPMENT)

	return profile

func create_sound_event_from_profile(
	source: Node3D,
	category: SoundCategory,
	profile: SoundProfile,
	message: String = ""
) -> SoundEvent:
	if profile == null:
		return null

	var origin := Vector3.ZERO

	if source != null:
		origin = source.global_position

	var sound := SoundEvent.new(
		source,
		origin,
		profile.volume,
		category,
		profile.base_dc,
		message
	)

	sound.profile = profile

	active_sounds.append(sound)
	sound_emitted.emit(sound)

	return sound

func emit_equipment_sound(
	source: Node3D,
	volume: SoundVolume = SoundVolume.NORMAL,
	message: String = "Equipamento",
	base_dc: int = 5
) -> SoundEvent:
	var origin := Vector3.ZERO

	if source != null:
		origin = source.global_position

	var sound := SoundEvent.new(
		source,
		origin,
		volume,
		SoundCategory.EQUIPMENT,
		base_dc,
		message
	)

	active_sounds.append(sound)
	sound_emitted.emit(sound)

	return sound

func emit_equipment_sound_from_character(
	character: CharacterEntity,
	message: String = "Equipamento"
) -> SoundEvent:
	if character == null:
		return null

	var volume := SoundVolume.NORMAL

	match character.equipment_sound_level:
		"Silent":
			return null
		"Light":
			volume = SoundVolume.WHISPER
		"Normal":
			volume = SoundVolume.NORMAL
		"Heavy":
			volume = SoundVolume.NORMAL

	return emit_equipment_sound(
		character,
		volume,
		message,
		character.equipment_sound_dc
	)

func was_heard_by(
	sound: SoundEvent,
	character: CharacterEntity
) -> bool:
	if sound == null or character == null:
		return false

	return sound.heard_by.has(character)

func _ready() -> void:
	add_to_group("sound_system")


func clear_sounds() -> void:
	active_sounds.clear()
