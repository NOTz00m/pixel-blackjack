# game_table.gd
# Main game table scene - handles visual display and user interaction
extends Node2D

#region Signals
signal betting_complete
signal action_selected(action: String)
#endregion

#region Constants
const CARD_SPACING: int = 25
const PLAYER_HAND_Y: int = 400
const DEALER_HAND_Y: int = 120
const DECK_POSITION: Vector2 = Vector2(600, 100)
const ANIMATION_SPEED: float = 0.3
#endregion

#region Node References
@onready var blackjack_game: BlackjackGame = $BlackjackGame
@onready var player_cards_container: Node2D = $PlayerCards
@onready var dealer_cards_container: Node2D = $DealerCards
@onready var bet_display: Label = $UI/BetDisplay
@onready var balance_display: Label = $UI/BalanceDisplay
@onready var message_label: Label = $UI/MessageLabel
@onready var player_value_label: Label = $UI/PlayerValueLabel
@onready var dealer_value_label: Label = $UI/DealerValueLabel

# Action buttons
@onready var hit_button: Button = $UI/ActionButtons/HitButton
@onready var stand_button: Button = $UI/ActionButtons/StandButton
@onready var double_button: Button = $UI/ActionButtons/DoubleButton
@onready var split_button: Button = $UI/ActionButtons/SplitButton
@onready var surrender_button: Button = $UI/ActionButtons/SurrenderButton

# Betting controls
@onready var bet_container: Control = $UI/BetContainer
@onready var chip_buttons: HBoxContainer = $UI/BetContainer/ChipButtons
@onready var deal_button: Button = $UI/BetContainer/ButtonContainer/DealButton
@onready var clear_bet_button: Button = $UI/BetContainer/ButtonContainer/ClearBetButton
@onready var current_bet_label: Label = $UI/BetContainer/CurrentBetLabel

# Insurance dialog
@onready var insurance_dialog: Control = $UI/InsuranceDialog
@onready var insurance_yes_button: Button = $UI/InsuranceDialog/Panel/VBox/HBox/YesButton
@onready var insurance_no_button: Button = $UI/InsuranceDialog/Panel/VBox/HBox/NoButton

# Back button
@onready var back_button: Button = $UI/BackButton
#endregion

#region State
var card_scene: PackedScene = preload("res://scenes/game/card.tscn")
var player_card_nodes: Array[Node2D] = []
var dealer_card_nodes: Array[Node2D] = []
var current_bet_amount: int = 0
var is_animating: bool = false
#endregion

#region Lifecycle
func _ready() -> void:
	_connect_signals()
	_update_displays()
	_setup_chip_buttons()
	_show_betting_phase()

func _connect_signals() -> void:
	# Game signals
	blackjack_game.game_started.connect(_on_game_started)
	blackjack_game.cards_dealt.connect(_on_cards_dealt)
	blackjack_game.player_turn_started.connect(_on_player_turn_started)
	blackjack_game.dealer_turn_started.connect(_on_dealer_turn_started)
	blackjack_game.hand_resolved.connect(_on_hand_resolved)
	blackjack_game.round_ended.connect(_on_round_ended)
	blackjack_game.insurance_offered.connect(_on_insurance_offered)
	blackjack_game.can_surrender.connect(_on_can_surrender)
	
	# Balance updates
	GameManager.balance_changed.connect(_on_balance_changed)
	
	# Action buttons
	hit_button.pressed.connect(_on_hit_pressed)
	stand_button.pressed.connect(_on_stand_pressed)
	double_button.pressed.connect(_on_double_pressed)
	split_button.pressed.connect(_on_split_pressed)
	surrender_button.pressed.connect(_on_surrender_pressed)
	
	# Betting controls
	deal_button.pressed.connect(_on_deal_pressed)
	clear_bet_button.pressed.connect(_on_clear_bet_pressed)
	
	# Insurance
	insurance_yes_button.pressed.connect(_on_insurance_yes)
	insurance_no_button.pressed.connect(_on_insurance_no)
	
	# Back button
	back_button.pressed.connect(_on_back_pressed)
#endregion

#region Betting Phase
func _show_betting_phase() -> void:
	bet_container.visible = true
	_hide_action_buttons()
	insurance_dialog.visible = false
	message_label.text = "Place your bet!"
	_update_bet_display()
	_update_deal_button()

func _setup_chip_buttons() -> void:
	var chip_values: Array[int] = [1, 5, 10, 25, 50, 100, 500]
	
	for child in chip_buttons.get_children():
		child.queue_free()
	
	for value: int in chip_values:
		var button: Button = Button.new()
		button.text = "$%d" % value
		button.custom_minimum_size = Vector2(60, 40)
		button.pressed.connect(_on_chip_pressed.bind(value))
		chip_buttons.add_child(button)

func _on_chip_pressed(value: int) -> void:
	var table_config: Dictionary = GameManager.get_table_config()
	var new_bet: int = current_bet_amount + value
	
	# Check against table max and player balance
	if new_bet <= table_config.max_bet and new_bet <= GameManager.player_balance:
		current_bet_amount = new_bet
		_update_bet_display()
		_update_deal_button()
		_animate_chip_add()

func _on_clear_bet_pressed() -> void:
	current_bet_amount = 0
	_update_bet_display()
	_update_deal_button()

func _on_deal_pressed() -> void:
	var table_config: Dictionary = GameManager.get_table_config()
	
	if current_bet_amount < table_config.min_bet:
		message_label.text = "Minimum bet is $%d" % table_config.min_bet
		return
	
	if current_bet_amount > GameManager.player_balance:
		message_label.text = "Insufficient balance!"
		return
	
	# Place the bet and start the game
	if GameManager.place_bet(current_bet_amount):
		bet_container.visible = false
		current_bet_amount = 0
		blackjack_game.start_new_round()
		await get_tree().create_timer(0.2).timeout
		blackjack_game.deal_initial_cards()

func _update_bet_display() -> void:
	current_bet_label.text = "Bet: $%d" % current_bet_amount
	bet_display.text = "Bet: $%d" % GameManager.current_bet

func _update_deal_button() -> void:
	var table_config: Dictionary = GameManager.get_table_config()
	deal_button.disabled = current_bet_amount < table_config.min_bet or current_bet_amount > GameManager.player_balance

func _animate_chip_add() -> void:
	# Simple scale animation for feedback
	var tween: Tween = create_tween()
	tween.tween_property(current_bet_label, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(current_bet_label, "scale", Vector2.ONE, 0.1)
#endregion

#region Game Display
func _on_game_started() -> void:
	_clear_cards()
	message_label.text = ""
	_update_displays()

func _on_cards_dealt() -> void:
	await _deal_initial_cards_animation()
	_update_value_labels()

func _deal_initial_cards_animation() -> void:
	is_animating = true
	
	var player_hand: Hand = blackjack_game.player_hands[0]
	var dealer_cards: Array = blackjack_game.dealer_hand.cards
	
	# Deal cards one by one with animation
	# Player first card
	await _create_and_deal_card(player_hand.cards[0], true, true, 0)
	
	# Dealer first card (face up)
	await _create_and_deal_card(dealer_cards[0], false, true, 0)
	
	# Player second card
	await _create_and_deal_card(player_hand.cards[1], true, true, 1)
	
	# Dealer second card (face down)
	await _create_and_deal_card(dealer_cards[1], false, false, 1)
	
	is_animating = false

func _create_and_deal_card(card_data: Dictionary, is_player: bool, face_up: bool, index: int) -> void:
	var card_node: Node2D = card_scene.instantiate()
	var container: Node2D = player_cards_container if is_player else dealer_cards_container
	container.add_child(card_node)
	
	# Setup card
	card_node.setup(card_data.rank, card_data.suit, face_up)
	
	# Calculate target position
	var base_x: float = 320 - (CARD_SPACING * 1.5)  # Center cards
	var target_pos: Vector2 = Vector2(base_x + index * CARD_SPACING, 0)
	
	# Store reference
	if is_player:
		player_card_nodes.append(card_node)
	else:
		dealer_card_nodes.append(card_node)
	
	# Animate dealing
	card_node.deal_to(target_pos, DECK_POSITION - container.global_position, index * 0.1)
	await get_tree().create_timer(0.3).timeout

func _on_player_turn_started() -> void:
	message_label.text = "Your turn!"
	_show_action_buttons()
	_update_button_states()

func _on_dealer_turn_started() -> void:
	message_label.text = "Dealer's turn..."
	_hide_action_buttons()
	
	# Flip dealer's hole card
	if dealer_card_nodes.size() > 1:
		var hole_card: Node2D = dealer_card_nodes[1]
		hole_card.flip(true)
		await get_tree().create_timer(0.5).timeout
	
	_update_value_labels()
	
	# Watch dealer draw cards
	var initial_dealer_cards: int = dealer_card_nodes.size()
	while blackjack_game.dealer_hand.cards.size() > dealer_card_nodes.size():
		var card_index: int = dealer_card_nodes.size()
		var card_data: Dictionary = blackjack_game.dealer_hand.cards[card_index]
		await _create_and_deal_card(card_data, false, true, card_index)
		_update_value_labels()
		await get_tree().create_timer(0.5).timeout

func _on_hand_resolved(result: String, payout: int) -> void:
	match result:
		"blackjack":
			message_label.text = "BLACKJACK! You win $%d!" % payout
			_play_win_animation()
		"win":
			message_label.text = "You win $%d!" % payout
			_play_win_animation()
		"loss", "dealer_blackjack":
			message_label.text = "You lose!"
			_play_lose_animation()
		"push":
			message_label.text = "Push - Bet returned"
		"bust":
			message_label.text = "Bust! You lose!"
			_play_lose_animation()
		"surrender":
			message_label.text = "Surrendered - $%d returned" % payout

func _on_round_ended() -> void:
	_hide_action_buttons()
	_update_displays()
	
	# Show "New Game" prompt after delay
	await get_tree().create_timer(2.0).timeout
	_show_betting_phase()

func _on_insurance_offered() -> void:
	insurance_dialog.visible = true
	_hide_action_buttons()

func _on_insurance_yes() -> void:
	insurance_dialog.visible = false
	if blackjack_game.take_insurance():
		message_label.text = "Insurance taken!"
	_update_displays()

func _on_insurance_no() -> void:
	insurance_dialog.visible = false
	blackjack_game.decline_insurance()

func _on_can_surrender(allowed: bool) -> void:
	surrender_button.visible = allowed
#endregion

#region Action Handlers
func _on_hit_pressed() -> void:
	if is_animating:
		return
	
	var new_card: Dictionary = blackjack_game.hit()
	if new_card.is_empty():
		return
	
	# Add new card to display
	var card_index: int = player_card_nodes.size()
	await _create_and_deal_card(new_card, true, true, card_index)
	_update_value_labels()
	_update_button_states()

func _on_stand_pressed() -> void:
	if is_animating:
		return
	blackjack_game.stand()

func _on_double_pressed() -> void:
	if is_animating:
		return
	
	var new_card: Dictionary = blackjack_game.double_down()
	if new_card.is_empty():
		return
	
	_update_displays()
	var card_index: int = player_card_nodes.size()
	await _create_and_deal_card(new_card, true, true, card_index)
	_update_value_labels()

func _on_split_pressed() -> void:
	if is_animating:
		return
	
	if blackjack_game.split():
		# TODO: Implement split hand display
		message_label.text = "Hand split!"
		_update_displays()
		_update_button_states()

func _on_surrender_pressed() -> void:
	if is_animating:
		return
	blackjack_game.surrender()
#endregion

#region UI Helpers
func _show_action_buttons() -> void:
	hit_button.visible = true
	stand_button.visible = true
	double_button.visible = true
	split_button.visible = true
	surrender_button.visible = blackjack_game.can_player_surrender()

func _hide_action_buttons() -> void:
	hit_button.visible = false
	stand_button.visible = false
	double_button.visible = false
	split_button.visible = false
	surrender_button.visible = false

func _update_button_states() -> void:
	hit_button.disabled = not blackjack_game.can_player_hit()
	stand_button.disabled = not blackjack_game.can_player_stand()
	double_button.disabled = not blackjack_game.can_player_double()
	split_button.disabled = not blackjack_game.can_player_split()
	surrender_button.disabled = not blackjack_game.can_player_surrender()

func _update_displays() -> void:
	balance_display.text = "Balance: $%d" % GameManager.player_balance
	bet_display.text = "Bet: $%d" % GameManager.current_bet

func _update_value_labels() -> void:
	var player_hand: Hand = blackjack_game.get_current_hand()
	if player_hand:
		player_value_label.text = player_hand.get_value_string()
		if player_hand.is_bust():
			player_value_label.modulate = Color.RED
		elif player_hand.is_blackjack():
			player_value_label.modulate = Color.GOLD
		else:
			player_value_label.modulate = Color.WHITE
	else:
		player_value_label.text = ""
	
	# Show dealer value based on game state
	if blackjack_game.current_state >= BlackjackGame.GameState.DEALER_TURN:
		dealer_value_label.text = str(blackjack_game.dealer_hand.get_value())
		if blackjack_game.dealer_hand.is_bust():
			dealer_value_label.modulate = Color.RED
		else:
			dealer_value_label.modulate = Color.WHITE
	else:
		# Only show visible card value
		dealer_value_label.text = str(blackjack_game.get_dealer_value(false))

func _on_balance_changed(_new_balance: int) -> void:
	_update_displays()

func _clear_cards() -> void:
	for card in player_card_nodes:
		card.queue_free()
	for card in dealer_card_nodes:
		card.queue_free()
	
	player_card_nodes.clear()
	dealer_card_nodes.clear()
#endregion

#region Animations
func _play_win_animation() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(message_label, "modulate", Color.GREEN, 0.2)
	tween.tween_property(message_label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(message_label, "scale", Vector2.ONE, 0.2)
	
	# Highlight winning cards
	for card in player_card_nodes:
		card.highlight(true)
	
	await get_tree().create_timer(1.0).timeout
	message_label.modulate = Color.WHITE
	for card in player_card_nodes:
		card.highlight(false)

func _play_lose_animation() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(message_label, "modulate", Color.RED, 0.2)
	
	# Shake player cards
	for card in player_card_nodes:
		card.shake()
	
	await get_tree().create_timer(1.0).timeout
	message_label.modulate = Color.WHITE
#endregion

#region Navigation
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
#endregion
