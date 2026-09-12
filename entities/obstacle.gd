extends Node3D
class_name ObstacleEntity

@export var grid_position: Vector2i = Vector2i(13, 8)


func _ready() -> void:
	call_deferred("_register_obstacle")


func _register_obstacle() -> void:
	var grid_system := get_tree().get_first_node_in_group(
		"grid_system"
	) as GridSystem

	if grid_system == null:
		push_error("ObstacleEntity: GridSystem not found.")
		return

	if not grid_system.is_inside_grid(grid_position):
		push_error(
			"ObstacleEntity: grid position is outside grid: "
			+ str(grid_position)
		)
		return

	grid_system.set_cell_blocked(grid_position, true)

	global_position = grid_system.grid_to_world(grid_position)

	print(
		"ObstacleEntity: célula bloqueada = ",
		grid_position
	)
