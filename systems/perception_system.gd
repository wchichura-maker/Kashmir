extends Node3D
class_name PerceptionSystem


enum PerceptionState {
	UNKNOWN,
	SUSPECTED,
	DETECTED,
	AWARE
}


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


@export_category("Perception")
@export var base_visual_range_feet: int = 120
@export var base_hearing_range_feet: int = 60


func _ready() -> void:
	add_to_group("perception_system")


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


func create_result(
	source: CharacterEntity,
	target: CharacterEntity
) -> PerceptionResult:
	var distance_feet := get_distance_feet(source, target)

	return PerceptionResult.new(
		PerceptionState.UNKNOWN,
		distance_feet
	)
