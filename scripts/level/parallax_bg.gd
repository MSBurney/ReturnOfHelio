class_name ParallaxBG
extends ParallaxBackground

## Procedural parallax background for Grasslands world.

func _ready() -> void:
	# Sky gradient (furthest layer, barely moves)
	_add_layer(Vector2(0.02, 0.02), _create_sky_texture())
	# Distant mountains
	_add_layer(Vector2(0.1, 0.05), _create_mountains_texture())
	# Mid-ground hills with trees
	_add_layer(Vector2(0.25, 0.1), _create_hills_texture())

func _add_layer(scroll_scale: Vector2, texture: ImageTexture) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = scroll_scale
	layer.motion_mirroring = Vector2(texture.get_width(), 0)
	add_child(layer)

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(-texture.get_width() * 0.5, -texture.get_height())
	layer.add_child(sprite)

func _create_sky_texture() -> ImageTexture:
	var w := 426
	var h := 240
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var sky_top := Color("1a1a3a")     # Dark blue-purple
	var sky_bottom := Color("3a5a8a")  # Lighter blue
	for y in range(h):
		var t := float(y) / float(h)
		var col := sky_top.lerp(sky_bottom, t)
		for x in range(w):
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

func _create_mountains_texture() -> ImageTexture:
	var w := 512
	var h := 240
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Draw mountain silhouettes in the lower portion
	var mountain_color := Color("1a3a2a")
	var mountain_highlight := Color("2a4a3a")

	# Generate a few peaks using simple sine waves
	for x in range(w):
		var base_height := 140.0
		var peak1 := sin(float(x) * 0.015) * 40.0
		var peak2 := sin(float(x) * 0.008 + 2.0) * 60.0
		var peak3 := sin(float(x) * 0.025 + 5.0) * 20.0
		var mountain_top := int(base_height - peak1 - peak2 - peak3)
		mountain_top = clampi(mountain_top, 60, h - 1)

		for y in range(mountain_top, h):
			var depth := float(y - mountain_top) / float(h - mountain_top)
			var col := mountain_color.lerp(mountain_highlight, depth * 0.3)
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)

func _create_hills_texture() -> ImageTexture:
	var w := 512
	var h := 240
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var hill_color := Color("1a4a1a")
	var hill_light := Color("2a6a2a")

	# Rolling hills
	for x in range(w):
		var hill1 := sin(float(x) * 0.02) * 25.0
		var hill2 := sin(float(x) * 0.035 + 1.5) * 15.0
		var hill_top := int(170.0 - hill1 - hill2)
		hill_top = clampi(hill_top, 120, h - 1)

		for y in range(hill_top, h):
			var depth := float(y - hill_top) / float(h - hill_top)
			var col := hill_light.lerp(hill_color, depth)
			img.set_pixel(x, y, col)

		# Simple tree silhouettes on hilltops
		if x % 24 < 4 and x > 10 and x < w - 10:
			var tree_base := hill_top
			var tree_height := 12 + (x * 7) % 8
			var trunk_x := x
			for ty in range(tree_base - tree_height, tree_base):
				if ty >= 0 and ty < h:
					# Triangle tree shape
					var tree_width := int(float(ty - (tree_base - tree_height)) / float(tree_height) * 4.0)
					for tx in range(trunk_x - tree_width, trunk_x + tree_width + 1):
						if tx >= 0 and tx < w:
							img.set_pixel(tx, ty, Color("0a3a0a"))

	return ImageTexture.create_from_image(img)
