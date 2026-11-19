extends "res://scripts/ashdod_environment.gd"
## Playable, compressed Mediterranean forest / Ashdod port-industrial chapters.
## Forest vocabulary: https://www.kkl-jnf.org/tourism-and-recreation/forests-and-parks/gezer-nachshon-forests/
## Port vocabulary: https://www.ashdodport.co.il/about/structure/Documents/adv/ashdod-port-eng.pdf
## These are authored game routes, not surveyed replicas or operational port maps.
@export_range(2,3,1) var chapter: int = 2
var terrain_rng := RandomNumberGenerator.new()

func _ready() -> void:
	terrain_rng.seed = 8021 + chapter
	_make_materials()
	_campaign_materials()
	_make_lighting()
	_campaign_light_adjustments()
	if chapter == 2:
		_build_forest()
	else:
		_build_port()
	_build_traversal_route()
	_campaign_markers()
	_batch_static_instances()
	if review_camera_enabled:
		_build_review_camera()

func _campaign_materials() -> void:
	mats.forest_floor = _pbr("coast_sand_02",Color(0.42,0.37,0.27),0.23,0.13)
	mats.trail = _pbr("coast_sand_02",Color(0.63,0.55,0.40),0.24,0.10)
	mats.rock = _pbr("white_plaster_rough_02",Color(0.72,0.70,0.61),0.35,0.15)
	mats.rock_clean = _clean_plaster(Color(0.61,0.60,0.53))
	mats.container_red = _plain(Color(0.48,0.21,0.13),0.68,0.30)
	mats.container_blue = _plain(Color(0.16,0.32,0.39),0.62,0.36)
	mats.container_cream = _plain(Color(0.60,0.59,0.49),0.72,0.22)
	mats.container_green = _plain(Color(0.24,0.36,0.31),0.70,0.22)
	mats.rust = _plain(Color(0.38,0.23,0.13),0.94,0.12)
	mats.safety = _plain(Color(0.79,0.58,0.19),0.65)
	mats.warehouse = _plain(Color(0.55,0.59,0.58),0.72,0.35)
	mats.steel = _plain(Color(0.44,0.50,0.51),0.43,0.70)
	mats.dark_steel = _plain(Color(0.16,0.21,0.22),0.54,0.65)
	mats.trunk_cut = _plain(Color(0.57,0.43,0.28),0.94)
	mats.mooring = _plain(Color(0.28,0.30,0.29),0.9)
	var pine_texture := load("res://assets/environment/pine-spray.png") as Texture2D
	var spray := StandardMaterial3D.new()
	spray.albedo_texture = pine_texture
	spray.albedo_color = Color(0.72,0.83,0.66)
	spray.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	spray.alpha_scissor_threshold = 0.33
	spray.cull_mode = BaseMaterial3D.CULL_DISABLED
	spray.roughness = 0.95
	spray.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats.pine_spray = spray

func _campaign_light_adjustments() -> void:
	for node in get_children():
		if node is WorldEnvironment:
			node.environment.ambient_light_energy = 0.53 if chapter==2 else 0.48
			node.environment.fog_density = 0.0017 if chapter==2 else 0.0011
			node.environment.fog_light_color = Color(0.65,0.72,0.67) if chapter==2 else Color(0.70,0.77,0.80)
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-48,-38,0) if chapter==2 else Vector3(-39,-62,0)
			node.light_energy = 0.93
			node.directional_shadow_max_distance = 90.0

func _marker(label: String, at: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name=label
	marker.position=at
	marker.rotation.y=PI
	add_child(marker)
	return marker

func _campaign_markers() -> void:
	_marker("Spawn",Vector3(0,0.04,29))
	_marker("EncounterA",Vector3(0,0.04,19))
	_marker("EncounterB",Vector3(0,0.04,-28))
	_marker("Exit",Vector3(0,0.04,-47))
	_marker("JumpApproach",Vector3(0,0.04,26.5))
	_marker("VaultApproach",Vector3(0,0.04,8.2))
	_marker("ClimbApproach",Vector3(0,0.04,0.1))
	_marker("LedgeApproach",Vector3(0,0.04,-8.9))
	_marker("VaultLanding",Vector3(0,0.04,6.0))
	_marker("ClimbLanding",Vector3(0,1.13,-1.8))
	_marker("LedgeLanding",Vector3(0,2.18,-11.1))
	var exit_group := _group("ChapterExitGate",Vector3(0,0,-47))
	var gate_material: Material = mats.wood if chapter==2 else mats.safety
	_box(exit_group,Vector3(0.28,3.2,0.28),Vector3(-2.5,1.6,0),gate_material,true)
	_box(exit_group,Vector3(0.28,3.2,0.28),Vector3(2.5,1.6,0),gate_material,true)
	_box(exit_group,Vector3(5.4,0.38,0.24),Vector3(0,3.15,0),gate_material)
	_label(exit_group,"אל הנמל" if chapter==2 else "שער יציאה",Vector3(0,3.15,0.15),Color(0.89,0.87,0.75),0.005)

func _build_traversal_route() -> void:
	var fixtures := _group("TraversalRoute",Vector3.ZERO)
	# Flat top boxes match the controller's chest/top ray contract exactly.
	var wood: Material = mats.wood if chapter==2 else mats.container_cream
	# A low trunk/pipe requires an ordinary jump; the .65 m chest ray clears it.
	if chapter==2:
		_fallen_log(Vector3(0,0.14,25),4.8,0.14,0.0)
	else:
		_beam(fixtures,Vector3(-2.4,0.14,25),Vector3(2.4,0.14,25),0.14,mats.steel)
		_collision_box(fixtures,Vector3(4.8,0.28,0.28),Vector3(0,0.14,25))
	var vault := _box(fixtures,Vector3(5.8,0.72,0.46),Vector3(0,0.36,7),wood,true)
	vault.name="Vault072"
	vault.set_meta("traversal_kind","vault")
	vault.set_meta("height",0.72)
	if chapter==2:
		_fallen_log(Vector3(-4.1,0.32,7),1.9,0.32,PI*0.5)
		_fallen_log(Vector3(4.1,0.32,7),1.9,0.32,PI*0.5)
	else:
		for x in [-2.6,2.6]:
			_box(fixtures,Vector3(0.25,0.72,0.49),Vector3(x,0.36,7),mats.safety)
	var climb := _box(fixtures,Vector3(5.8,1.1,3.2),Vector3(0,0.55,-2.6),wood,true)
	climb.name="Climb110"
	climb.set_meta("traversal_kind","climb")
	climb.set_meta("height",1.1)
	var ledge := _box(fixtures,Vector3(5.8,2.15,4.0),Vector3(0,1.075,-12),mats.rock_clean if chapter==2 else mats.container_blue,true)
	ledge.name="Ledge215"
	ledge.set_meta("traversal_kind","hang")
	ledge.set_meta("height",2.15)
	for i in range(5):
		var h := 0.90-float(i)*0.20
		_box(fixtures,Vector3(5.8,h,0.45),Vector3(0,h*0.5,-4.425-float(i)*0.45),wood,true)
	for i in range(8):
		var h := 1.90-float(i)*0.25
		_box(fixtures,Vector3(5.8,h,0.58),Vector3(0,h*0.5,-14.29-float(i)*0.58),wood,true)
	# Flanking geometry makes a readable route while leaving a wide combat
	# clearing at either end. Tops remain unobstructed for hanging/pull-up.
	for side in [-1.0,1.0]:
		for z in [7.0,-2.4,-11.8]:
			if chapter==2:
				_boulder(Vector3(float(side)*5.0,0,z),Vector3(4.3,3.2,3.2),int(z))
				# Three close route trees retain fine individual needle sprays.
				var close_detail: bool = z==7.0 or (side<0.0 and z==-11.8)
				_pine(Vector3(float(side)*7.0,0,z-2.5),8.5,int(z)+10,close_detail)
			else:
				_container(Vector3(float(side)*5.4,0,z),Vector3(4.6,2.65,3.1),int(z)+3)
	if chapter==2:
		for z in [-1.08,-2.0,-3.0]:
			_box(fixtures,Vector3(5.74,0.07,0.82),Vector3(0,1.065,z),mats.wood)
	else:
		for x in [-2.6,2.6]:
			_box(fixtures,Vector3(0.15,0.035,3.8),Vector3(x,2.175,-12),mats.safety)

func _build_forest() -> void:
	_box(self,Vector3(70,0.5,118),Vector3(0,-0.25,-10),mats.forest_floor,true)
	# A broad compacted path joins two open clearings, with sunlit understory.
	_box(self,Vector3(6.2,0.024,92),Vector3(0,0.002,-8),mats.trail)
	for z in [19.0,-28.0]:
		_cylinder(self,9.1,0.025,Vector3(0,0.008,z),mats.trail,-1.0,48)
	for i in range(40):
		var side := -1.0 if i%2==0 else 1.0
		var z := 34.0-float(i/2)*4.55
		var x := side*(11.5+terrain_rng.randf()*13.0)
		_pine(Vector3(x,0,z),terrain_rng.randf_range(7.0,11.5),i)
		if i%3==0:
			_cypress(Vector3(x+side*3.5,0,z+1.4),terrain_rng.randf_range(7.0,10.0),i)
	for i in range(72):
		var side := -1.0 if i%2==0 else 1.0
		var at := Vector3(side*terrain_rng.randf_range(7.4,25.0),0,terrain_rng.randf_range(-52,35))
		if i%4==0:
			_boulder(at,Vector3(1.7,1.0,1.2)*terrain_rng.randf_range(0.7,1.5),i)
		else:
			_shrub(self,at,terrain_rng.randf_range(0.5,0.9),i)
	for side in [-1.0,1.0]:
		for i in range(8):
			_boulder(Vector3(float(side)*30,0,30-float(i)*12),Vector3(8,4.5+float(i%3),10),i+80)
	_fallen_log(Vector3(-7.0,0.36,19),5.6,0.36,0.2)
	_fallen_log(Vector3(7.2,0.39,-26),5.2,0.39,-0.5)
	_picnic_table(Vector3(7.5,0,23),0.2)
	_picnic_table(Vector3(-8,0,-31),-0.35)
	_boardwalk(Vector3(0,0,-37),4.5,11.0)
	_forest_sign(Vector3(-3.7,0,27),"שביל החורש")
	_forest_sign(Vector3(3.8,0,-21),"אל הנמל")
	# Low visual boundary, backed by natural tree/rock mass; no invisible wall.
	for side in [-1.0,1.0]:
		_rail_fence(Vector3(float(side)*25.5,0,-9),88,0.9)

func _pine(at: Vector3, height: float, variant: int, detailed: bool = false) -> void:
	var tree := _group("MediterraneanPine",at)
	var trunk_end := Vector3(sin(float(variant))*0.35,height,cos(float(variant))*0.25)
	_beam(tree,Vector3.ZERO,trunk_end,0.19+height*0.009,mats.bark)
	var body := StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=0
	tree.add_child(body)
	var collision := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius=0.28
	trunk_shape.height=height
	collision.shape=trunk_shape
	collision.position.y=height*0.5
	body.add_child(collision)
	var needles := SurfaceTool.new()
	needles.begin(Mesh.PRIMITIVE_TRIANGLES)
	needles.set_smooth_group(0)
	var branches := 12 if detailed else 7
	var twigs := 5 if detailed else 3
	var bundles := 5 if detailed else 4
	var leaves := 6 if detailed else 5
	# Background crowns use fewer, slightly broader sprays. Silhouettes and
	# branch depth remain, with much less subpixel geometry and shadow work.
	for branch in range(branches):
		var a := float(branch)*2.39996+float(variant)*0.13
		var tier := float(branch%5)/5.0
		var start := trunk_end*Vector3(1,0.54+tier*0.40,1)
		var radial := Vector3(cos(a),0,sin(a))
		var side := Vector3(-sin(a),0,cos(a))
		var end := start+radial*(3.0-tier*1.3)+Vector3.UP*(0.6-tier*0.2)
		_beam(tree,start,end,0.055-tier*0.025,mats.bark)
		for twig in range(twigs):
			var t := 0.35+float(twig)*0.52/float(maxi(1,twigs-1))
			var twig_base := start.lerp(end,t)
			var twig_end := twig_base+side*((-1.0 if twig%2==0 else 1.0)*(0.6+t*0.5))+radial*0.35+Vector3.UP*0.12
			_beam(tree,twig_base,twig_end,0.019,mats.bark)
			for bundle in range(bundles):
				var center := twig_base.lerp(twig_end,0.25+float(bundle)*0.68/float(maxi(1,bundles-1)))
				for leaf in range(leaves):
					var la := float(leaf)*TAU/float(leaves)+float(bundle)
					var direction := Vector3(cos(la),0.20+sin(la*1.7)*0.22,sin(la))
					var length := (0.28+float((leaf+bundle)%3)*0.065)*(1.0 if detailed else 1.28)
					var points := PackedVector3Array([center,center+direction*length*0.5+Vector3.UP*0.045,center+direction*length])
					_leaf_ribbon(needles,points,0.032 if detailed else 0.043,Color(0.25,0.37,0.21).lerp(Color(0.38,0.46,0.27),float(bundle%3)*0.20))
	needles.generate_normals()
	_mesh(tree,needles.commit(),mats.foliage)
	_pine_crown(tree,height,variant)
	_merge_material_meshes(tree,mats.bark)
	_merge_material_meshes(tree,mats.pine_spray)

func _pine_crown(tree: Node3D, height: float, variant: int) -> void:
	# Fixed, intersecting branch sprays provide volume from every angle. This
	# is foliage geometry, never a camera-facing tree billboard.
	var random := RandomNumberGenerator.new()
	random.seed = 9013 + absi(variant) * 73
	for layer_index in range(3):
		var radius := 2.5 - float(layer_index) * 0.58
		var count := 13 - layer_index * 3
		for index in range(count):
			var angle := float(index) * TAU / float(count) + float(layer_index) * 0.8
			var r := radius * random.randf_range(0.48,1.0)
			var center := Vector3(cos(angle)*r,height*(0.69+float(layer_index)*0.105)+random.randf_range(-0.22,0.22),sin(angle)*r)
			for crossed in range(2):
				var card := QuadMesh.new()
				card.size = Vector2(random.randf_range(2.05,2.85),random.randf_range(1.8,2.45))
				var instance := _mesh(tree,card,mats.pine_spray,center)
				instance.rotation = Vector3(random.randf_range(-0.65,0.65),angle+float(crossed)*PI*0.5,random.randf_range(-0.4,0.4))

func _cypress(at: Vector3, height: float, variant: int) -> void:
	var tree := _group("MediterraneanCypress",at)
	_beam(tree,Vector3.ZERO,Vector3(0,height,0),0.17,mats.bark)
	# Irregular tapered sprays give the narrow cypress silhouette real edges.
	for tier in range(6):
		var y := 1.2+float(tier)*(height-1.4)/6.0
		var r := 0.95*(1.0-float(tier)/10.0)
		for side in range(2):
			var a := float(side)*PI+float(tier)*1.1
			_shrub(tree,Vector3(cos(a)*r*0.35,y,sin(a)*r*0.35),r,variant+tier+side)
			(tree.get_child(tree.get_child_count()-1) as Node3D).scale.y=1.7
	# A cypress keeps its narrow outline, but its crown must remain dense at
	# gameplay distance where the individual needle geometry is subpixel.
	for tier in range(7):
		var y := 1.3 + float(tier) * (height-1.8) / 7.0
		var width := 1.9 * (1.0 - float(tier) / 10.0)
		for crossed in range(3):
			var card := QuadMesh.new()
			card.size = Vector2(width,2.2)
			var instance := _mesh(tree,card,mats.pine_spray,Vector3(0,y,0))
			instance.rotation.y = float(crossed)*PI/3.0+float(tier)*0.65
	_merge_material_meshes(tree,mats.foliage)
	_merge_material_meshes(tree,mats.pine_spray)

func _merge_material_meshes(parent: Node3D, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inverse := parent.global_transform.affine_inverse()
	var instances: Array[MeshInstance3D] = []
	for node in parent.find_children("*","MeshInstance3D",true,false):
		if node.material_override==material:
			instances.append(node)
			for index in range(node.mesh.get_surface_count()):
				surface.append_from(node.mesh,index,inverse*node.global_transform)
	if instances.is_empty(): return
	for instance in instances:
		instance.get_parent().remove_child(instance)
		instance.free()
	_mesh(parent,surface.commit(),material)

func _collision_box(parent: Node3D, size_value: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=0
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size_value
	collision.shape=shape
	collision.position=at
	body.add_child(collision)

func _boulder(at: Vector3, size_value: Vector3, variant: int) -> void:
	var rock := _group("WeatheredChalkRock",at)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for ring in range(6):
		for sector in range(12):
			var corners: Array[Vector3] = []
			for coordinate in [Vector2(sector,ring),Vector2(sector+1,ring),Vector2(sector+1,ring+1),Vector2(sector,ring+1)]:
				var a: float = coordinate.x*TAU/12.0
				var v: float = coordinate.y*PI/6.0
				var irregular := 1.0+sin(a*3.0+float(variant))*0.12+cos(v*5.0+a)*0.07
				corners.append(Vector3(cos(a)*sin(v)*size_value.x*0.5*irregular,(cos(v)+1.0)*size_value.y*0.5,sin(a)*sin(v)*size_value.z*0.5*irregular))
			for index in [0,2,1,0,3,2]:
				surface.set_uv(Vector2(corners[index].x,corners[index].z))
				surface.add_vertex(corners[index])
	surface.generate_normals()
	surface.generate_tangents()
	var instance := _mesh(rock,surface.commit(),mats.rock)
	instance.create_convex_collision()

func _fallen_log(at: Vector3, length: float, radius: float, angle: float) -> void:
	var log_node := _group("FallenPineLog",at)
	log_node.rotation.y=angle
	var bark := _cylinder(log_node,radius,length,Vector3.ZERO,mats.bark,radius*0.88,14)
	bark.rotation.z=PI*0.5
	for side in [-1.0,1.0]:
		var cut := _cylinder(log_node,radius*0.88,0.025,Vector3(float(side)*length*0.5,0,0),mats.trunk_cut,-1.0,20)
		cut.rotation.z=PI*0.5
		for ring in [0.33,0.61,0.84]:
			var torus := TorusMesh.new()
			torus.inner_radius=radius*float(ring)-0.008
			torus.outer_radius=radius*float(ring)+0.008
			torus.rings=20
			torus.ring_segments=5
			var growth := _mesh(log_node,torus,mats.bark,Vector3(float(side)*(length*0.5+0.02),0,0))
			growth.rotation.z=PI*0.5
	var body := StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=0
	log_node.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius=radius
	shape.height=length
	collision.shape=shape
	collision.rotation.z=PI*0.5
	body.add_child(collision)

func _boardwalk(at: Vector3, width: float, length: float) -> void:
	var deck := _group("TimberForestBoardwalk",at)
	for i in range(int(length/0.28)):
		_box(deck,Vector3(width,0.12,0.265),Vector3(0,-0.035,-length*0.5+float(i)*0.28),mats.wood,true)
	for side in [-1.0,1.0]:
		for i in range(int(length/1.5)+1):
			_box(deck,Vector3(0.13,1.1,0.13),Vector3(float(side)*(width*0.5+0.12),0.55,-length*0.5+float(i)*1.5),mats.dark_wood,true)
		for y in [0.50,1.05]:
			_box(deck,Vector3(0.09,0.10,length),Vector3(float(side)*(width*0.5+0.12),y,0),mats.wood,true)

func _picnic_table(at: Vector3, angle: float) -> void:
	var table := _group("ForestPicnicTable",at)
	table.rotation.y=angle
	for plank in range(5):
		_box(table,Vector3(2.1,0.075,0.17),Vector3(0,0.79,-0.36+float(plank)*0.18),mats.wood)
	for x in [-0.7,0.7]:
		_beam(table,Vector3(x,0,-0.65),Vector3(x,0.79,0.2),0.065,mats.dark_wood)
		_beam(table,Vector3(x,0,0.65),Vector3(x,0.79,-0.2),0.065,mats.dark_wood)
	for z in [-0.75,0.75]:
		_box(table,Vector3(2.2,0.09,0.38),Vector3(0,0.44,z),mats.wood,true)

func _forest_sign(at: Vector3, text_value: String) -> void:
	var sign_node := _group("ForestWayfinding",at)
	_box(sign_node,Vector3(0.12,1.8,0.12),Vector3(0,0.9,0),mats.dark_wood,true)
	_box(sign_node,Vector3(1.4,0.48,0.08),Vector3(0,1.62,0),mats.wood)
	_label(sign_node,text_value,Vector3(0,1.63,0.06),Color(0.90,0.87,0.73),0.0035)

func _rail_fence(at: Vector3, length: float, height: float) -> void:
	var fence := _group("RouteBoundaryFence",at)
	for z in range(int(-length*0.5),int(length*0.5)+1,3):
		_box(fence,Vector3(0.12,height,0.12),Vector3(0,height*0.5,float(z)),mats.dark_wood,true)
	for y in [height*0.4,height*0.9]:
		_box(fence,Vector3(0.10,0.09,length),Vector3(0,y,0),mats.wood,true)

func _build_port() -> void:
	_box(self,Vector3(72,0.6,112),Vector3(10,-0.30,-10),mats.paving,true)
	# West quayside water begins beyond the solid apron rather than below it.
	var sea := PlaneMesh.new()
	sea.size=Vector2(200,250)
	_mesh(self,sea,_plain(Color(0.12,0.29,0.34),0.24,0.12),Vector3(-126,-0.45,-10))
	for z in range(-60,45,7):
		_box(self,Vector3(0.45,0.38,6.8),Vector3(-25.7,0.19,float(z)),mats.stone,true)
		_cylinder(self,0.21,0.62,Vector3(-24.5,0.31,float(z)),mats.dark_steel,0.27,10)
	for z in range(-48,35,7):
		_box(self,Vector3(0.11,0.015,3.0),Vector3(-9.5,0.025,float(z)),mats.safety)
		_box(self,Vector3(0.11,0.015,3.0),Vector3(9.5,0.025,float(z)),mats.safety)
	for at in [Vector3(-16,0,24),Vector3(17,0,23),Vector3(-17,0,-27),Vector3(17,0,-30)]:
		_container(at,Vector3(5.1,2.65,10.0),int(at.z))
		_container(at+Vector3(0,2.65,0),Vector3(5.1,2.65,10.0),int(at.z)+1)
	_warehouse(Vector3(21,0,-3),Vector3(12,7.5,24),0)
	_warehouse(Vector3(-18,0,-47),Vector3(11,6.3,14),1)
	_gantry_crane(Vector3(-22,0,-19),0)
	_gantry_crane(Vector3(-30,0,32),1)
	_pipe_rack(Vector3(0,0,-22),20.0)
	for side in [-1.0,1.0]:
		for z in [-3.0,-8.0]:
			_storage_tank(Vector3(float(side)*17,0,z),1.7,5.2)
	for i in range(10):
		var at := Vector3(10.6+float(i%2)*2.0,0,31.0-float(i/2)*3.1)
		_pallet_stack(at,1+ i%3)
	for i in range(8):
		_oil_drum(Vector3(-10.9+float(i%2)*1.0,0,-23-float(i/2)*1.2),i)
	_forklift(Vector3(8.3,0,-34),-0.6)
	_industrial_station(Vector3(-7.7,0,-30),PI*0.5)
	for z in [27.0,15.0,-27.0,-42.0]:
		_lamp(Vector3(12.5,0,z))

func _container(at: Vector3, size_value: Vector3, variant: int) -> void:
	var container := _group("CorrugatedShippingContainer",at)
	var palette := [mats.container_red,mats.container_blue,mats.container_cream,mats.container_green]
	var material: Material = palette[posmod(variant,4)]
	_box(container,size_value,Vector3(0,size_value.y*0.5,0),material,true)
	for side in [-1.0,1.0]:
		for i in range(int(size_value.z/0.25)):
			_box(container,Vector3(0.055,size_value.y-0.18,0.09),Vector3(float(side)*(size_value.x*0.5+0.02),size_value.y*0.5,-size_value.z*0.5+0.14+float(i)*0.25),material)
		for y in [0.10,size_value.y-0.10]:
			_box(container,Vector3(0.12,0.14,size_value.z+0.10),Vector3(float(side)*size_value.x*0.5,y,0),mats.dark_steel)
	for x in [-size_value.x*0.5,size_value.x*0.5]:
		for z in [-size_value.z*0.5,size_value.z*0.5]:
			_box(container,Vector3(0.18,size_value.y,0.18),Vector3(x,size_value.y*0.5,z),material)
	for door in [-1.0,1.0]:
		var x: float = float(door)*size_value.x*0.25
		_box(container,Vector3(size_value.x*0.47,size_value.y-0.30,0.06),Vector3(x,size_value.y*0.5,size_value.z*0.5+0.035),material)
		for offset in [-0.30,0.30]:
			_beam(container,Vector3(x+offset,0.20,size_value.z*0.5+0.10),Vector3(x+offset,size_value.y-0.20,size_value.z*0.5+0.10),0.029,mats.white_metal)
		for y in [0.35,size_value.y-0.35]:
			_box(container,Vector3(0.29,0.10,0.08),Vector3(x,y,size_value.z*0.5+0.10),mats.dark_steel)
	_label(container,"ASHD  %04d"%posmod(variant*791+418,9999),Vector3(-size_value.x*0.18,size_value.y*0.72,size_value.z*0.5+0.11),Color(0.82,0.83,0.77),0.0025)

func _warehouse(at: Vector3, size_value: Vector3, variant: int) -> void:
	var warehouse := _group("PortWorkshopWarehouse",at)
	warehouse.rotation.y=-PI*0.5 if variant==0 else 0.0
	_box(warehouse,Vector3(size_value.x,size_value.y,size_value.z),Vector3(0,size_value.y*0.5,-size_value.z*0.5),mats.warehouse,true)
	for i in range(int(size_value.x/0.32)):
		_box(warehouse,Vector3(0.07,size_value.y-0.1,0.09),Vector3(-size_value.x*0.5+float(i)*0.32,size_value.y*0.5,0.04),mats.steel)
	for x in [-size_value.x*0.25,size_value.x*0.25]:
		_box(warehouse,Vector3(size_value.x*0.35,4.6,0.14),Vector3(x,2.3,0.15),mats.dark_steel)
		for slat in range(22):
			_box(warehouse,Vector3(size_value.x*0.34,0.15,0.07),Vector3(x,0.18+float(slat)*0.20,0.25),mats.steel)
	for x in [-size_value.x*0.37,0.0,size_value.x*0.37]:
		_box(warehouse,Vector3(size_value.x*0.23,1.05,0.12),Vector3(x,size_value.y-1.1,0.15),mats.window_light)
		_box(warehouse,Vector3(0.06,1.05,0.14),Vector3(x,size_value.y-1.1,0.24),mats.cream)
	for side in [-1.0,1.0]:
		var roof := _box(warehouse,Vector3(size_value.x*0.54,0.20,size_value.z+0.8),Vector3(float(side)*size_value.x*0.25,size_value.y+0.35,-size_value.z*0.5),mats.dark_steel)
		roof.rotation.z=float(side)*-0.12
	for x in [-size_value.x*0.46,size_value.x*0.46]:
		_beam(warehouse,Vector3(x,0,0.25),Vector3(x,size_value.y,0.25),0.07,mats.steel)
	_label(warehouse,"סדנת נמל · 03",Vector3(0,5.15,0.35),Color(0.87,0.82,0.65),0.007)

func _gantry_crane(at: Vector3, variant: int) -> void:
	var crane := _group("AshdodQuaysideGantryCrane",at)
	var h := 22.0+float(variant)*5.0
	for x in [-3.0,3.0]:
		for z in [-4.0,4.0]:
			_box(crane,Vector3(0.7,h,0.7),Vector3(x,h*0.5,z),mats.container_blue,true)
			for y in [1.0,5.0,9.0,13.0,17.0]:
				_beam(crane,Vector3(x,y,-4),Vector3(x,y+4,4),0.095,mats.steel)
		_box(crane,Vector3(0.9,1.2,11),Vector3(x,h,0),mats.container_blue)
	_box(crane,Vector3(30,1.0,2.1),Vector3(-7,h+1.1,0),mats.container_blue)
	for i in range(14):
		var x := -21.0+float(i)*2.15
		_beam(crane,Vector3(x,h+1.6,-1),Vector3(x+2.15,h+3.1,-1),0.095,mats.steel)
		_beam(crane,Vector3(x,h+3.1,1),Vector3(x+2.15,h+1.6,1),0.095,mats.steel)
	_box(crane,Vector3(3.0,2.0,2.3),Vector3(4,h-1.0,0),mats.cream)
	_box(crane,Vector3(2.1,1.2,0.06),Vector3(4,h-0.85,1.18),mats.glass)
	for z in [-0.7,0.7]:
		_beam(crane,Vector3(-10,h+1,z),Vector3(-10,7,z),0.026,mats.dark_steel)
	_box(crane,Vector3(5.6,0.45,2.5),Vector3(-10,7,0),mats.safety)

func _storage_tank(at: Vector3, radius: float, height: float) -> void:
	var tank := _group("PortBulkTank",at)
	_cylinder(tank,radius,height,Vector3(0,height*0.5,0),mats.steel,-1.0,32)
	for y in [0.18,height*0.5,height-0.15]:
		_cylinder(tank,radius+0.06,0.12,Vector3(0,y,0),mats.dark_steel,-1.0,32)
	_cylinder(tank,radius,0.7,Vector3(0,height+0.35,0),mats.steel,0.3,32)
	_collision_box(tank,Vector3(radius*2,height,radius*2),Vector3(0,height*0.5,0))
	for y in range(int(height*3)):
		_beam(tank,Vector3(-0.28,float(y)/3.0,radius+0.16),Vector3(0.28,float(y)/3.0,radius+0.16),0.026,mats.safety)
	for x in [-0.3,0.3]:
		_beam(tank,Vector3(x,0,radius+0.16),Vector3(x,height+0.2,radius+0.16),0.035,mats.safety)

func _pipe_rack(at: Vector3, width: float) -> void:
	var rack := _group("ElevatedFactoryPipeRack",at)
	for x in [-width*0.5,width*0.5]:
		_box(rack,Vector3(0.32,6.4,0.32),Vector3(x,3.2,0),mats.dark_steel,true)
		_box(rack,Vector3(1.0,0.28,1.0),Vector3(x,0.14,0),mats.stone,true)
	_box(rack,Vector3(width+1.0,0.32,2.4),Vector3(0,6.2,0),mats.dark_steel)
	for pipe in range(4):
		var z := -0.83+float(pipe)*0.55
		_beam(rack,Vector3(-width*0.5,6.65,z),Vector3(width*0.5,6.65,z),0.17+float(pipe%2)*0.045,mats.steel)
		for x in [-6.0,0.0,6.0]:
			var flange := _cylinder(rack,0.25,0.10,Vector3(x,6.65,z),mats.dark_steel,-1.0,16)
			flange.rotation.z=PI*0.5

func _pallet_stack(at: Vector3, count: int) -> void:
	var stack := _group("TimberCargoPallets",at)
	for level in range(count):
		for x in [-0.50,0.0,0.50]:
			_box(stack,Vector3(0.13,0.12,1.2),Vector3(x,float(level)*0.19+0.06,0),mats.dark_wood)
		for slat in range(5):
			_box(stack,Vector3(1.2,0.055,0.20),Vector3(0,float(level)*0.19+0.15,-0.48+float(slat)*0.24),mats.wood)
	_collision_box(stack,Vector3(1.2,float(count)*0.19,1.2),Vector3(0,float(count)*0.095,0))

func _oil_drum(at: Vector3, variant: int) -> void:
	var drum := _group("IndustrialDrum",at)
	var material: Material = mats.container_red if variant%2==0 else mats.container_blue
	_cylinder(drum,0.36,0.92,Vector3(0,0.46,0),material,-1.0,20)
	for y in [0.04,0.27,0.65,0.90]:
		_cylinder(drum,0.375,0.045,Vector3(0,y,0),mats.dark_steel,-1.0,20)
	_box(drum,Vector3(0.25,0.23,0.035),Vector3(0,0.48,0.365),mats.safety)

func _forklift(at: Vector3, angle: float) -> void:
	var lift := _group("PortForklift",at)
	lift.rotation.y=angle
	_box(lift,Vector3(1.3,0.7,2.2),Vector3(0,0.63,0),mats.safety,true)
	_box(lift,Vector3(0.8,0.45,0.5),Vector3(0,1.03,-0.15),mats.rubber)
	for x in [-0.56,0.56]:
		for z in [-0.7,0.7]:
			var wheel := _cylinder(lift,0.31,0.22,Vector3(x,0.31,z),mats.rubber,-1.0,14)
			wheel.rotation.z=PI*0.5
		for z in [-0.6,0.55]:
			_box(lift,Vector3(0.07,1.45,0.07),Vector3(x,1.7,z),mats.dark_steel)
	_box(lift,Vector3(1.35,0.12,1.55),Vector3(0,2.42,0),mats.safety)
	for x in [-0.35,0.35]:
		_box(lift,Vector3(0.12,2.65,0.14),Vector3(x,1.4,1.18),mats.dark_steel)
		_box(lift,Vector3(0.16,0.08,1.15),Vector3(x,0.15,1.65),mats.steel)

func _industrial_station(at: Vector3, angle: float) -> void:
	var station := _group("IndustrialContactStation",at)
	station.rotation.y=angle
	station.add_to_group("environment_stations")
	_box(station,Vector3(2.3,1.0,0.92),Vector3(0,0.50,0),mats.steel,true)
	_box(station,Vector3(2.42,0.09,1.05),Vector3(0,1.045,0),mats.dark_steel)
	_box(station,Vector3(0.65,0.025,0.52),Vector3(-0.4,1.10,0),mats.rust)
	for x in [-0.9,0.9]:
		_box(station,Vector3(0.14,0.92,0.14),Vector3(x,0.46,0.31),mats.safety)
	var approach := Marker3D.new()
	approach.name="Approach"
	approach.position=Vector3(-0.4,0,1.4)
	station.add_child(approach)
	var contact := Marker3D.new()
	contact.name="Contact"
	contact.position=Vector3(-0.4,1.12,0)
	station.add_child(contact)

func _build_review_camera() -> void:
	camera=Camera3D.new()
	camera.name="CampaignReviewCamera"
	camera.fov=66
	camera.far=500
	add_child(camera)
	camera.current=true
	_viewpoint(0)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud=Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var panel := PanelContainer.new()
	panel.position=Vector2(20,18)
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.04,0.07,0.07,0.84)
	style.content_margin_left=14
	style.content_margin_right=14
	style.content_margin_top=10
	style.content_margin_bottom=10
	panel.add_theme_stylebox_override("panel",style)
	hud.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text="ГЛАВА 2 · СРЕДИЗЕМНОМОРСКИЙ ЛЕС" if chapter==2 else "ГЛАВА 3 · ПОРТ И ЗАВОД АШДОДА"
	title.add_theme_font_size_override("font_size",19)
	column.add_child(title)
	var help := Label.new()
	help.text="ПКМ — осмотр · WASD — движение · Q/E — высота · Tab — интерфейс"
	help.add_theme_font_size_override("font_size",12)
	column.add_child(help)
	var row := HBoxContainer.new()
	column.add_child(row)
	var labels := ["Вход","Маршрут","Уступ","Арена","Общий вид"]
	for index in range(labels.size()):
		var button := Button.new()
		button.text=labels[index]
		button.custom_minimum_size=Vector2(76,34)
		button.pressed.connect(_viewpoint.bind(index))
		row.add_child(button)

func _viewpoint(index: int) -> void:
	var positions := [Vector3(-4,2.6,32),Vector3(-8,3.3,9),Vector3(-6,3.1,-7),Vector3(6,2.5,-20),Vector3(-27,24,27)]
	var targets := [Vector3(0,2,9),Vector3(0,1.4,-4),Vector3(0,1.6,-13),Vector3(-1,1.5,-32),Vector3(0,1,-12)]
	camera.position=positions[index]
	camera.look_at(targets[index])
	fly_yaw=camera.rotation.y
	fly_pitch=camera.rotation.x
