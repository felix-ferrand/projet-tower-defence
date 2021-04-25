extends Projectile
	
func _on_hit(other):
	if other.has_method("take_damage"): 
		other.heal(damage)
		queue_free()
