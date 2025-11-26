# deck.gd
# Manages multiple decks of cards with shuffling and reshuffle threshold
class_name Deck
extends RefCounted

#region Constants
const RESHUFFLE_THRESHOLD: float = 0.25  # Reshuffle when 25% cards remain
const DEFAULT_NUM_DECKS: int = 6  # Standard casino uses 6-8 decks
#endregion

#region Properties
var cards: Array[Dictionary] = []
var discard_pile: Array[Dictionary] = []
var num_decks: int = DEFAULT_NUM_DECKS
var initial_card_count: int = 0
#endregion

#region Initialization
func _init(deck_count: int = DEFAULT_NUM_DECKS) -> void:
	num_decks = deck_count
	_create_decks()
	shuffle()

func _create_decks() -> void:
	cards.clear()
	discard_pile.clear()
	
	for _deck_num in range(num_decks):
		for suit in GameManager.SUITS:
			for rank in GameManager.RANKS:
				cards.append({
					"rank": rank,
					"suit": suit
				})
	
	initial_card_count = cards.size()
	print("Created deck with %d cards (%d decks)" % [initial_card_count, num_decks])
#endregion

#region Shuffle
func shuffle() -> void:
	# Move discard pile back to deck
	cards.append_array(discard_pile)
	discard_pile.clear()
	
	# Fisher-Yates shuffle
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Dictionary = cards[i]
		cards[i] = cards[j]
		cards[j] = temp
	
	print("Deck shuffled. %d cards ready." % cards.size())

func needs_reshuffle() -> bool:
	var remaining_ratio: float = float(cards.size()) / float(initial_card_count)
	return remaining_ratio <= RESHUFFLE_THRESHOLD

func check_and_reshuffle() -> bool:
	if needs_reshuffle():
		shuffle()
		return true
	return false
#endregion

#region Drawing Cards
func draw() -> Dictionary:
	if cards.is_empty():
		shuffle()
	
	if cards.is_empty():
		push_error("No cards available to draw!")
		return {}
	
	return cards.pop_back()

func draw_multiple(count: int) -> Array[Dictionary]:
	var drawn: Array[Dictionary] = []
	for _i in range(count):
		var card: Dictionary = draw()
		if not card.is_empty():
			drawn.append(card)
	return drawn

func peek() -> Dictionary:
	if cards.is_empty():
		return {}
	return cards.back()
#endregion

#region Discard
func discard(card: Dictionary) -> void:
	discard_pile.append(card)

func discard_multiple(card_array: Array) -> void:
	for card: Dictionary in card_array:
		discard_pile.append(card)
#endregion

#region Info
func get_remaining_count() -> int:
	return cards.size()

func get_discard_count() -> int:
	return discard_pile.size()

func get_total_count() -> int:
	return cards.size() + discard_pile.size()

func get_remaining_ratio() -> float:
	return float(cards.size()) / float(initial_card_count)
#endregion
