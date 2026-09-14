extends Node3D
class_name PerceptionSystem

signal perception_detected(source: CharacterEntity, target: CharacterEntity)
signal sound_perceived(listener: CharacterEntity, sound: SoundSystem.SoundEvent)

enum PerceptionState {
	UNKNOWN,
	SUSPECTED,
	DETECTED,
	AWARE
}

class SoundPerception:
	var state: PerceptionState = PerceptionState.UNKNOWN
	var last_sound_origin: Vector3 = Vector3.ZERO
	var last_sound_category: SoundSystem.SoundCategory = SoundSystem.SoundCategory.ENVIRONMENT
	var last_sound_time: int = 0

class PerceptionResult:
	var state: PerceptionState = PerceptionState.UNKNOWN
	var distance_feet: int = 0
	var visual_detected: bool = false
	var auditory_detected: bool = false

	func _init(
		initial_state: PerceptionState = PerceptionState.UNKNOWN,
		initial_distance_feet: int = 0
	) -> void:
		state = initial_state
		distance_feet = initial_distance_feet

class PerceptionActivity:
	var visual_activity: int = 0
	var auditory_activity: int = 0

	var visual_threshold: int = 3
	var auditory_threshold: int = 3

	func add_visual(amount: int = 1) -> void:
		visual_activity += amount

	func add_auditory(amount: int = 1) -> void:
		auditory_activity += amount

	func visual_threshold_reached() -> bool:
		return visual_activity >= visual_threshold

	func auditory_threshold_reached() -> bool:
		return auditory_activity >= auditory_threshold

	func reset_visual() -> void:
		visual_activity = 0

	func reset_auditory() -> void:
		auditory_activity = 0

@export_category("Perception")
@export var base_visual_range_feet: int = 120
@export var base_hearing_range_feet: int = 60

var perception_results: Dictionary = {}
var sound_perceptions: Dictionary = {}
var perception_activities: Dictionary = {}

@export_category("Hearing")
@export var default_sound_dc: int = 0

func _ready() -> void:
	add_to_group("perception_system")

	call_deferred("_connect_sound_system")
	call_deferred("_update_all_perceptions_deferred")

func _update_all_perceptions_deferred() -> void:
	await get_tree().physics_frame

	update_all_perceptions()
	
func _connect_sound_system() -> void:
	var sound_system := get_tree().get_first_node_in_group("sound_system") as SoundSystem

	if sound_system == null:
		push_error("PerceptionSystem: SoundSystem não encontrado.")
		return

	if not sound_system.sound_emitted.is_connected(_on_sound_emitted):
		sound_system.sound_emitted.connect(_on_sound_emitted)


func _on_sound_emitted(sound: SoundSystem.SoundEvent) -> void:
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

		if not can_hear_sound_by_distance(listener, sound):
			continue

		var activity := get_perception_activity(listener, sound.source)

		if activity == null:
			continue

		activity.add_auditory(1)

		if activity.auditory_threshold_reached():
			activity.reset_auditory()

			var heard := perform_listen_check(listener, sound)

			if heard:
				if not sound.heard_by.has(listener):
					sound.heard_by.append(listener)

				_register_sound_perception(listener, sound)

				if not is_aware_of(listener, sound.source):
					sound_perceived.emit(listener, sound)

func _register_sound_perception(
	listener: CharacterEntity,
	sound: SoundSystem.SoundEvent
) -> void:
	if listener == null or sound == null:
		return

	var listener_id := listener.get_instance_id()

	if not sound_perceptions.has(listener_id):
		sound_perceptions[listener_id] = {}

	var source_id := 0

	if sound.source != null:
		source_id = sound.source.get_instance_id()

	if source_id == 0:
		return

	var listener_sound_perceptions: Dictionary = sound_perceptions[listener_id]

	var perception := SoundPerception.new()
	perception.state = PerceptionState.SUSPECTED
	perception.last_sound_origin = sound.origin
	perception.last_sound_category = sound.category
	perception.last_sound_time = Time.get_ticks_msec()

	listener_sound_perceptions[source_id] = perception

func get_sound_perception(
	listener: CharacterEntity,
	source: CharacterEntity
) -> SoundPerception:
	if listener == null or source == null:
		return null

	var listener_id := listener.get_instance_id()
	var source_id := source.get_instance_id()

	if not perception_results.has(listener_id):
		return null

	var listener_sound_perceptions: Dictionary = sound_perceptions[listener_id]

	if not sound_perceptions.has(source_id):
		return null

	return listener_sound_perceptions[source_id] as SoundPerception

func get_distance_feet(
	source: CharacterEntity,
	target: CharacterEntity
) -> int:
	if source == null or target == null:
		return 0

	var distance := source.global_position.distance_to(
		target.global_position
	)

	return roundi(distance / 1.524 * 5.0)

func perform_visual_check(
	source: CharacterEntity,
	target: CharacterEntity
) -> bool:
	if source == null or target == null:
		return false

	var spot_roll := randi_range(1, 20)
	var spot_total := (
		spot_roll
		+ source.spot_modifier
		+ get_spot_distance_modifier(source, target)
	)

	var visual_dc := target.base_visual_dc

	print(
		"Spot Test: %s -> %s | d20=%d | total=%d | DC=%d"
		% [
			source.name,
			target.name,
			spot_roll,
			spot_total,
			visual_dc
		]
	)

	return spot_total >= visual_dc

func create_result(
	source: CharacterEntity,
	target: CharacterEntity
) -> PerceptionResult:
	var distance_feet := get_distance_feet(source, target)

	return PerceptionResult.new(
		PerceptionState.UNKNOWN,
		distance_feet
	)

func can_see(
	source: CharacterEntity,
	target: CharacterEntity
) -> bool:
	if source == null or target == null:
		return false

	var result := get_perception_result(source, target)

	if result == null:
		return false

	return result.visual_detected

func can_hear_by_distance(
	source: CharacterEntity,
	target: CharacterEntity
) -> bool:
	if source == null or target == null:
		return false

	var distance_feet := get_distance_feet(source, target)

	return distance_feet <= base_hearing_range_feet

func can_hear_sound_by_distance(
	listener: CharacterEntity,
	sound: SoundSystem.SoundEvent
) -> bool:
	if listener == null or sound == null:
		return false

	var distance_feet := roundi(
		listener.global_position.distance_to(sound.origin) / 1.524 * 5.0
	)

	var sound_system := get_tree().get_first_node_in_group("sound_system") as SoundSystem

	if sound_system == null:
		return false

	return distance_feet <= sound_system.get_sound_range_feet(sound.profile.volume)

func get_listen_distance_modifier(
	source: CharacterEntity,
	target: CharacterEntity
) -> int:
	if source == null or target == null:
		return 0

	var distance_feet := get_distance_feet(source, target)

	return -floori(float(distance_feet) / 10.0)

func get_listen_distance_modifier_from_distance(distance_feet: int) -> int:
	return -floori(float(distance_feet) / 10.0)

func get_hearing_dc(
	source: CharacterEntity,
	target: CharacterEntity
) -> int:
	if source == null or target == null:
		return 0

	return default_sound_dc + (-get_listen_distance_modifier(source, target))

func perform_listen_check(
	listener: CharacterEntity,
	sound: SoundSystem.SoundEvent
) -> bool:
	if listener == null or sound == null:
		return false

	var distance_feet := roundi(
	listener.global_position.distance_to(sound.origin) / 1.524 * 5.0
	)

	var distance_modifier := get_listen_distance_modifier_from_distance(
		distance_feet
	)

	var dc: int = sound.profile.base_dc + (-distance_modifier)


	var listen_roll := randi_range(1, 20)
	var listen_total: int = listen_roll + listener.listen_modifier
	print(
		"Listen Test: %s | d20=%d | modifier=%d | total=%d | DC=%d"
		% [
			listener.name,
			listen_roll,
			listener.listen_modifier,
			listen_total,
			dc
		]
	)

	return listen_total >= dc

func update_perception(
	source: CharacterEntity,
	target: CharacterEntity
) -> PerceptionResult:
	if source == null or target == null:
		return PerceptionResult.new()

	var source_id := source.get_instance_id()
	var target_id := target.get_instance_id()

	if not perception_results.has(source_id):
		perception_results[source_id] = {}

	var source_results: Dictionary = perception_results[source_id]

	if source_results.has(target_id):
		var existing_result := source_results[target_id] as PerceptionResult

		if existing_result != null:
			if existing_result.state == PerceptionState.AWARE:
				return existing_result

	var result := create_result(source, target)

	print(
		"Visual Debug: %s -> %s | distance=%d ft | in_range=%s | LOS=%s"
		% [
			source.name,
			target.name,
			get_distance_feet(source, target),
			str(can_perceive_by_distance(source, target)),
			str(has_line_of_sight(source, target))
		]
	)

	if can_perceive_by_distance(source, target):
		if has_line_of_sight(source, target):
			if perform_visual_check(source, target):
				result.state = PerceptionState.AWARE
				result.visual_detected = true
				perception_detected.emit(source, target)

	perception_results[source_id][target_id] = result

	return result

func get_perception_result(
	source: CharacterEntity,
	target: CharacterEntity
) -> PerceptionResult:
	if source == null or target == null:
		return null

	var source_id := source.get_instance_id()
	var target_id := target.get_instance_id()

	if not perception_results.has(source_id):
		return null

	var source_results: Dictionary = perception_results[source_id]

	if not source_results.has(target_id):
		return null

	return source_results[target_id] as PerceptionResult

func is_aware_of(
	source: CharacterEntity,
	target: CharacterEntity
) -> bool:
	if source == null or target == null:
		return false

	var result := get_perception_result(source, target)

	if result == null:
		return false

	return result.state == PerceptionState.AWARE

func get_perception_activity(
	source: CharacterEntity,
	target: CharacterEntity
) -> PerceptionActivity:
	if source == null or target == null:
		return null

	var source_id := source.get_instance_id()
	var target_id := target.get_instance_id()

	if not perception_activities.has(source_id):
		perception_activities[source_id] = {}

	var source_activities: Dictionary = perception_activities[source_id]

	if not source_activities.has(target_id):
		source_activities[target_id] = PerceptionActivity.new()

	return source_activities[target_id] as PerceptionActivity

func add_visual_activity(
	source: CharacterEntity,
	target: CharacterEntity,
	amount: int = 1
) -> bool:
	if source == null or target == null:
		return false

	if amount <= 0:
		return false

	var perception_result := get_perception_result(source, target)

	if perception_result != null:
		if perception_result.state == PerceptionState.AWARE:
			return false

	var activity := get_perception_activity(source, target)

	if activity == null:
		return false

	activity.add_visual(amount)

	return activity.visual_threshold_reached()

func check_visual_activity(
	source: CharacterEntity,
	target: CharacterEntity
) -> bool:
	if source == null or target == null:
		return false

	var activity := get_perception_activity(source, target)

	if activity == null:
		return false

	if not activity.visual_threshold_reached():
		return false

	var perception_result := get_perception_result(source, target)

	if perception_result != null:
		if perception_result.state == PerceptionState.AWARE:
			activity.reset_visual()
			return false

	if not can_perceive_by_distance(source, target):
		activity.reset_visual()
		return false

	if not has_line_of_sight(source, target):
		activity.reset_visual()
		return false

	var detected := perform_visual_check(source, target)

	activity.reset_visual()

	if detected:
		if perception_result == null:
			perception_result = create_result(source, target)

		perception_result.state = PerceptionState.AWARE
		perception_result.visual_detected = true

		var investigation_system := get_tree().get_first_node_in_group(
			"investigation_system"
		) as InvestigationSystem

		if investigation_system != null:
			investigation_system.clear_investigation(source)

		var source_id := source.get_instance_id()
		var target_id := target.get_instance_id()

		if not perception_results.has(source_id):
			perception_results[source_id] = {}

		perception_results[source_id][target_id] = perception_result

		perception_detected.emit(source, target)

	return detected

func update_all_perceptions() -> void:
	var characters := get_tree().get_nodes_in_group("combatants")

	for source_node in characters:
		var source := source_node as CharacterEntity

		if source == null or not source.is_alive:
			continue

		for target_node in characters:
			var target := target_node as CharacterEntity

			if target == null or not target.is_alive:
				continue

			if source == target:
				continue

			update_perception(source, target)

func debug_perception(
	source: CharacterEntity,
	target: CharacterEntity
) -> void:
	if source == null or target == null:
		return

	var distance_feet := get_distance_feet(source, target)
	var line_of_sight := has_line_of_sight(source, target)
	var spot_modifier := get_spot_distance_modifier(source, target)

	print(
		"Perception Debug: %s -> %s | distance=%d ft | LOS=%s | SpotDistance=%d | SpotModifier=%d | TargetDC=%d"
		% [
			source.name,
			target.name,
			distance_feet,
			str(line_of_sight),
			spot_modifier,
			source.spot_modifier,
			target.base_visual_dc
		]
	)

	var result := update_perception(source, target)

	print(
		"Perception Result: visual=%s | state=%s"
		% [
			str(result.visual_detected),
			str(result.state)
		]
	)

	var first_check := can_see(source, target)
	var second_check := can_see(source, target)

	print(
		"Perception Query: first=%s | second=%s"
		% [
			str(first_check),
			str(second_check)
		]
	)

func can_perceive_by_distance(
	source: CharacterEntity,
	target: CharacterEntity
) -> bool:
	if source == null or target == null:
		return false

	var distance_feet := get_distance_feet(source, target)

	return distance_feet <= base_visual_range_feet

func get_spot_distance_modifier(
	source: CharacterEntity,
	target: CharacterEntity
) -> int:
	if source == null or target == null:
		return 0

	var distance_feet := get_distance_feet(source, target)

	return -floori(float(distance_feet) / 10.0)

func has_line_of_sight(
	source: CharacterEntity,
	target: CharacterEntity
) -> bool:
	if source == null or target == null:
		return false

	var space_state := get_world_3d().direct_space_state

	print(
		"LOS Position Debug | source=%s | target=%s"
		% [
			str(source.global_position),
			str(target.global_position)
		]
	)

	var query := PhysicsRayQueryParameters3D.create(
		source.global_position + Vector3(0.0, 0.60, 0.0),
		target.global_position + Vector3(0.0, 0.60, 0.0)
	)

	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := space_state.intersect_ray(query)

	print(
		"LOS Ray Debug | collider=%s | position=%s"
		% [
			str(result.get("collider")),
			str(result.get("position"))
		]
	)

	if result.is_empty():
		return true

	var collider: Object = result["collider"]

	if collider == target:
		return true

	return false
