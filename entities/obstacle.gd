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
	
	await get_tree().physics_frame
	
	print(
		"ObstacleEntity: célula bloqueada = ",
		grid_position
	)

	var space_state := get_world_3d().direct_space_state

	var test_query := PhysicsRayQueryParameters3D.create(
		Vector3(0.761999, 2.0, -6.858),
		Vector3(0.761999, -1.0, -6.858)
	)

	test_query.collide_with_bodies = true
	test_query.collide_with_areas = false

	var test_result := space_state.intersect_ray(test_query)

	var test_collider := test_result.get("collider") as Object

	print(
		"Obstacle Physics Ray Test | collider=%s | path=%s | position=%s"
		% [
			str(test_collider),
			str(test_collider.get_path())
				if test_collider is Node
				else "not_node",
			str(test_result.get("position"))
		]
	)

	var horizontal_query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(-2.0, 0.60, 0.0),
		global_position + Vector3(2.0, 0.60, 0.0)
	)

	horizontal_query.collide_with_bodies = true
	horizontal_query.collide_with_areas = false

	var horizontal_result := space_state.intersect_ray(horizontal_query)

	var horizontal_collider := horizontal_result.get("collider") as Object

	print(
		"Obstacle Horizontal Ray Test | collider=%s | path=%s | position=%s"
		% [
			str(horizontal_collider),
			str(horizontal_collider.get_path())
				if horizontal_collider is Node
				else "not_node",
			str(horizontal_result.get("position"))
		]
	)

	var static_body := get_node_or_null("StaticBody3D") as StaticBody3D

	if static_body != null:
		print(
			"Obstacle Physics Debug | body=%s | global_position=%s | collision_layer=%d | collision_mask=%d"
			% [
				static_body.name,
				str(static_body.global_position),
				static_body.collision_layer,
				static_body.collision_mask
			]
		)

		var collision_shape := static_body.get_node_or_null(
			"CollisionShape3D"
		) as CollisionShape3D

		if collision_shape != null:
			print(
				"Obstacle Shape Debug | shape=%s | global_position=%s | disabled=%s"
				% [
					str(collision_shape.shape),
					str(collision_shape.global_position),
					str(collision_shape.disabled)
				]
			)
			
			print(
				"Obstacle Transform Debug | body_transform=%s | shape_transform=%s"
				% [
					str(static_body.global_transform),
					str(collision_shape.global_transform)
				]
			)
