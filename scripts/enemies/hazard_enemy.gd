class_name HazardEnemy
extends Enemy

# Hazard enemy: flying spike target that punishes homing attacks.

func _ready() -> void:
	hazardous = true
	super._ready()

func _setup_placeholder_sprites() -> void:
	# White body with red spikes so hazardous targets are readable.
	if sprite and sprite.texture == null:
		var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
		var center := Vector2(7, 7)
		
		for y in range(14):
			for x in range(14):
				var pos := Vector2(x, y)
				var dist := pos.distance_to(center)
				
				if dist <= 5.0:
					var shade: float = 1.0 - (pos.x + pos.y - 7) * 0.04
					img.set_pixel(x, y, Color(0.95 * shade, 0.95 * shade, 0.95 * shade))
				elif (x == 7 and (y <= 2 or y >= 12)) or (y == 7 and (x <= 2 or x >= 12)):
					img.set_pixel(x, y, Color(0.95, 0.2, 0.2))
				elif abs(x - 7) == abs(y - 7) and dist >= 5.0 and dist <= 8.0:
					img.set_pixel(x, y, Color(0.95, 0.2, 0.2))
		
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex
		sprite.offset = Vector2(0, -7)
	
	# Keep the same flying shadow treatment as the base enemy.
	if shadow and shadow.texture == null:
		var simg := Image.create(10, 5, false, Image.FORMAT_RGBA8)
		for y in range(5):
			for x in range(10):
				var cx := x - 5
				var cy := y - 2.5
				if (cx * cx) / 25.0 + (cy * cy) / 6.25 <= 1.0:
					simg.set_pixel(x, y, Color(0, 0, 0, 0.5))
		
		var stex := ImageTexture.create_from_image(simg)
		shadow.texture = stex
