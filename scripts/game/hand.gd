# hand.gd
# Represents a player or dealer hand with cards and calculated value
class_name Hand
extends RefCounted

#region Properties
var cards: Array[Dictionary] = []
var bet: int = 0
var is_split_hand: bool = false
var is_doubled: bool = false
var is_standing: bool = false
var is_surrendered: bool = false
#endregion

#region Card Management
func add_card(card: Dictionary) -> void:
	cards.append(card)

func get_cards() -> Array[Dictionary]:
	return cards

func get_card_count() -> int:
	return cards.size()

func clear() -> void:
	cards.clear()
	bet = 0
	is_split_hand = false
	is_doubled = false
	is_standing = false
	is_surrendered = false
#endregion

#region Value Calculation
func get_value() -> int:
	return GameManager.calculate_hand_value(cards)

func is_bust() -> bool:
	return get_value() > 21

func is_blackjack() -> bool:
	return cards.size() == 2 and get_value() == 21 and not is_split_hand

func is_soft() -> bool:
	return GameManager.is_soft_hand(cards)

func is_21() -> bool:
	return get_value() == 21

func can_hit() -> bool:
	return not is_standing and not is_bust() and not is_21()
#endregion

#region Split
func can_split() -> bool:
	if cards.size() != 2 or is_split_hand:
		return false
	return GameManager.get_card_value(cards[0].rank) == GameManager.get_card_value(cards[1].rank)

func split() -> Hand:
	if not can_split():
		return null
	
	var new_hand: Hand = Hand.new()
	new_hand.is_split_hand = true
	new_hand.bet = bet
	new_hand.add_card(cards.pop_back())
	
	is_split_hand = true
	
	return new_hand
#endregion

#region Display
func _to_string() -> String:
	var card_strings: Array[String] = []
	for card: Dictionary in cards:
		card_strings.append("%s of %s" % [card.rank, card.suit])
	return ", ".join(card_strings) + " (Value: %d)" % get_value()

func get_value_string() -> String:
	var value: int = get_value()
	if is_soft() and value <= 21:
		# Show both possible values for soft hands
		var hard_value: int = value - 10
		return "%d/%d" % [hard_value, value]
	return str(value)
#endregion
