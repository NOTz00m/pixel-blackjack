# blackjack_game.gd
# Core blackjack game logic - manages game state, dealer AI, and round flow
class_name BlackjackGame
extends Node

#region Signals
signal game_started
signal cards_dealt
signal player_turn_started
signal dealer_turn_started
signal dealer_card_drawn(card: Dictionary)
signal hand_resolved(result: String, payout: int)
signal round_ended
signal insurance_offered
signal split_occurred
signal can_surrender(allowed: bool)
#endregion

#region Enums
enum GameState {
	BETTING,
	DEALING,
	PLAYER_TURN,
	SPLIT_TURN,  # When playing split hands
	DEALER_TURN,
	RESOLVING,
	ROUND_END
}
#endregion

#region Constants
const DEALER_HIT_THRESHOLD: int = 16  # Dealer hits on 16 or less
const DEALER_STAND_THRESHOLD: int = 17  # Dealer stands on 17+
const DEALER_CARD_DELAY: float = 0.8  # Delay between dealer draws
#endregion

#region Game State
var current_state: GameState = GameState.BETTING
var deck: Deck
var player_hands: Array[Hand] = []
var dealer_hand: Hand
var active_hand_index: int = 0
var insurance_available: bool = false
var surrender_available: bool = false
var first_action: bool = true  # Track if player has taken any action
#endregion

#region Node References
@onready var card_scene: PackedScene = preload("res://scenes/game/card.tscn")
#endregion

#region Lifecycle
func _ready() -> void:
	deck = Deck.new()
	dealer_hand = Hand.new()
#endregion

#region Game Flow
func start_new_round() -> void:
	# Check for reshuffle
	deck.check_and_reshuffle()
	
	# Reset state
	current_state = GameState.BETTING
	player_hands.clear()
	dealer_hand.clear()
	active_hand_index = 0
	insurance_available = false
	surrender_available = true
	first_action = true
	
	game_started.emit()

func deal_initial_cards() -> void:
	if GameManager.current_bet <= 0:
		push_error("Cannot deal without a bet placed!")
		return
	
	current_state = GameState.DEALING
	
	# Create player's initial hand
	var player_hand: Hand = Hand.new()
	player_hand.bet = GameManager.current_bet
	player_hands.append(player_hand)
	
	# Deal cards (player, dealer, player, dealer - face up except dealer's second)
	player_hands[0].add_card(deck.draw())
	dealer_hand.add_card(deck.draw())
	player_hands[0].add_card(deck.draw())
	dealer_hand.add_card(deck.draw())  # This will be face down initially
	
	cards_dealt.emit()
	
	# Check for insurance opportunity (dealer shows ace)
	if dealer_hand.cards[0].rank.to_lower() == "ace":
		insurance_available = true
		insurance_offered.emit()
	
	# Check for immediate blackjacks
	await get_tree().create_timer(0.5).timeout
	
	if _check_initial_blackjacks():
		return
	
	# Start player turn
	_start_player_turn()

func _check_initial_blackjacks() -> bool:
	var player_bj: bool = player_hands[0].is_blackjack()
	var dealer_bj: bool = dealer_hand.is_blackjack()
	
	if player_bj and dealer_bj:
		# Both have blackjack - push
		current_state = GameState.RESOLVING
		GameManager.process_push()
		hand_resolved.emit("push", GameManager.current_bet)
		_end_round()
		return true
	elif dealer_bj:
		# Dealer has blackjack - player loses (unless they took insurance)
		current_state = GameState.RESOLVING
		if GameManager.insurance_bet > 0:
			GameManager.process_insurance_win()
		GameManager.process_loss()
		hand_resolved.emit("dealer_blackjack", 0)
		_end_round()
		return true
	elif player_bj:
		# Player has blackjack - win 3:2
		current_state = GameState.RESOLVING
		if GameManager.insurance_bet > 0:
			GameManager.process_insurance_loss()
		var payout: int = GameManager.process_win(true)
		hand_resolved.emit("blackjack", payout)
		_end_round()
		return true
	
	# No blackjacks, but insurance might have been lost
	if GameManager.insurance_bet > 0:
		GameManager.process_insurance_loss()
	
	return false

func _start_player_turn() -> void:
	current_state = GameState.PLAYER_TURN
	surrender_available = true
	first_action = true
	can_surrender.emit(true)
	player_turn_started.emit()

func _start_dealer_turn() -> void:
	current_state = GameState.DEALER_TURN
	dealer_turn_started.emit()
	
	# Reveal dealer's hole card
	await get_tree().create_timer(0.3).timeout
	
	# Dealer draws according to house rules
	await _dealer_play()
	
	# Resolve all hands
	_resolve_hands()
#endregion

#region Player Actions
func hit() -> Dictionary:
	if current_state != GameState.PLAYER_TURN and current_state != GameState.SPLIT_TURN:
		return {}
	
	first_action = false
	surrender_available = false
	can_surrender.emit(false)
	
	var current_hand: Hand = player_hands[active_hand_index]
	var new_card: Dictionary = deck.draw()
	current_hand.add_card(new_card)
	
	# Check for bust or 21 after a delay (handled by caller)
	# The game_table.gd will check the state after animation
	
	return new_card

func check_player_hand_state() -> void:
	# Called after card animation completes
	var current_hand: Hand = player_hands[active_hand_index]
	
	if current_hand.is_bust():
		_on_hand_complete()
	elif current_hand.is_21():
		stand()

func stand() -> void:
	if current_state != GameState.PLAYER_TURN and current_state != GameState.SPLIT_TURN:
		return
	
	var current_hand: Hand = player_hands[active_hand_index]
	current_hand.is_standing = true
	
	_on_hand_complete()

func double_down() -> Dictionary:
	if current_state != GameState.PLAYER_TURN and current_state != GameState.SPLIT_TURN:
		return {}
	
	var current_hand: Hand = player_hands[active_hand_index]
	
	# Can only double on first two cards
	if current_hand.get_card_count() != 2:
		return {}
	
	if not GameManager.can_double_down():
		return {}
	
	# Double the bet
	GameManager.double_bet()
	current_hand.is_doubled = true
	
	first_action = false
	surrender_available = false
	can_surrender.emit(false)
	
	# Draw exactly one more card
	var new_card: Dictionary = deck.draw()
	current_hand.add_card(new_card)
	
	# Mark for standing (will be completed by caller after animation)
	current_hand.is_standing = true
	
	return new_card

func complete_double_down() -> void:
	# Called after card animation completes for double down
	_on_hand_complete()

func split() -> bool:
	if current_state != GameState.PLAYER_TURN and current_state != GameState.SPLIT_TURN:
		return false
	
	var current_hand: Hand = player_hands[active_hand_index]
	
	if not current_hand.can_split():
		return false
	
	if not GameManager.can_split():
		return false
	
	# Deduct additional bet for split hand
	GameManager.player_balance -= current_hand.bet
	
	# Create new hand from split
	var new_hand: Hand = current_hand.split()
	player_hands.insert(active_hand_index + 1, new_hand)
	
	# Deal new card to each hand
	current_hand.add_card(deck.draw())
	new_hand.add_card(deck.draw())
	
	first_action = false
	surrender_available = false
	can_surrender.emit(false)
	
	current_state = GameState.SPLIT_TURN
	split_occurred.emit()
	
	return true

func surrender() -> bool:
	if not surrender_available or not first_action:
		return false
	
	if current_state != GameState.PLAYER_TURN:
		return false
	
	var current_hand: Hand = player_hands[active_hand_index]
	current_hand.is_surrendered = true
	
	GameManager.process_surrender()
	hand_resolved.emit("surrender", GameManager.current_bet / 2)
	
	_end_round()
	return true

func take_insurance() -> bool:
	if not insurance_available:
		return false
	
	if not GameManager.place_insurance():
		return false
	
	insurance_available = false
	return true

func decline_insurance() -> void:
	insurance_available = false
#endregion

#region Hand Resolution
func _on_hand_complete() -> void:
	var current_hand: Hand = player_hands[active_hand_index]
	
	# Check if there are more hands to play (splits)
	if active_hand_index < player_hands.size() - 1:
		active_hand_index += 1
		player_turn_started.emit()
	else:
		# All hands complete, check if we need dealer turn
		var any_hand_active: bool = false
		for hand: Hand in player_hands:
			if not hand.is_bust() and not hand.is_surrendered:
				any_hand_active = true
				break
		
		if any_hand_active:
			_start_dealer_turn()
		else:
			# All hands busted or surrendered
			for hand: Hand in player_hands:
				if hand.is_bust():
					GameManager.process_loss()
					hand_resolved.emit("bust", 0)
			_end_round()

func _dealer_play() -> void:
	# Dealer reveals hole card and plays according to house rules
	# Dealer hits on 16 or less, stands on 17+
	
	while dealer_hand.get_value() <= DEALER_HIT_THRESHOLD:
		await get_tree().create_timer(DEALER_CARD_DELAY).timeout
		var new_card: Dictionary = deck.draw()
		dealer_hand.add_card(new_card)
		dealer_card_drawn.emit(new_card)
	
	# Some casinos have dealer hit on soft 17 - we use stand on all 17
	await get_tree().create_timer(0.3).timeout

func _resolve_hands() -> void:
	current_state = GameState.RESOLVING
	var dealer_value: int = dealer_hand.get_value()
	var dealer_bust: bool = dealer_hand.is_bust()
	
	for i in range(player_hands.size()):
		var hand: Hand = player_hands[i]
		
		# Skip busted or surrendered hands (already resolved)
		if hand.is_bust() or hand.is_surrendered:
			continue
		
		var player_value: int = hand.get_value()
		var payout: int = 0
		
		# Calculate individual hand bet (might be doubled)
		var hand_bet: int = hand.bet
		if hand.is_doubled:
			hand_bet *= 2
		
		if dealer_bust:
			# Dealer busted, player wins
			payout = hand_bet * 2
			GameManager.player_balance += payout
			hand_resolved.emit("win", payout)
		elif player_value > dealer_value:
			# Player wins
			payout = hand_bet * 2
			GameManager.player_balance += payout
			hand_resolved.emit("win", payout)
		elif player_value < dealer_value:
			# Dealer wins
			hand_resolved.emit("loss", 0)
		else:
			# Push - return bet
			payout = hand_bet
			GameManager.player_balance += payout
			hand_resolved.emit("push", payout)
	
	# Update stats
	GameManager.stats.games_played += 1
	SaveManager.save_game()
	
	_end_round()

func _end_round() -> void:
	current_state = GameState.ROUND_END
	
	# Discard all cards
	for hand: Hand in player_hands:
		deck.discard_multiple(hand.cards)
	deck.discard_multiple(dealer_hand.cards)
	
	round_ended.emit()
#endregion

#region Getters
func get_current_hand() -> Hand:
	if player_hands.is_empty():
		return null
	return player_hands[active_hand_index]

func get_player_value() -> int:
	var hand: Hand = get_current_hand()
	return hand.get_value() if hand else 0

func get_dealer_value(show_all: bool = false) -> int:
	if show_all or current_state >= GameState.DEALER_TURN:
		return dealer_hand.get_value()
	else:
		# Only show first card value
		if dealer_hand.cards.size() > 0:
			return GameManager.get_card_value(dealer_hand.cards[0].rank)
		return 0

func can_player_hit() -> bool:
	var hand: Hand = get_current_hand()
	if not hand:
		return false
	return hand.can_hit() and (current_state == GameState.PLAYER_TURN or current_state == GameState.SPLIT_TURN)

func can_player_stand() -> bool:
	return current_state == GameState.PLAYER_TURN or current_state == GameState.SPLIT_TURN

func can_player_double() -> bool:
	var hand: Hand = get_current_hand()
	if not hand:
		return false
	return hand.get_card_count() == 2 and GameManager.can_double_down() and (current_state == GameState.PLAYER_TURN or current_state == GameState.SPLIT_TURN)

func can_player_split() -> bool:
	var hand: Hand = get_current_hand()
	if not hand:
		return false
	return hand.can_split() and GameManager.can_split() and (current_state == GameState.PLAYER_TURN or current_state == GameState.SPLIT_TURN)

func can_player_surrender() -> bool:
	return surrender_available and first_action and current_state == GameState.PLAYER_TURN
#endregion
