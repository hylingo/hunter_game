extends StaticBody3D

func take_damage(amount: float) -> void:
	print("Dummy took ", amount, " damage")
	queue_free()
