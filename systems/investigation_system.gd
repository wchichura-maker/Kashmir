extends Node3D
class_name InvestigationSystem

enum InvestigationState {
	INACTIVE,
	SUSPECTED,
	MOVING_TO_SOUND,
	SEARCHING,
	RETURNING
}

class InvestigationTarget:
	var center_cell: Vector2i
	var radius_cells: int = 2
	var origin_cell: Vector2i
	var search_turns_elapsed: int = 0
	var search_turn_limit: int = 0
	var state: InvestigationState = InvestigationState.SUSPECTED

	var sound_origin: Vector3
	var sound_category: SoundSystem.SoundCategory
	var created_at: int

	func _init(
		initial_sound_origin: Vector3,
		initial_sound_category: SoundSystem.SoundCategory,
		initial_center_cell: Vector2i = Vector2i.ZERO,
		initial_origin_cell: Vector2i = Vector2i.ZERO
	) -> void:
		sound_origin = initial_sound_origin
		sound_category = initial_sound_category
		center_cell = initial_center_cell
		origin_cell = initial_origin_cell
		created_at = Time.get_ticks_msec()


var investigation_targets: Dictionary = {}
var active_investigations: Dictionary = {}

@export_category("Investigation")
@export var investigation_turns_per_radius: int = 2

func calculate_investigation_time(radius_cells: int) -> int:
	if radius_cells <= 0:
		return 1

	return radius_cells * investigation_turns_per_radius

func _ready() -> void:
	add_to_group("investigation_system")

	call_deferred("_connect_perception_system")


func _connect_perception_system() -> void:
	var perception_system := get_tree().get_first_node_in_group(
		"perception_system"
	) as PerceptionSystem

	if perception_system == null:
		push_error("InvestigationSystem: PerceptionSystem não encontrado.")
		return

	if not perception_system.sound_perceived.is_connected(
		_on_sound_perceived
	):
		perception_system.sound_perceived.connect(
			_on_sound_perceived
	)


func _on_sound_perceived(
	listener: CharacterEntity,
	sound: SoundSystem.SoundEvent
) -> void:
	if listener == null or sound == null:
		return

	if sound.source == null:
		return

	var listener_id := listener.get_instance_id()

	var grid_system := get_tree().get_first_node_in_group(
		"grid_system"
	) as GridSystem

	if grid_system == null:
		push_error("InvestigationSystem: GridSystem não encontrado.")
		return

	var center_cell := grid_system.world_to_grid(sound.origin)
	var origin_cell := listener.grid_position

	var target: InvestigationTarget

	if investigation_targets.has(listener_id):
		target = investigation_targets[listener_id] as InvestigationTarget

		if target == null:
			target = InvestigationTarget.new(
				sound.origin,
				sound.category,
				center_cell,
				origin_cell
			)
	else:
		target = InvestigationTarget.new(
			sound.origin,
			sound.category,
			center_cell,
			origin_cell
		)

	target.center_cell = center_cell
	target.sound_origin = sound.origin
	target.sound_category = sound.category
	target.search_turns_elapsed = 0
	target.search_turn_limit = calculate_investigation_time(
	target.radius_cells
	)
	
	investigation_targets[listener_id] = target
	
	print(
		"Investigation Debug: %s | center_cell=%s | origin_cell=%s | radius=%d | state=%s | elapsed=%d | limit=%d"
		% [
			listener.name,
			str(target.center_cell),
			str(target.origin_cell),
			target.radius_cells,
			InvestigationState.keys()[target.state],
			target.search_turns_elapsed,
			target.search_turn_limit
		]
	)
	
	print(
		"InvestigationSystem: %s suspeita de uma presença | origem do som=%s | categoria=%s"
		% [
			listener.name,
			str(sound.origin),
			SoundSystem.SoundCategory.keys()[sound.category]
		]
	)


func get_investigation_target(
	listener: CharacterEntity
) -> InvestigationTarget:
	if listener == null:
		return null

	var listener_id := listener.get_instance_id()

	if not investigation_targets.has(listener_id):
		return null

	return investigation_targets[listener_id] as InvestigationTarget

func process_investigation_turn_end() -> void:
	for listener_id in investigation_targets:
		var target := investigation_targets[listener_id] as InvestigationTarget

		if target == null:
			continue

		if target.state == InvestigationState.INACTIVE:
			continue

		target.search_turns_elapsed += 1

		print(
			"Investigation Turn: listener_id=%s | state=%s | elapsed=%d | limit=%d"
			% [
				str(listener_id),
				InvestigationState.keys()[target.state],
				target.search_turns_elapsed,
				target.search_turn_limit
			]
		)

func start_investigation(
	listener: CharacterEntity
) -> bool:
	if listener == null:
		return false

	var target := get_investigation_target(listener)

	if target == null:
		return false

	if target.state != InvestigationState.SUSPECTED:
		return false

	target.state = InvestigationState.MOVING_TO_SOUND
	target.search_turns_elapsed = 0

	print(
		"InvestigationSystem: %s iniciou investigação | centro=%s | origem=%s | estado=%s"
		% [
			listener.name,
			str(target.center_cell),
			str(target.origin_cell),
			InvestigationState.keys()[target.state]
		]
	)

	return true

func evaluate_investigation_decision(
	listener: CharacterEntity
) -> void:
	if listener == null:
		return

	var target := get_investigation_target(listener)

	if target == null:
		return

	if target.state != InvestigationState.SUSPECTED:
		return

	start_investigation(listener)
