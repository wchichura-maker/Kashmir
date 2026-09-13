extends Node3D
class_name AISystem

enum AIState {
	IDLE,
	INVESTIGATING,
	SEARCHING,
	COMBAT
}

var ai_states: Dictionary = {}

func _ready() -> void:
	add_to_group("ai_system")
	call_deferred("_connect_turn_system")

func _connect_turn_system() -> void:
	var turn_system := get_tree().get_first_node_in_group(
		"turn_system"
	) as TurnSystem

	if turn_system == null:
		push_error("AISystem: TurnSystem não encontrado.")
		return

	if not turn_system.turn_started.is_connected(_on_turn_started):
		turn_system.turn_started.connect(_on_turn_started)

func _on_turn_started(character: CharacterEntity) -> void:
	if character == null:
		return

	if character.faction != "Enemy":
		return

	var character_id := character.get_instance_id()

	if not ai_states.has(character_id):
		ai_states[character_id] = AIState.IDLE

	var state: AIState = ai_states[character_id]

	var perception_system := get_tree().get_first_node_in_group(
		"perception_system"
	) as PerceptionSystem

	if perception_system != null:
		var characters := get_tree().get_nodes_in_group("combatants")

		for other_node in characters:
			var other := other_node as CharacterEntity

			if other == null:
				continue

			if other == character:
				continue

			if not other.is_alive:
				continue

			if other.faction == character.faction:
				continue

			var perception_result: PerceptionSystem.PerceptionResult = (
				perception_system.get_perception_result(character, other)
			)

			if perception_result == null:
				continue

			if perception_result.state == PerceptionSystem.PerceptionState.AWARE:
				state = AIState.COMBAT
				ai_states[character_id] = state
				break

	print(
		"========== AI TURN =========="
	)
	print(
		"Enemy: %s"
		% character.name
	)
	print(
		"Estado: %s"
		% AIState.keys()[state]
	)
	print(
		"============================="
	)
