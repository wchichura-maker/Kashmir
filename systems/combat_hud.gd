extends CanvasLayer

var turn_system: TurnSystem

@onready var turn_label: Label = $ActionPanel/Actions/TurnLabel
@onready var round_label: Label = $ActionPanel/Actions/RoundLabel

@onready var standard_status: Label = $ActionPanel/Actions/StandardStatus
@onready var move_status: Label = $ActionPanel/Actions/MoveStatus
@onready var full_round_status: Label = $ActionPanel/Actions/FullRoundStatus

@onready var standard_button: Button = $ActionPanel/Actions/StandardButton
@onready var move_button: Button = $ActionPanel/Actions/MoveButton
@onready var full_round_button: Button = $ActionPanel/Actions/FullRoundButton
@onready var end_turn_button: Button = $ActionPanel/Actions/EndTurnButton
@onready var second_move_confirmation: ConfirmationDialog = $SecondMoveConfirmation
@onready var dont_ask_again_check_box: CheckBox = $SecondMoveConfirmation/DontAskAgainCheckBox

var ask_before_second_move: bool = true

func _ready() -> void:
	add_to_group("combat_hud")
	
	turn_system = get_tree().get_first_node_in_group("turn_system") as TurnSystem

	if turn_system == null:
		push_error("CombatHUD: TurnSystem not found.")
		return

	turn_system.turn_started.connect(_on_turn_started)
	turn_system.round_started.connect(_on_round_started)
	turn_system.combat_ended.connect(_on_combat_ended)

	standard_button.pressed.connect(_on_standard_pressed)
	move_button.pressed.connect(_on_move_pressed)
	full_round_button.pressed.connect(_on_full_round_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	second_move_confirmation.confirmed.connect(_on_second_move_confirmed)
	dont_ask_again_check_box.button_pressed = false
	
	_update_hud()


func _process(_delta: float) -> void:
	_update_hud()


func _update_hud() -> void:
	if turn_system == null:
		return

	round_label.text = "ROUND: %d" % turn_system.round_number

	var character := turn_system.get_current_actor()

	if character == null:
		turn_label.text = "TURN: -"
		standard_status.text = "Standard: -"
		move_status.text = "Movement: -"
		full_round_status.text = "Full Round: -"

		standard_button.disabled = true
		move_button.disabled = true
		full_round_button.disabled = true
		end_turn_button.disabled = true

		return

	turn_label.text = "TURN: %s" % character.name

	var has_standard := turn_system.has_standard_action(character)
	var has_full_round := turn_system.has_full_round_action(character)
	var movement_remaining := turn_system.get_movement_remaining_feet(character)

	standard_status.text = "Standard: %s" % _available_text(has_standard)
	move_status.text = "Movement: %d ft" % movement_remaining
	full_round_status.text = "Full Round: %s" % _available_text(has_full_round)

	standard_button.disabled = not has_standard
	move_button.disabled = true
	full_round_button.disabled = not has_full_round

	end_turn_button.disabled = false

func _available_text(value: bool) -> String:
	if value:
		return "AVAILABLE"

	return "USED"


func _on_standard_pressed() -> void:
	var character := turn_system.get_current_actor()

	if character == null:
		return

	turn_system.use_standard_action(character)


func _on_move_pressed() -> void:
	var character := turn_system.get_current_actor()

	if character == null:
		return

	turn_system.use_move_action(character)


func _on_full_round_pressed() -> void:
	var character := turn_system.get_current_actor()

	if character == null:
		return

	turn_system.use_full_round_action(character)


func _on_end_turn_pressed() -> void:
	turn_system.end_turn()

func show_second_move_confirmation() -> void:
	if not ask_before_second_move:
		_on_second_move_confirmed()
		return
	second_move_confirmation.title = "Continuar movimento?"
	second_move_confirmation.dialog_text = "Continuar o movimento consumirá sua ação Standard."
	second_move_confirmation.ok_button_text = "Sim"
	second_move_confirmation.cancel_button_text = "Não"
	second_move_confirmation.popup_centered()

func _on_second_move_confirmed() -> void:
	var character := turn_system.get_current_actor()

	if character == null:
		return
		
	ask_before_second_move = not dont_ask_again_check_box.button_pressed
	
	turn_system.confirm_second_move(character)

func _on_turn_started(_character: CharacterEntity) -> void:
	_update_hud()


func _on_round_started(_round_number: int) -> void:
	_update_hud()


func _on_combat_ended() -> void:
	_update_hud()
