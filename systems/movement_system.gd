extends Node3D
class_name MovementSystem


const CELL_SIZE: float = 1.524


@export_category("Movement")
@export var movement_range_cells: int = 6


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

	if not debug_reported:
		print("MovementSystem: personagem selecionado = ", character.name)
		print("MovementSystem: grid_position = ", character.grid_position)
		print("MovementSystem: células alcançáveis = ", reachable_cells.size())
		debug_reported = true

	_update_destination_preview()

func _update_reachable_cells(origin: Vector2i) -> void:
	var new_cells: Array[Vector2i] = []

	for x in range(
		origin.x - movement_range_cells,
		origin.x + movement_range_cells + 1
	):
		for y in range(
			origin.y - movement_range_cells,
			origin.y + movement_range_cells + 1
		):
			var cell := Vector2i(x, y)

			if not grid_system.is_inside_grid(cell):
				continue

			var distance: int = abs(cell.x - origin.x) + abs(cell.y - origin.y)

			if distance <= movement_range_cells:
				new_cells.append(cell)

	reachable_cells = new_cells

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


func _build_path(
	origin: Vector2i,
	destination: Vector2i
) -> void:
	_clear_path()

	var current := origin

	while current.x != destination.x:
		if current.x < destination.x:
			current.x += 1
		else:
			current.x -= 1

		path_cells.append(current)

	while current.y != destination.y:
		if current.y < destination.y:
			current.y += 1
		else:
			current.y -= 1

		path_cells.append(current)

	for cell in path_cells:
		if cell == destination:
			continue

		var visual := _create_cell_visual(
			Color(0.3, 0.7, 0.9, path_alpha)
		)

		visual.position = grid_system.grid_to_world(cell) + Vector3(0.0, 0.028, 0.0)

		path_visuals[cell] = visual


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
