class_name GroundEnemy
extends Enemy

# Ground enemy overrides (no hovering)

@onready var hurtbox: Node2D = $Hurtbox

func _ready() -> void:
	float_height = 0.0
	bob_amplitude = 0.0
	super._ready()
	if hurtbox and hurtbox.has_method("set"):
		hurtbox.set("z_offset", 6.0)

func _try_contact_damage(player: Node2D) -> void:
	if contact_timer > 0.0:
		return
	if not player or not player.has_method("get_world_pos"):
		return
	if player.has_method("get"):
		var homing: bool = player.get("is_homing") == true
		if homing:
			return
	var p_pos: Vector3 = player.get_world_pos()
	var dist := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y).length()
	if dist <= 0.8:
		var dir := Vector2(p_pos.x - world_pos.x, p_pos.y - world_pos.y)
		if player.has_method("take_damage"):
			player.take_damage(contact_damage, dir)
		contact_timer = contact_cooldown

func _setup_placeholder_sprites() -> void:
	# Yellow/blue variant
	if sprite and sprite.texture == null:
		var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
		var center := Vector2(7, 7)
		
		for y in range(14):
			for x in range(14):
				var pos := Vector2(x, y)
				var dist := pos.distance_to(center)
				
				if dist <= 5.0:
					var shade: float = 1.0 - (pos.x + pos.y - 7) * 0.04
					img.set_pixel(x, y, Color(0.9 * shade, 0.8 * shade, 0.2 * shade))
				elif (x == 7 and (y <= 2 or y >= 12)) or (y == 7 and (x <= 2 or x >= 12)):
					img.set_pixel(x, y, Color(0.2, 0.4, 0.9))
				elif abs(x - 7) == abs(y - 7) and dist >= 5.0 and dist <= 8.0:
					img.set_pixel(x, y, Color(0.2, 0.4, 0.9))
		
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex
		sprite.offset = Vector2(0, -7)
	
	# Create shadow sprite
	if shadow and shadow.texture == null:
		var img := Image.create(10, 5, false, Image.FORMAT_RGBA8)
		for y in range(5):
			for x in range(10):
				var cx := x - 5
				var cy := y - 2.5
				if (cx * cx) / 25.0 + (cy * cy) / 6.25 <= 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0.5))
		
		var tex := ImageTexture.create_from_image(img)
		shadow.texture = tex
