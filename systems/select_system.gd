extends Node3D
class_name SelectionSystem


var selected_character: CharacterEntity = null
var selected_cell: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	add_to_group("selection_system")
func _process(_delta: float) -> void:
	_update_hover()
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("select_cell"):
		return

	var mouse_event := event as InputEventMouseButton

	if mouse_event == null:
		return

	var camera := get_viewport().get_camera_3d()

	if camera == null:
		return

	var ray_origin := camera.project_ray_origin(mouse_event.position)
	var ray_direction := camera.project_ray_normal(mouse_event.position)

	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 1000.0
	)

	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		return

	var collider = result.get("collider")

	if collider == null:
		return

	# -------------------------------------------------
	# PRIORIDADE 1: PERSONAGEM
	# -------------------------------------------------

	if collider is Area3D:
		var character := collider.get_parent() as CharacterEntity

		if character != null:
			select_character(character)
			get_viewport().set_input_as_handled()
			return

	# -------------------------------------------------
	# PRIORIDADE 2: GRID / TERRENO
	# -------------------------------------------------

	var grid_system := get_tree().get_first_node_in_group(
		"grid_system"
	) as GridSystem

	if grid_system == null:
		return

	var world_position: Vector3 = result.get("position")
	var cell := grid_system.world_to_grid(world_position)

	if not grid_system.is_inside_grid(cell):
		return

	# -------------------------------------------------
	# PRIORIDADE 3: MOVIMENTO
	# -------------------------------------------------

	if selected_character != null:

		if selected_character.is_moving:
			get_viewport().set_input_as_handled()
			return

		var movement_system: MovementSystem = get_tree().get_first_node_in_group(
			"movement_system"
		) as MovementSystem

		if movement_system != null:
			movement_system.try_move_to_cell(cell)
			get_viewport().set_input_as_handled()
			return

	# -------------------------------------------------
	# SEM PERSONAGEM SELECIONADO:
	# SELECIONA A CÉLULA
	# -------------------------------------------------

	select_cell(cell)

	get_viewport().set_input_as_handled()

func select_character(character: CharacterEntity) -> void:
	_clear_character_selection()

	var grid_system := get_tree().get_first_node_in_group(
		"grid_system"
	) as GridSystem

	if grid_system != null:
		grid_system.clear_selection()

	selected_cell = Vector2i(-1, -1)

	selected_character = character
	selected_character.set_selected(true)


func select_cell(cell: Vector2i) -> void:
	_clear_character_selection()

	selected_cell = cell

	var grid_system := get_tree().get_first_node_in_group(
		"grid_system"
	) as GridSystem

	if grid_system != null:
		grid_system.select_cell(cell)


func clear_selection() -> void:
	_clear_character_selection()

	selected_cell = Vector2i(-1, -1)

	var grid_system := get_tree().get_first_node_in_group(
		"grid_system"
	) as GridSystem

	if grid_system != null:
		grid_system.clear_selection()


func _clear_character_selection() -> void:
	if is_instance_valid(selected_character):
		selected_character.set_selected(false)

	selected_character = null
func _update_hover() -> void:
	var grid_system := get_tree().get_first_node_in_group(
		"grid_system"
	) as GridSystem

	if grid_system == null:
		return

	var camera := get_viewport().get_camera_3d()

	if camera == null:
		return

	var mouse_position := get_viewport().get_mouse_position()

	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)

	if abs(ray_direction.y) < 0.0001:
		grid_system.clear_hover()
		return

	var distance := -ray_origin.y / ray_direction.y

	if distance < 0.0:
		grid_system.clear_hover()
		return

	var world_position := ray_origin + ray_direction * distance
	var cell := grid_system.world_to_grid(world_position)

	if grid_system.is_inside_grid(cell):
		grid_system.set_hovered_cell(cell)
	else:
		grid_system.clear_hover()
