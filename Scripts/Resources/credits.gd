# CreditsResource.gd
extends Resource
class_name CreditsResource

## Individual credit entries
@export var credits_entries: Array[CreditEntry] = []

## Auto-scroll speed in pixels per second
@export var scroll_speed: float = 30.0
