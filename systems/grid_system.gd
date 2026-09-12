extends Node3D
class_name GridSystem

const CELL_SIZE: float = 1.524

@export_category("Grid")
@export var grid_width: int = 26
@export var grid_height: int = 26

@export_category("Visual")
@export var line_height: float = 0.015
@export var show_grid: bool = true

var selected_cell: Vector2i = Vector2i(-1, -1)
var selection_visual: MeshInstance3D
var hovered_cell: Vector2i = Vector2i(-1, -1)
var hover_visual: MeshInstance3D
var blocked_cells: Dictionary = {}
var occupied_cells: Dictionary = {}

func _ready() -> void:
	add_to_group("grid_system")
	
	if show_grid:
		_build_grid()

	_create_selection_visual()
	_create_hover_visual()

func world_to_grid(world_position: Vector3) -> Vector2i:
	var local_position := to_local(world_position)

	return Vector2i(
		floori(local_position.x / CELL_SIZE),
		floori(local_position.z / CELL_SIZE)
	)

func grid_to_world(grid_position: Vector2i) -> Vector3:
	var local_position := Vector3(
		(grid_position.x + 0.5) * CELL_SIZE,
		0.0,
		(grid_position.y + 0.5) * CELL_SIZE
	)

	return to_global(local_position)

func is_inside_grid(grid_position: Vector2i) -> bool:
	return (
		grid_position.x >= 0
		and grid_position.x < grid_width
		and grid_position.y >= 0
		and grid_position.y < grid_height
	)

func select_cell(cell: Vector2i) -> void:
	selected_cell = cell

	_update_selection_visual()

func clear_selection() -> void:
	selected_cell = Vector2i(-1, -1)

	if is_instance_valid(selection_visual):
		selection_visual.visible = false

func _create_selection_visual() -> void:
	selection_visual = MeshInstance3D.new()
	selection_visual.name = "Selection"

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(
		CELL_SIZE * 0.92,
		CELL_SIZE * 0.92
	)

	selection_visual.mesh = mesh

	var material := StandardMaterial3D.new()

	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.65, 0.8, 0.72, 0.35)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	selection_visual.material_override = material

	selection_visual.position.y = line_height + 0.002
	selection_visual.visible = false

	add_child(selection_visual)


func _update_selection_visual() -> void:
	if not is_inside_grid(selected_cell):
		selection_visual.visible = false
		return

	var local_position := Vector3(
		(selected_cell.x + 0.5) * CELL_SIZE,
		line_height + 0.002,
		(selected_cell.y + 0.5) * CELL_SIZE
	)

	selection_visual.position = local_position
	selection_visual.visible = true


func _build_grid() -> void:
	var material := StandardMaterial3D.new()

	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.05, 0.05, 0.05, 0.65)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for x in range(grid_width + 1):
		var line := MeshInstance3D.new()

		line.mesh = _create_line_mesh(
			Vector3(
				x * CELL_SIZE,
				line_height,
				0.0
			),
			Vector3(
				x * CELL_SIZE,
				line_height,
				grid_height * CELL_SIZE
			)
		)

		line.material_override = material
		add_child(line)

	for z in range(grid_height + 1):
		var line := MeshInstance3D.new()

		line.mesh = _create_line_mesh(
			Vector3(
				0.0,
				line_height,
				z * CELL_SIZE
			),
			Vector3(
				grid_width * CELL_SIZE,
				line_height,
				z * CELL_SIZE
			)
		)

		line.material_override = material
		add_child(line)


func _create_line_mesh(
	start: Vector3,
	end: Vector3
) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(start)
	mesh.surface_add_vertex(end)
	mesh.surface_end()

	return mesh
func set_hovered_cell(cell: Vector2i) -> void:
	hovered_cell = cell

	if not is_inside_grid(cell):
		hover_visual.visible = false
		return

	var local_position := Vector3(
		(cell.x + 0.5) * CELL_SIZE,
		line_height + 0.003,
		(cell.y + 0.5) * CELL_SIZE
	)

	hover_visual.position = local_position
	hover_visual.visible = true


func clear_hover() -> void:
	hovered_cell = Vector2i(-1, -1)

	if is_instance_valid(hover_visual):
		hover_visual.visible = false


func _create_hover_visual() -> void:
	hover_visual = MeshInstance3D.new()
	hover_visual.name = "Hover"

	var mesh := PlaneMesh.new()

	mesh.size = Vector2(
		CELL_SIZE * 0.94,
		CELL_SIZE * 0.94
	)

	hover_visual.mesh = mesh

	var material := StandardMaterial3D.new()

	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.45, 0.65, 0.8, 0.18)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	hover_visual.material_override = material

	hover_visual.position.y = line_height + 0.003
	hover_visual.visible = false

	add_child(hover_visual)
func is_cell_blocked(cell: Vector2i) -> bool:
	return blocked_cells.has(cell)


func set_cell_blocked(cell: Vector2i, blocked: bool = true) -> void:
	if not is_inside_grid(cell):
		return

	if blocked:
		blocked_cells[cell] = true
	else:
		blocked_cells.erase(cell)


func clear_blocked_cells() -> void:
	blocked_cells.clear()


func can_walk(cell: Vector2i) -> bool:
	if not is_inside_grid(cell):
		return false

	if is_cell_blocked(cell):
		return false

	return true

func is_cell_occupied(cell: Vector2i) -> bool:
	return occupied_cells.has(cell)


func get_character_at_cell(cell: Vector2i) -> CharacterEntity:
	if not occupied_cells.has(cell):
		return null

	return occupied_cells[cell] as CharacterEntity


func set_cell_occupied(
	cell: Vector2i,
	character: CharacterEntity
) -> void:
	if not is_inside_grid(cell):
		return

	if character == null:
		return

	occupied_cells[cell] = character


func clear_cell_occupied(cell: Vector2i) -> void:
	occupied_cells.erase(cell)
