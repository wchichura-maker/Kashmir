extends Node3D
class_name MovementSystem


const CELL_SIZE: float = 1.524

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1)
]

@export_category("Movement")
@export var movement_speed_feet: int = 30


@export_category("Visual")
@export var reachable_alpha: float = 0.18
@export var path_alpha: float = 0.35
@export var destination_alpha: float = 0.55


var grid_system: GridSystem
var selection_system: SelectionSystem

var reachable_cells: Array[Vector2i] = []
var path_cells: Array[Vector2i] = []

var reachable_visuals: Dictionary = {}
var path_visuals: Dictionary = {}

var destination_visual: MeshInstance3D
var debug_reported: bool = false

func _ready() -> void:
	add_to_group("movement_system")

	call_deferred("_initialize")


func _initialize() -> void:
	grid_system = get_tree().get_first_node_in_group(
		"grid_system"
	) as GridSystem

	selection_system = get_tree().get_first_node_in_group(
		"selection_system"
	) as SelectionSystem

	if grid_system == null:
		push_error("MovementSystem: GridSystem not found.")

	if selection_system == null:
		push_error("MovementSystem: SelectionSystem not found.")

	_create_destination_visual()


func _process(_delta: float) -> void:
	if grid_system == null or selection_system == null:
		return

	var character := selection_system.selected_character

	if character != null and character.is_moving:
		clear_preview()
		return
		
	if character == null:
		clear_preview()
		return

	_update_reachable_cells(character.grid_position)

	_update_destination_preview()

func _update_reachable_cells(origin: Vector2i) -> void:
	var character := selection_system.selected_character

	if character == null:
		reachable_cells.clear()
		_rebuild_reachable_visuals()
		return

	var distances: Dictionary = {}
	var states: Array[Vector3i] = []

	var start_state := Vector3i(origin.x, origin.y, 0)

	distances[start_state] = 0
	states.append(start_state)

	while not states.is_empty():
		var best_index := 0
		var best_state: Vector3i = states[0]

		for i in range(1, states.size()):
			if distances[states[i]] < distances[best_state]:
				best_index = i
				best_state = states[i]

		states.remove_at(best_index)

		var current := Vector2i(
			best_state.x,
			best_state.y
		)

		var current_cost: int = distances[best_state]
		var diagonal_parity: int = best_state.z

		for direction in DIRECTIONS:
			var next_cell := current + direction

			if not grid_system.is_inside_grid(next_cell):
				continue

			if not can_pass_through_cell(
				next_cell,
				character
			):
				continue

			if not _can_move_diagonally(
				current,
				next_cell,
			):
				continue

			var is_diagonal := (
				direction.x != 0
				and direction.y != 0
			)

			var movement_cost := 5
			var next_parity := diagonal_parity

			if is_diagonal:
				if diagonal_parity == 0:
					movement_cost = 5
				else:
					movement_cost = 10

				next_parity = 1 - diagonal_parity

			var new_cost := current_cost + movement_cost

			if new_cost > movement_speed_feet:
				continue

			var next_state := Vector3i(
				next_cell.x,
				next_cell.y,
				next_parity
			)

			if not distances.has(next_state):
				distances[next_state] = new_cost
				states.append(next_state)
			elif new_cost < distances[next_state]:
				distances[next_state] = new_cost

	reachable_cells.clear()

	for state in distances.keys():
		var cell := Vector2i(
			state.x,
			state.y
		)

		if not reachable_cells.has(cell):
			reachable_cells.append(cell)

	_rebuild_reachable_visuals()

func _rebuild_reachable_visuals() -> void:
	_clear_visual_dictionary(reachable_visuals)

	var selection_system_instance := selection_system

	for cell in reachable_cells:
		if (
			selection_system_instance.selected_character != null
			and cell == selection_system_instance.selected_character.grid_position
		):
			continue

		var visual := _create_cell_visual(
			Color(0.35, 0.65, 0.85, reachable_alpha)
		)

		visual.position = grid_system.grid_to_world(cell) + Vector3(0.0, 0.025, 0.0)

		reachable_visuals[cell] = visual


func _update_destination_preview() -> void:
	var character := selection_system.selected_character

	if character == null:
		destination_visual.visible = false
		return

	var hovered_cell := grid_system.hovered_cell

	if not grid_system.is_inside_grid(hovered_cell):
		_clear_path()
		destination_visual.visible = false
		return

	if not reachable_cells.has(hovered_cell):
		_clear_path()
		destination_visual.visible = false
		return

	if hovered_cell == character.grid_position:
		_clear_path()
		destination_visual.visible = false
		return

	destination_visual.position = grid_system.grid_to_world(hovered_cell) + Vector3(0.0, 0.03, 0.0)

	destination_visual.visible = true

	_build_path(
		character.grid_position,
		hovered_cell
	)
	
	if path_cells.is_empty():
		destination_visual.visible = false

func _build_path(
	origin: Vector2i,
	destination: Vector2i
) -> void:
	_clear_path()

	if origin == destination:
		return

	var path := _find_path(origin, destination)

	if path.is_empty():
		return

	path_cells.append_array(path)

	for cell in path_cells:
		if cell == destination:
			continue

		var visual := _create_cell_visual(
			Color(0.3, 0.7, 0.9, path_alpha)
		)

		visual.position = (
			grid_system.grid_to_world(cell)
			+ Vector3(0.0, 0.028, 0.0)
		)

		path_visuals[cell] = visual

func _find_path(
	origin: Vector2i,
	destination: Vector2i
) -> Array[Vector2i]:
	var character := selection_system.selected_character

	if character == null:
		return []

	var distances: Dictionary = {}
	var came_from: Dictionary = {}
	var states: Array[Vector3i] = []

	var start_state := Vector3i(
		origin.x,
		origin.y,
		0
	)

	distances[start_state] = 0
	came_from[start_state] = start_state
	states.append(start_state)

	var destination_state := Vector3i(
		destination.x,
		destination.y,
		0
	)

	while not states.is_empty():
		var best_index := 0
		var best_state: Vector3i = states[0]

		for i in range(1, states.size()):
			if distances[states[i]] < distances[best_state]:
				best_index = i
				best_state = states[i]

		states.remove_at(best_index)

		var current := Vector2i(
			best_state.x,
			best_state.y
		)

		var current_cost: int = distances[best_state]
		var diagonal_parity: int = best_state.z

		if current == destination:
			destination_state = best_state
			break

		for direction in DIRECTIONS:
			var next_cell := current + direction

			if not grid_system.is_inside_grid(next_cell):
				continue

			if not can_pass_through_cell(
				next_cell,
				character
			):
				continue

			if not _can_move_diagonally(
				current,
				next_cell,
			):
				continue

			var is_diagonal := (
				direction.x != 0
				and direction.y != 0
			)

			var movement_cost := 5
			var next_parity := diagonal_parity

			if is_diagonal:
				if diagonal_parity == 0:
					movement_cost = 5
				else:
					movement_cost = 10

				next_parity = 1 - diagonal_parity

			var new_cost := current_cost + movement_cost

			if new_cost > movement_speed_feet:
				continue

			var next_state := Vector3i(
				next_cell.x,
				next_cell.y,
				next_parity
			)

			if not distances.has(next_state):
				distances[next_state] = new_cost
				came_from[next_state] = best_state
				states.append(next_state)

			elif new_cost < distances[next_state]:
				distances[next_state] = new_cost
				came_from[next_state] = best_state

	if not distances.has(destination_state):
		return []

	var path: Array[Vector2i] = []
	var current_state: Vector3i = destination_state

	while current_state != start_state:
		path.push_front(
			Vector2i(
				current_state.x,
				current_state.y
			)
		)

		current_state = came_from[current_state]

	return path
	
func _create_destination_visual() -> void:
	destination_visual = _create_cell_visual(
		Color(0.35, 0.75, 1.0, destination_alpha)
	)

	destination_visual.name = "Destination"
	destination_visual.visible = false


func _create_cell_visual(color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(
		CELL_SIZE * 0.86,
		CELL_SIZE * 0.86
	)

	visual.mesh = mesh

	var material := StandardMaterial3D.new()

	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	visual.material_override = material

	visual.position.y = 0.022

	add_child(visual)

	return visual


func clear_preview() -> void:
	reachable_cells.clear()
	_clear_visual_dictionary(reachable_visuals)

	path_cells.clear()
	_clear_visual_dictionary(path_visuals)

	if is_instance_valid(destination_visual):
		destination_visual.visible = false


func _clear_path() -> void:
	path_cells.clear()
	_clear_visual_dictionary(path_visuals)


func _clear_visual_dictionary(
	visual_dictionary: Dictionary
) -> void:
	for visual in visual_dictionary.values():
		if is_instance_valid(visual):
			visual.queue_free()

	visual_dictionary.clear()
func try_move_to_cell(cell: Vector2i) -> bool:
	if grid_system == null or selection_system == null:
		return false

	var character := selection_system.selected_character

	if character == null:
		return false

	if character.is_moving:
		return false

	if not grid_system.is_inside_grid(cell):
		return false

	if grid_system.is_cell_blocked(cell):
		return false
		
	if not can_end_movement_on_cell(cell, character):
		return false
		
	if not reachable_cells.has(cell):
		return false
		
	if cell == character.grid_position:
		return false

	_build_path(
		character.grid_position,
		cell
	)

	if path_cells.is_empty():
		return false

	var move_path: Array[Vector2i] = []
	move_path.append_array(path_cells)

	clear_preview()

	character.move_along_path(move_path)

	return true

func can_pass_through_cell(
	cell: Vector2i,
	moving_character: CharacterEntity
) -> bool:
	if not grid_system.is_inside_grid(cell):
		return false

	if grid_system.is_cell_blocked(cell):
		return false

	if not grid_system.is_cell_occupied(cell):
		return true

	var occupant := grid_system.get_character_at_cell(cell)

	if occupant == null:
		return true

	if occupant == moving_character:
		return true

	# Um aliado pode ser atravessado.
	if occupant.faction == moving_character.faction:
		return true

	# Um inimigo vivo normalmente não pode ser atravessado.
	if occupant.is_alive and not occupant.is_helpless:
		return false

	# Um inimigo indefeso pode ser atravessado.
	if occupant.is_helpless:
		return true

	# Cadáver não é tratado como criatura viva.
	if not occupant.is_alive:
		return true

	return false
	
func can_end_movement_on_cell(
	cell: Vector2i,
	moving_character: CharacterEntity
) -> bool:
	if not grid_system.is_inside_grid(cell):
		return false

	if grid_system.is_cell_blocked(cell):
		return false

	if not grid_system.is_cell_occupied(cell):
		return true

	var occupant := grid_system.get_character_at_cell(cell)

	if occupant == null:
		return true

	if occupant == moving_character:
		return false

	# Pela regra básica, não terminamos no mesmo espaço
	# que outra criatura, salvo se ela estiver helpless.
	if occupant.is_helpless:
		return true

	return false
	
func _can_move_diagonally(
	from_cell: Vector2i,
	to_cell: Vector2i
) -> bool:
	var difference := to_cell - from_cell

	if difference.x == 0 or difference.y == 0:
		return true

	var horizontal_cell := Vector2i(
		to_cell.x,
		from_cell.y
	)

	var vertical_cell := Vector2i(
		from_cell.x,
		to_cell.y
	)

	if not grid_system.is_inside_grid(horizontal_cell):
		return false

	if not grid_system.is_inside_grid(vertical_cell):
		return false

	if grid_system.is_cell_blocked(horizontal_cell):
		return false

	if grid_system.is_cell_blocked(vertical_cell):
		return false

	return true
