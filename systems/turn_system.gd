extends Node3D
class_name TurnSystem

signal combat_started
signal round_started(round_number: int)
signal turn_started(character: CharacterEntity)
signal turn_ended(character: CharacterEntity)
signal combat_ended

enum ActionType {
	STANDARD,
	MOVE,
	FULL_ROUND,
	FREE
}

class TurnResources:
	var standard_action_available: bool = true
	var move_action_available: bool = true
	var full_round_action_available: bool = true
	var free_actions_used: int = 0

	var movement_remaining_feet: int = 30
	var movement_action_active: bool = false

	var has_moved_this_turn: bool = false
	var five_foot_step_available: bool = true

	func reset(movement_speed_feet: int = 30) -> void:
		standard_action_available = true
		move_action_available = true
		full_round_action_available = true
		free_actions_used = 0

		movement_remaining_feet = movement_speed_feet
		movement_action_active = false

		has_moved_this_turn = false
		five_foot_step_available = true

	func can_use_standard() -> bool:
		return standard_action_available and full_round_action_available

	func can_use_move() -> bool:
		return move_action_available and full_round_action_available

	func can_use_full_round() -> bool:
		return standard_action_available and move_action_available and full_round_action_available

	func consume_standard() -> bool:
		if not can_use_standard():
			return false

		standard_action_available = false
		movement_action_active = false

		return true

	func consume_move() -> bool:
		if not can_use_move():
			return false

		move_action_available = false
		return true

	func can_continue_movement(distance_feet: int) -> bool:
		if not full_round_action_available:
			return false

		if distance_feet <= 0:
			return false

		return movement_remaining_feet >= distance_feet


	func consume_movement(distance_feet: int) -> bool:
		if not can_continue_movement(distance_feet):
			return false
		movement_remaining_feet -= distance_feet
		return true
	
	
	func consume_full_round() -> bool:
		if not can_use_full_round():
			return false

		standard_action_available = false
		move_action_available = false
		full_round_action_available = false
		return true

	func consume_free() -> bool:
		if not full_round_action_available:
			return false

		free_actions_used += 1
		return true
	
	func can_use_second_move(movement_speed_feet: int) -> bool:
		if not full_round_action_available:
			return false

		if move_action_available:
			return false

		if not standard_action_available:
			return false

		if movement_speed_feet <= 0:
			return false

		return true

	func consume_second_move(movement_speed_feet: int) -> bool:
		if not can_use_second_move(movement_speed_feet):
			return false

		standard_action_available = false
		movement_remaining_feet = movement_speed_feet

		return true
		
func can_use_second_move(character: CharacterEntity) -> bool:
	if not combat_active:
		return false

	if character != current_actor:
		return false

	if not turn_resources.has(character):
		return false

	var resources: TurnResources = turn_resources[character]

	return resources.can_use_second_move(30)
	
func use_second_move(character: CharacterEntity) -> bool:
	if not can_use_second_move(character):
		return false

	var resources: TurnResources = turn_resources[character]

	var result := resources.consume_second_move(30)

	if result:
		print(
			"TurnSystem: %s iniciou uma SEGUNDA MOVE ACTION."
			% character.name
		)

	return result

@export_category("Combat")
@export var auto_start_combat: bool = false

var combat_active: bool = false
var round_number: int = 0

var initiative_order: Array[CharacterEntity] = []
var current_actor_index: int = -1
var current_actor: CharacterEntity = null

var turn_resources: Dictionary = {}
var initiative_results: Dictionary = {}

func _ready() -> void:
	add_to_group("turn_system")

	call_deferred("_connect_perception_system")
	call_deferred("_initialize")

func _connect_perception_system() -> void:
	var perception_system := get_tree().get_first_node_in_group("perception_system") as PerceptionSystem

	if perception_system == null:
		push_error("TurnSystem: PerceptionSystem não encontrado.")
		return

	if not perception_system.perception_detected.is_connected(_on_perception_detected):
		perception_system.perception_detected.connect(_on_perception_detected)

func _on_perception_detected(
	source: CharacterEntity,
	target: CharacterEntity
) -> void:
	if source == null or target == null:
		return

	print(
		"Perception Event: %s detectou %s."
		% [
			source.name,
			target.name
		]
	)

	if not source.is_alive:
		return

	if not target.is_alive:
		return

	if source.faction == target.faction:
		return

	request_combat_start()

func _initialize() -> void:
	if auto_start_combat:
		start_combat()

func request_combat_start() -> void:
	if combat_active:
		return

	start_combat()

func start_combat() -> void:
	if combat_active:
		return

	var characters := _get_combatants()

	if characters.is_empty():
		push_error("TurnSystem: nenhum combatente encontrado.")
		return

	_roll_initiative(characters)

	combat_active = true
	round_number = 1
	current_actor_index = -1

	print("")
	print("========================================")
	print("COMBATE INICIADO")
	print("========================================")

	for i in range(initiative_order.size()):
		var character := initiative_order[i]
		print(
			"%.0f. %s | iniciativa = %d"
			% [
				i + 1,
				character.name,
				_get_initiative_result(character)
			]
		)

	print("========================================")

	var investigation_system := get_tree().get_first_node_in_group(
		"investigation_system"
	) as InvestigationSystem

	if investigation_system != null:
		investigation_system.clear_all_investigations()

	for character in characters:
		if character.is_moving:
			character.interrupt_movement()

	combat_started.emit()

	_start_round()


func _start_round() -> void:
	if not combat_active:
		return

	print("")
	print("---------- RODADA %d ----------" % round_number)

	for character in initiative_order:
		if not is_instance_valid(character):
			continue

		var resources := TurnResources.new()
		turn_resources[character] = resources

	round_started.emit(round_number)

	current_actor_index = 0
	_start_current_turn()


func _start_current_turn() -> void:
	if not combat_active:
		return

	if initiative_order.is_empty():
		end_combat()
		return

	if current_actor_index >= initiative_order.size():
		round_number += 1
		_start_round()
		return

	var character := initiative_order[current_actor_index]

	if not is_instance_valid(character):
		_advance_turn()
		return

	if not character.is_alive:
		print("TurnSystem: %s está morto e não pode agir." % character.name)
		_advance_turn()
		return

	current_actor = character

	if not turn_resources.has(character):
		turn_resources[character] = TurnResources.new()

	var resources: TurnResources = turn_resources[character]
	resources.reset(30)
	
	var investigation_system := get_tree().get_first_node_in_group(
		"investigation_system"
	) as InvestigationSystem

	if investigation_system != null:
		investigation_system.evaluate_investigation_decision(character)
		
	print("")
	print(">>> TURNO DE %s <<<" % character.name)
	print(
		"    Standard: %s | Move: %s | Full Round: %s"
		% [
			resources.standard_action_available,
			resources.move_action_available,
			resources.full_round_action_available
		]
	)

	turn_started.emit(character)


func end_turn() -> void:
	if not combat_active:
		return

	if current_actor == null:
		return

	var finished_character := current_actor

	print("<<< FIM DO TURNO DE %s >>>" % finished_character.name)

	turn_ended.emit(finished_character)

	var investigation_system := get_tree().get_first_node_in_group(
		"investigation_system"
	) as InvestigationSystem

	if investigation_system != null:
		investigation_system.process_investigation_turn_end()
	
	current_actor = null
	_advance_turn()


func _advance_turn() -> void:
	current_actor_index += 1

	if current_actor_index >= initiative_order.size():
		round_number += 1
		_start_round()
		return

	_start_current_turn()


func end_combat() -> void:
	if not combat_active:
		return

	combat_active = false
	current_actor = null
	current_actor_index = -1

	print("")
	print("========================================")
	print("COMBATE ENCERRADO")
	print("========================================")

	combat_ended.emit()


func can_use_action(
	character: CharacterEntity,
	action_type: ActionType
) -> bool:
	if not combat_active:
		return false

	if character != current_actor:
		return false

	if not turn_resources.has(character):
		return false

	var resources: TurnResources = turn_resources[character]

	match action_type:
		ActionType.STANDARD:
			return resources.can_use_standard()

		ActionType.MOVE:
			return resources.can_use_move()

		ActionType.FULL_ROUND:
			return resources.can_use_full_round()

		ActionType.FREE:
			return resources.full_round_action_available

	return false


func consume_action(
	character: CharacterEntity,
	action_type: ActionType
) -> bool:
	if not can_use_action(character, action_type):
		return false

	var resources: TurnResources = turn_resources[character]

	match action_type:
		ActionType.STANDARD:
			return resources.consume_standard()

		ActionType.MOVE:
			return resources.consume_move()

		ActionType.FULL_ROUND:
			return resources.consume_full_round()

		ActionType.FREE:
			return resources.consume_free()

	return false


func has_standard_action(character: CharacterEntity) -> bool:
	return can_use_action(character, ActionType.STANDARD)


func has_move_action(character: CharacterEntity) -> bool:
	return can_use_action(character, ActionType.MOVE)


func has_full_round_action(character: CharacterEntity) -> bool:
	return can_use_action(character, ActionType.FULL_ROUND)


func use_standard_action(character: CharacterEntity) -> bool:
	var result := consume_action(character, ActionType.STANDARD)

	if result:
		print("TurnSystem: %s consumiu STANDARD ACTION." % character.name)

	return result


func use_move_action(character: CharacterEntity) -> bool:
	var result := consume_action(character, ActionType.MOVE)

	if result:
		print("TurnSystem: %s consumiu MOVE ACTION." % character.name)

	return result


func use_full_round_action(character: CharacterEntity) -> bool:
	var result := consume_action(character, ActionType.FULL_ROUND)

	if result:
		print("TurnSystem: %s consumiu FULL-ROUND ACTION." % character.name)

	return result


func use_free_action(character: CharacterEntity) -> bool:
	var result := consume_action(character, ActionType.FREE)

	if result:
		print("TurnSystem: %s consumiu FREE ACTION." % character.name)

	return result


func get_current_actor() -> CharacterEntity:
	return current_actor


func is_character_turn(character: CharacterEntity) -> bool:
	return combat_active and current_actor == character


func _get_combatants() -> Array[CharacterEntity]:
	var result: Array[CharacterEntity] = []

	var nodes := get_tree().get_nodes_in_group("combatants")

	for node in nodes:
		var character := node as CharacterEntity

		if character == null:
			continue

		if not character.is_alive:
			continue

		result.append(character)

	return result


func _roll_initiative(characters: Array[CharacterEntity]) -> void:
	initiative_order.clear()
	initiative_results.clear()

	for character in characters:
		initiative_order.append(character)
		initiative_results[character] = randi_range(
			1,
			20
		) + character.initiative_modifier

	initiative_order.sort_custom(_compare_initiative)

func _compare_initiative(
	a: CharacterEntity,
	b: CharacterEntity
) -> bool:
	return initiative_results[a] > initiative_results[b]


func _get_initiative_result(character: CharacterEntity) -> int:
	if initiative_results.has(character):
		return initiative_results[character]

	return 0

func get_movement_remaining_feet(character: CharacterEntity) -> int:
	if not turn_resources.has(character):
		return 0

	var resources: TurnResources = turn_resources[character]

	if character != current_actor:
		return 0

	return resources.movement_remaining_feet

func get_movement_speed_feet(character: CharacterEntity) -> int:
	if not combat_active:
		return 0

	if character != current_actor:
		return 0

	if not turn_resources.has(character):
		return 0

	return 30


func has_second_move_potential(character: CharacterEntity) -> bool:
	if not combat_active:
		return false

	if character != current_actor:
		return false

	if not turn_resources.has(character):
		return false

	var resources: TurnResources = turn_resources[character]

	if resources.movement_remaining_feet > 0:
		return false

	return resources.standard_action_available
	
func can_continue_movement(
	character: CharacterEntity,
	distance_feet: int
) -> bool:
	if not combat_active:
		return false

	if character != current_actor:
		return false

	if not turn_resources.has(character):
		return false

	var resources: TurnResources = turn_resources[character]

	return resources.can_continue_movement(distance_feet)


func consume_movement(
	character: CharacterEntity,
	distance_feet: int
) -> bool:

	if not can_continue_movement(character, distance_feet):
		return false

	var resources: TurnResources = turn_resources[character]

	var result := resources.consume_movement(distance_feet)

	if result:
		print(
			"TurnSystem: %s moveu %d ft | restante = %d ft"
			% [
				character.name,
				distance_feet,
				resources.movement_remaining_feet
			]
		)

		if resources.movement_remaining_feet <= 0:
			resources.movement_action_active = false

	return result
	
func is_movement_action_active(character: CharacterEntity) -> bool:
	if not combat_active:
		return false

	if character != current_actor:
		return false

	if not turn_resources.has(character):
		return false

	var resources: TurnResources = turn_resources[character]

	return resources.movement_action_active
	
func mark_character_moved(character: CharacterEntity) -> void:
	if not turn_resources.has(character):
		return

	var resources: TurnResources = turn_resources[character]

	resources.has_moved_this_turn = true
	resources.five_foot_step_available = false
	
func can_start_movement(character: CharacterEntity) -> bool:
	if not combat_active:
		return false

	if character != current_actor:
		return false

	if not turn_resources.has(character):
		return false

	var resources: TurnResources = turn_resources[character]

	# Continua uma Move Action que já foi iniciada.
	if resources.movement_action_active:
		return true

	# Primeira Move Action da rodada.
	if resources.move_action_available:
		return true

	# Segunda Move Action: usa a Standard Action.
	if resources.standard_action_available:
		return true

	return false

func start_movement(character: CharacterEntity) -> bool:
	if not combat_active:
		return false

	if character != current_actor:
		return false

	if not turn_resources.has(character):
		return false

	var resources: TurnResources = turn_resources[character]

	# Se já existe uma Move Action ativa,
	# não fazemos nada. O jogador pode continuar
	# escolhendo destinos com os cliques.
	if resources.movement_action_active:
		return true

	# Primeira Move Action.
	if resources.move_action_available:
		resources.move_action_available = false
		resources.movement_action_active = true
		resources.movement_remaining_feet = 30

		print(
			"TurnSystem: %s iniciou a PRIMEIRA MOVE ACTION."
			% character.name
		)

		return true

	# Segunda Move Action:
	# usa a Standard Action.
	if resources.standard_action_available:
		resources.standard_action_available = false
		resources.movement_action_active = true
		resources.movement_remaining_feet = 30

		print(
			"TurnSystem: %s iniciou a SEGUNDA MOVE ACTION."
			% character.name
		)

		return true

	return false
func confirm_second_move(character: CharacterEntity) -> bool:
	if not combat_active:
		return false

	if character != current_actor:
		return false

	if not turn_resources.has(character):
		return false

	var resources: TurnResources = turn_resources[character]

	if not resources.standard_action_available:
		return false

	resources.standard_action_available = false
	resources.movement_remaining_feet = 30
	resources.movement_action_active = true

	print(
		"TurnSystem: %s confirmou SEGUNDA MOVE ACTION usando STANDARD."
		% character.name
	)

	return true
