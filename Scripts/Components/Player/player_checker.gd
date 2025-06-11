extends Area3D
class_name PlayerScanner
@export var room_id: String

var delay : int = 10
var check_for_bodies: bool = false
signal player_in_room(id:String)

func _ready() -> void:
	self.body_entered.connect(_on_body_entered)
	self.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if check_for_bodies:
		delay = delay -1
		if delay > 0: 
			for body in get_overlapping_bodies():
				if body is Player: 
					player_in_room.emit(room_id)
		else: 
			delay = 10 
		

func _on_body_entered(body: Node) -> void:
	check_for_bodies = true

func _on_body_exited(body: Node) -> void:
	check_for_bodies = false
