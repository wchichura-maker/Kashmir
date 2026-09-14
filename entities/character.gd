extends Node3D
class_name CharacterEntity

@export_category("Grid")
@export var grid_position: Vector2i = Vector2i(13, 13)
@export_category("Combat")
@export_enum("Ally", "Enemy") var faction: String = "Ally"
@export var is_alive: bool = true
@export var is_helpless: bool = false
@export var initiative_modifier: int = 0

@export_category("Perception")
@export var spot_modifier: int = 0
@export var listen_modifier: int = 0
@export var hide_modifier: int = 0
@export var move_silently_modifier: int = 0

@export var base_visual_dc: int = 10

@export_category("Movement")
@export var move_step_duration: float = 0.12

@export_category("Equipment")
@export var equipment_sound_enabled: bool = true
@export_enum("Silent", "Light", "Normal", "Heavy") var equipment_sound_level: String = "Normal"
@export var equipment_sound_dc: int = 5

@onready var visual: Node3D = $Visual

var world_position: Vector3
var is_selected: bool = false
var is_moving: bool = false
var movement_interrupted: bool = false

func interrupt_movement() -> void:
	if not is_moving:
		return

	movement_interrupted = true

var selection_visual: MeshInstance3D


func _ready() -> void:
	add_to_group("combatants")
	_create_selection_visual()
	call_deferred("_sync_from_grid")


func _sync_from_grid() -> void:
	var grid_system := get_tree().get_first_node_in_group("grid_system") as GridSystem

	if grid_system == null:
		push_error("CharacterEntity: GridSystem not found.")
		return

	if not grid_system.is_inside_grid(grid_position):
		push_error(
			"CharacterEntity: grid position is outside the grid: "
			+ str(grid_position)
		)
		return

	world_position = grid_system.grid_to_world(grid_position)
	global_position = world_position

	grid_system.set_cell_occupied(
		grid_position,
		self
	)


func move_along_path(path: Array[Vector2i]) -> bool:
	if is_moving:
		return false

	if path.is_empty():
		return false

	var grid_system := get_tree().get_first_node_in_group(
		"grid_system"
	) as GridSystem

	if grid_system == null:
		push_error("CharacterEntity: GridSystem not found during movement.")
		return false

	is_moving = true
	movement_interrupted = false

	# Guardamos se o personagem estava selecionado.
	var was_selected := is_selected

	# Esconde o círculo de seleção durante o movimento.
	if is_instance_valid(selection_visual):
		selection_visual.visible = false

	# A posição visual atual do personagem.


	for cell in path:
		if movement_interrupted:
			break

		var step_world := grid_system.grid_to_world(cell)
		var step_visual_world := step_world + Vector3(0.0, 0.60, 0.0)

		# Atualiza a posição lógica somente para a célula
		# que está sendo alcançada agora.
		grid_system.clear_cell_occupied(grid_position)

		grid_position = cell
		world_position = step_world

		grid_system.set_cell_occupied(
			grid_position,
			self
		)

		# O corpo lógico acompanha a célula atual.
		global_position = step_world

		# Cria um Tween somente para esta célula.
		var tween := create_tween()

		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)

		tween.tween_property(
			visual,
			"global_position",
			step_visual_world,
			move_step_duration
		)

		# Som do passo.
		var sound_system := get_tree().get_first_node_in_group(
			"sound_system"
		) as SoundSystem

		if sound_system != null:
			var movement_profile := sound_system.create_movement_sound_profile(
				self
			)

			sound_system.create_sound_event_from_profile(
				self,
				SoundSystem.SoundCategory.FOOTSTEP,
				movement_profile,
				"Movimento"
			)

		await tween.finished

		if movement_interrupted:
			break

		# Avalia percepção visual após alcançar esta célula.
		var perception_system := get_tree().get_first_node_in_group(
			"perception_system"
		) as PerceptionSystem

		if perception_system != null:
			var characters := get_tree().get_nodes_in_group("combatants")

			for character_node in characters:
				var observer := character_node as CharacterEntity

				if observer == null:
					continue

				if observer == self:
					continue

				if not observer.is_alive:
					continue

				if perception_system.can_perceive_by_distance(
					observer,
					self
				):
					var threshold_reached := perception_system.add_visual_activity(
						observer,
						self,
						1
					)

					if threshold_reached:
						perception_system.check_visual_activity(
							observer,
							self
						)

						if movement_interrupted:
							break

		if movement_interrupted:
			break


	# Garante que o visual fique exatamente na última célula alcançada.
	visual.global_position = global_position + Vector3(0.0, 0.60, 0.0)

	var completed_normally := not movement_interrupted

	is_moving = false
	movement_interrupted = false

	if was_selected and is_instance_valid(selection_visual):
		selection_visual.visible = true

	return completed_normally


func set_selected(value: bool) -> void:
	is_selected = value

	if is_instance_valid(selection_visual):
		selection_visual.visible = value


func _create_selection_visual() -> void:
	selection_visual = MeshInstance3D.new()
	selection_visual.name = "Selection"

	var mesh := CylinderMesh.new()

	mesh.top_radius = 0.43
	mesh.bottom_radius = 0.43
	mesh.height = 0.025

	selection_visual.mesh = mesh

	var material := StandardMaterial3D.new()

	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.3, 0.7, 1.0, 0.45)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	selection_visual.material_override = material

	selection_visual.position = Vector3(0.0, 0.025, 0.0)
	selection_visual.visible = false

	add_child(selection_visual)
