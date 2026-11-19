extends Node3D
## Compressed Lido–Oranim / HaKshatot waterfront, authored from photographed
## architectural references. Not photogrammetry or a survey-accurate replica.
## Reference/source register: assets/environment/SOURCES.md.
@export var review_camera_enabled: bool = false
var mats: Dictionary = {}
var camera: Camera3D
var fly_yaw := 0.0
var fly_pitch := 0.0
var looking := false
var hud: Control
var water_material: ShaderMaterial
var primitive_cache: Dictionary = {}
var texture_cache: Dictionary = {}

func _ready() -> void:
	_make_materials()
	_make_lighting()
	_build_waterfront()
	_build_foodcourt()
	_build_city()
	_build_arches()
	_batch_static_instances()
	if review_camera_enabled:
		_build_review_camera()

func _plain(color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.3
	return m

func _filtered_texture(path: String, normal_map: bool = false) -> Texture2D:
	if texture_cache.has(path):
		return texture_cache[path]
	var imported: Texture2D = load(path)
	var pixels := imported.get_image()
	# These runtime-assigned materials are not detected by the editor's 3D
	# importer. Guarantee mip chains in web exports as well as desktop builds.
	# Albedo remains sRGB; normal/roughness use their linear material slots.
	if pixels.is_compressed():
		pixels.decompress()
	if not pixels.has_mipmaps():
		pixels.generate_mipmaps(normal_map)
	var filtered := ImageTexture.create_from_image(pixels)
	texture_cache[path] = filtered
	return filtered

func _pbr(id: String, color: Color, scale_value: float, normal_strength: float = 0.12) -> StandardMaterial3D:
	var m := _plain(color)
	var prefix := "res://assets/environment/materials/" + id + "/" + id
	m.albedo_texture = _filtered_texture(prefix + "_diff_1k.jpg")
	m.albedo_texture_force_srgb = false
	m.normal_enabled = true
	m.normal_texture = _filtered_texture(prefix + "_nor_gl_1k.jpg",true)
	m.normal_scale = normal_strength
	m.roughness_texture = _filtered_texture(prefix + "_rough_1k.jpg")
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale_value
	return m

func _clean_plaster(color: Color) -> StandardMaterial3D:
	# The reference plaster scan includes green weathering. Near-camera cafe
	# walls use clean mineral paint, retaining only a very subtle micro-normal.
	var m := _pbr("white_plaster_rough_02",color,0.24,0.025)
	m.albedo_texture = null
	m.roughness_texture = null
	m.roughness = 0.92
	return m

func _make_materials() -> void:
	mats.sand = _pbr("coast_sand_02",Color(0.79,0.77,0.70),0.22,0.10)
	mats.paving = _pbr("concrete_pavers_03",Color(0.71,0.74,0.75),0.32,0.16)
	mats.stone = _clean_plaster(Color(0.71,0.67,0.58))
	mats.plaster = _clean_plaster(Color(0.86,0.82,0.73))
	mats.ochre = _clean_plaster(Color(0.75,0.49,0.34))
	mats.wood = _pbr("brown_planks_03",Color(0.68,0.63,0.54),0.55,0.18)
	mats.dark_wood = _pbr("brown_planks_03",Color(0.29,0.25,0.19),0.8,0.12)
	mats.cream = _plain(Color(0.78,0.79,0.75))
	mats.yellow = _plain(Color(0.69,0.59,0.33))
	mats.metal = _plain(Color(0.21,0.26,0.27),0.36,0.65)
	mats.white_metal = _plain(Color(0.68,0.73,0.73),0.44,0.35)
	mats.glass = _plain(Color(0.12,0.21,0.26),0.28,0.22)
	mats.display_glass = _plain(Color(0.57,0.72,0.76,0.19),0.18,0.04)
	mats.display_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats.window_light = _plain(Color(0.48,0.56,0.56),0.32,0.12)
	mats.curtain = _plain(Color(0.78,0.75,0.65),0.95)
	mats.interior = _plain(Color(0.69,0.58,0.43),0.9)
	mats.interior.emission_enabled = true
	mats.interior.emission = Color(0.38,0.28,0.16)
	mats.interior.emission_energy_multiplier = 0.20
	mats.bottle = _plain(Color(0.19,0.37,0.25),0.22,0.08)
	mats.jar = _plain(Color(0.69,0.36,0.18),0.32)
	mats.bread = _plain(Color(0.67,0.42,0.20),0.88)
	mats.menu = _plain(Color.WHITE,0.9)
	mats.menu.albedo_texture = _filtered_texture("res://assets/environment/coastal-menu.png")
	mats.menu.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats.menu.emission_enabled = true
	mats.menu.emission_texture = mats.menu.albedo_texture
	mats.menu.emission = Color.WHITE
	mats.menu.emission_energy_multiplier = 0.16
	mats.balcony = _plain(Color(0.27,0.38,0.37),0.28,0.18)
	mats.rubber = _plain(Color(0.055,0.065,0.063),0.9)
	mats.asphalt = _plain(Color(0.22,0.23,0.22),0.96)
	mats.leaf = _plain(Color(0.20,0.29,0.21),0.94)
	mats.leaf_light = _plain(Color(0.24,0.33,0.22),0.94)
	mats.foliage = _plain(Color.WHITE,0.94)
	mats.foliage.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats.foliage.vertex_color_use_as_albedo = true
	mats.foliage.metallic_specular = 0.12
	mats.foliage.backlight_enabled = true
	mats.foliage.backlight = Color(0.27,0.36,0.18)
	mats.bark = _pbr("brown_planks_03",Color(0.37,0.36,0.32),1.1,0.20)
	mats.soil = _plain(Color(0.20,0.18,0.15),1.0)
	mats.turquoise = _plain(Color(0.32,0.64,0.61))
	mats.red = _plain(Color(0.63,0.16,0.12))
	mats.light = _plain(Color(0.86,0.81,0.67),0.45)
	mats.light.emission_enabled = true
	mats.light.emission = Color(1.0,0.72,0.35)
	mats.light.emission_energy_multiplier = 0.3

func _group(label: String, position_value: Vector3, parent: Node = null) -> Node3D:
	if parent==null:
		parent=self
	var group := Node3D.new()
	group.name = label
	parent.add_child(group)
	group.position = position_value
	return group

func _mesh(parent: Node3D, mesh_value: Mesh, material: Material, position_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh_value
	instance.material_override = material
	instance.position = position_value
	parent.add_child(instance)
	return instance

func _box(parent: Node3D, size_value: Vector3, position_value: Vector3, material: Material, solid: bool = false) -> MeshInstance3D:
	var key := "box:%s" % size_value
	if not primitive_cache.has(key):
		var primitive := BoxMesh.new()
		primitive.size = size_value
		primitive_cache[key] = primitive
	var shape: BoxMesh = primitive_cache[key]
	var instance := _mesh(parent,shape,material,position_value)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		instance.add_child(body)
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size_value
		collision.shape = box
		body.add_child(collision)
	return instance

func _cylinder(parent: Node3D, radius: float, height: float, position_value: Vector3, material: Material, top_radius: float = -1.0, segments: int = 16) -> MeshInstance3D:
	var top := radius if top_radius < 0.0 else top_radius
	var key := "cylinder:%.5f:%.5f:%.5f:%d" % [radius,height,top,segments]
	if not primitive_cache.has(key):
		var primitive := CylinderMesh.new()
		primitive.bottom_radius = radius
		primitive.top_radius = top
		primitive.height = height
		primitive.radial_segments = segments
		primitive_cache[key] = primitive
	var shape: CylinderMesh = primitive_cache[key]
	return _mesh(parent,shape,material,position_value)

func _beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var beam := _cylinder(parent,radius,a.distance_to(b),(a+b)*0.5,material,-1.0,8)
	beam.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return beam

func _sphere(parent: Node3D, radius: float, position_value: Vector3, material: Material) -> MeshInstance3D:
	var key := "sphere:%.5f" % radius
	if not primitive_cache.has(key):
		var primitive := SphereMesh.new()
		primitive.radius = radius
		primitive.height = radius * 2.0
		primitive.radial_segments = 12
		primitive.rings = 6
		primitive_cache[key] = primitive
	var mesh_value: SphereMesh = primitive_cache[key]
	return _mesh(parent,mesh_value,material,position_value)

func _batch_static_instances() -> void:
	# Repeated furniture/palm/building parts share instanced GPU draws. Spatial
	# chunks retain culling, and original hidden nodes retain their collision.
	# Interaction stations remain independent for the later break animation.
	var groups: Dictionary = {}
	for node in find_children("*","MeshInstance3D",true,false):
		var instance: MeshInstance3D = node
		if not instance.mesh is PrimitiveMesh or instance.material_override is ShaderMaterial:
			continue
		var ancestor: Node = instance.get_parent()
		var interactive := false
		while ancestor != self and ancestor != null:
			if ancestor.is_in_group("environment_stations"):
				interactive = true
				break
			ancestor = ancestor.get_parent()
		if interactive:
			continue
		var at := instance.global_position
		var key := "%d:%d:%d:%d" % [instance.mesh.get_instance_id(),instance.material_override.get_instance_id(),floori(at.x/32.0),floori(at.z/32.0)]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(instance)
	var batching_root := _group("StaticDetailBatches",Vector3.ZERO)
	var inverse := global_transform.affine_inverse()
	for key in groups:
		var instances: Array = groups[key]
		if instances.size()<3:
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = instances[0].mesh
		multimesh.instance_count = instances.size()
		for i in range(instances.size()):
			multimesh.set_instance_transform(i,inverse*instances[i].global_transform)
			instances[i].visible = false
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multimesh
		batch.material_override = instances[0].material_override
		batching_root.add_child(batch)

func _label(parent: Node3D, value: String, position_value: Vector3, color: Color, size_value: float = 0.008) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = position_value
	label.font_size = 72
	label.pixel_size = size_value
	label.modulate = color
	label.outline_size = 0
	parent.add_child(label)
	return label

func _make_lighting() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.23,0.43,0.66)
	sky_material.sky_horizon_color = Color(0.75,0.81,0.82)
	sky_material.sky_curve = 0.30
	sky_material.ground_bottom_color = Color(0.30,0.32,0.32)
	sky_material.ground_horizon_color = Color(0.75,0.81,0.82)
	sky_material.sun_angle_max = 1.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.72,0.78,0.83)
	environment.ambient_light_energy = 0.48
	environment.background_energy_multiplier = 0.88
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.95
	environment.ssao_enabled = true
	environment.ssao_radius = 0.75
	environment.ssao_intensity = 1.1
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.65,0.74,0.79)
	environment.fog_density = 0.0008
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "NeutralCoastalDaylight"
	sun.rotation_degrees = Vector3(-43,-72,0)
	sun.light_color = Color(1.0,0.96,0.88)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

func _build_waterfront() -> void:
	var coast := _group("LidoOranimPromenade",Vector3.ZERO)
	_box(coast,Vector3(238,1.0,360),Vector3(71,-1.35,0),mats.sand,true)
	_box(coast,Vector3(27,0.44,190),Vector3(0,-0.22,0),mats.paving,true)
	# Paved city apron meets the promenade exactly; cafe furniture, shops and
	# inland buildings all sit at y=0 rather than hovering over the lower sand.
	_box(coast,Vector3(100,0.85,200),Vector3(63.5,-0.425,0),mats.paving,true)
	_box(coast,Vector3(4.8,0.3,190),Vector3(-15.9,-0.45,0),mats.wood,true)
	for z in range(-90,91,6):
		_box(coast,Vector3(0.42,0.32,5.95),Vector3(-13.55,0.16,float(z)),mats.stone,true)
	for z in range(-85,86,17):
		_lamp(Vector3(-11.5,0,float(z)))
		_bench(Vector3(-10.4,0,float(z)+4.7),PI*0.5)
		_palm(Vector3(10.8,0,float(z)+3.0),7.1+float(posmod(z,4)))
		_planter(Vector3(10.8,0,float(z)+3.0),Vector3(3.7,0.55,3.7))
	for z in [-70.0,-54.0,-37.0,-22.0,12.0,30.0,48.0,68.0]:
		_parasol(Vector3(-6.0,0,z),mats.yellow if int(z)%3!=0 else mats.cream)
		_table_set(Vector3(-6.0,0,z),0.0)
		_bin(Vector3(-9.6,0,z+3.0))
	for z in range(-80,81,18):
		for x in [-25.0,-32.0]:
			_parasol(Vector3(x,-0.85,float(z)),mats.cream)
			_lounger(Vector3(x-1.2,-0.85,float(z)+0.7),0.3)
			_lounger(Vector3(x+1.1,-0.85,float(z)-0.4),0.3)
	_lifeguard_tower(Vector3(-35,-0.85,-28))
	# A circular wood-edged public splash plaza, observed in the Lido night photographs.
	var splash := _group("CircularSplashPlaza",Vector3(-2,0,47))
	_cylinder(splash,7.3,0.12,Vector3(0,0.02,0),mats.stone,-1.0,64)
	for i in range(40):
		var a := float(i)*TAU/40.0
		var seat := _box(splash,Vector3(1.14,0.3,0.75),Vector3(cos(a)*7.2,0.26,sin(a)*7.2),mats.wood,true)
		seat.rotation.y = -a+PI*0.5
	for i in range(13):
		var a := float(i)*TAU/13.0
		_cylinder(splash,0.09,0.015,Vector3(cos(a)*4.4,0.095,sin(a)*4.4),mats.metal)
	# The sea is a real animated surface, with shallow-water colour and moving foam.
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=sin(world_pos.x*0.19+TIME*0.75)*0.13+sin(world_pos.z*0.34+world_pos.x*0.3-TIME)*0.07;}
void fragment(){float wave=sin(world_pos.x*0.74+world_pos.z*0.13-TIME*1.25);float ripple=sin(world_pos.z*2.1+world_pos.x*1.3+TIME);float shore=smoothstep(-74.0,-48.0,world_pos.x);vec3 sea=mix(vec3(0.035,0.22,0.30),vec3(0.18,0.44,0.43),shore);float foam=smoothstep(0.94,1.0,wave)*shore;ALBEDO=mix(sea,vec3(0.81,0.86,0.77),foam*0.65);ROUGHNESS=0.24;METALLIC=0.16;NORMAL=normalize(vec3(wave*0.08,ripple*0.06,1.0));}
"""
	water_material = ShaderMaterial.new()
	water_material.shader = shader
	var water := PlaneMesh.new()
	water.size = Vector2(420,520)
	water.subdivide_width = 90
	water.subdivide_depth = 70
	_mesh(coast,water,water_material,Vector3(-258,-0.88,0))
	# Breakwater and distant mast cluster are silhouettes from the HaKshatot panorama.
	_box(coast,Vector3(78,1.4,5),Vector3(-82,-0.5,-150),mats.stone)
	for i in range(23):
		var z := -133.0-float(i%3)*5.0
		_beam(coast,Vector3(-50.0-float(i)*2.1,-0.6,z),Vector3(-50.0-float(i)*2.1,4.0+float(i%4),z),0.035,mats.white_metal)

func _parasol(position_value: Vector3, material: Material) -> void:
	var group := _group("LidoFixedOctagonalShade",position_value)
	_cylinder(group,0.075,2.75,Vector3(0,1.375,0),mats.white_metal)
	_cylinder(group,2.15,0.6,Vector3(0,2.7,0),material,0.08,8)
	for i in range(8):
		var a := float(i)*TAU/8.0
		_beam(group,Vector3(0,3.0,0),Vector3(cos(a)*2.13,2.4,sin(a)*2.13),0.022,mats.white_metal)
	_cylinder(group,0.18,0.08,Vector3(0,0.04,0),mats.metal)

func _chair(parent: Node3D, at: Vector3, angle: float) -> void:
	var chair := _group("CafeChair",at,parent)
	chair.rotation.y = angle
	for x in [-0.24,0.24]:
		for z in [-0.23,0.23]:
			_beam(chair,Vector3(x*1.1,0.0,z*1.1),Vector3(x,0.48,z),0.024,mats.metal)
	_box(chair,Vector3(0.54,0.055,0.51),Vector3(0,0.48,0),mats.wood)
	for x in [-0.24,0.24]:
		_beam(chair,Vector3(x,0.4,-0.22),Vector3(x,0.97,-0.28),0.021,mats.metal)
	for y in [0.68,0.81,0.94]:
		_box(chair,Vector3(0.51,0.085,0.035),Vector3(0,y,-0.27),mats.wood)

func _table_set(at: Vector3, angle: float, parent: Node3D = null) -> void:
	if parent==null:
		parent=self
	var table := _group("OutdoorCafeTable",at,parent)
	table.rotation.y = angle
	_cylinder(table,0.07,0.76,Vector3(0,0.38,0),mats.metal)
	_cylinder(table,0.39,0.055,Vector3(0,0.03,0),mats.metal)
	_cylinder(table,0.62,0.065,Vector3(0,0.79,0),mats.wood,-1.0,24)
	for i in range(3):
		var a := float(i)*TAU/3.0
		_chair(table,Vector3(sin(a)*1.02,0,cos(a)*1.02),a)
	_cylinder(table,0.085,0.14,Vector3(0.12,0.90,0),mats.cream,-1.0,12)
	_cylinder(table,0.13,0.022,Vector3(-0.2,0.84,0.1),mats.cream,-1.0,20)

func _bench(at: Vector3, angle: float) -> void:
	var bench := _group("PromenadeWoodBench",at)
	bench.rotation.y = angle
	for x in [-0.78,0.78]:
		_box(bench,Vector3(0.10,0.45,0.65),Vector3(x,0.23,0),mats.metal)
		_beam(bench,Vector3(x,0.35,-0.27),Vector3(x,0.95,-0.35),0.035,mats.metal)
	for z in [-0.22,-0.075,0.075,0.22]:
		_box(bench,Vector3(1.95,0.07,0.12),Vector3(0,0.49,z),mats.dark_wood)
	for y in [0.66,0.81,0.96]:
		_box(bench,Vector3(1.95,0.11,0.055),Vector3(0,y,-0.33),mats.dark_wood)
	_box(bench,Vector3(1.9,0.52,0.64),Vector3(0,0.26,0),_plain(Color(0,0,0,0)),false).visible=false

func _bin(at: Vector3) -> void:
	var bin := _group("TimberWasteBin",at)
	_cylinder(bin,0.28,0.85,Vector3(0,0.425,0),mats.dark_wood)
	_cylinder(bin,0.31,0.10,Vector3(0,0.88,0),mats.metal)
	_cylinder(bin,0.21,0.015,Vector3(0,0.94,0),mats.rubber)
	for i in range(12):
		var a := float(i)*TAU/12.0
		_box(bin,Vector3(0.055,0.72,0.055),Vector3(cos(a)*0.285,0.43,sin(a)*0.285),mats.wood)

func _lamp(at: Vector3) -> void:
	var lamp := _group("PromenadeBranchLight",at)
	_cylinder(lamp,0.075,6.4,Vector3(0,3.2,0),mats.white_metal,0.045)
	for side in [-1.0,1.0]:
		_beam(lamp,Vector3(0,5.7,0),Vector3(side*1.12,6.45,0),0.035,mats.white_metal)
		_box(lamp,Vector3(0.62,0.08,0.23),Vector3(side*1.1,6.44,0),mats.light)

func _planter(at: Vector3, size_value: Vector3) -> void:
	var planter := _group("RaisedCoastalPlanter",at)
	_box(planter,size_value,Vector3(0,size_value.y*0.5,0),mats.stone,true)
	_box(planter,Vector3(size_value.x-0.25,0.055,size_value.z-0.25),Vector3(0,size_value.y+0.015,0),mats.soil)
	for i in range(7):
		var a := float(i)*2.4
		_shrub(planter,Vector3(cos(a)*size_value.x*0.32,size_value.y+0.04,sin(a)*size_value.z*0.31),0.48,i)

func _leaf_ribbon(surface: SurfaceTool, points: PackedVector3Array, width: float, tint: Color) -> void:
	# A folded, curved strip, never a large flat triangular leaf/card.
	for segment in range(points.size()-1):
		var t0 := float(segment)/float(points.size()-1)
		var t1 := float(segment+1)/float(points.size()-1)
		var tangent := (points[segment+1]-points[segment]).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		if side.length_squared()<0.1: side=Vector3.RIGHT
		var w0 := width*(0.12+sin(t0*PI)*0.88)*(1.0-t0*0.7)
		var w1 := width*(0.12+sin(t1*PI)*0.88)*(1.0-t1*0.7)
		var center0 := points[segment]
		var center1 := points[segment+1]
		var p := [center0-side*w0,center0+Vector3.UP*width*0.16,center0+side*w0,center1-side*w1,center1+Vector3.UP*width*0.16,center1+side*w1]
		# Upward-facing winding is essential: the former reversed faces made
		# every palm top receive the dark underside lighting in Compatibility.
		for n in [0,4,3,0,1,4,1,5,4,1,2,5]:
			surface.set_color(tint)
			surface.set_uv(Vector2(float(n%3)*0.5,t0 if n<3 else t1))
			surface.add_vertex(p[n])

func _shrub(parent: Node3D, at: Vector3, radius: float, variant: int = 0) -> void:
	var shrub := _group("SaltTolerantLeafyShrub",at,parent)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	var rng := RandomNumberGenerator.new()
	rng.seed=3471+variant*91
	for twig in range(30):
		var angle := rng.randf()*TAU
		var r := sqrt(rng.randf())*radius
		var tip := Vector3(cos(angle)*r,rng.randf_range(0.23,0.5)*radius/0.48,sin(angle)*r)
		for leaf_index in range(4):
			var t := 0.45+float(leaf_index)*0.16
			var origin := tip*t
			var leaf_angle := angle+float(leaf_index)*2.4
			var direction := Vector3(cos(leaf_angle),rng.randf_range(0.1,0.65),sin(leaf_angle))
			var length := rng.randf_range(0.10,0.17)*radius/0.48
			var points := PackedVector3Array([origin,origin+direction*length*0.5+Vector3.UP*0.025,origin+direction*length])
			var tint := Color(0.27,0.39,0.23).lerp(Color(0.42,0.50,0.29),rng.randf()*0.7)
			_leaf_ribbon(surface,points,length*0.30,tint)
	surface.generate_normals()
	_mesh(shrub,surface.commit(),mats.foliage)

func _frond_point(origin: Vector3, direction: Vector3, length: float, rise: float, droop: float, t: float) -> Vector3:
	return origin+direction*length*t+Vector3.UP*(sin(t*PI*0.9)*rise-droop*t*t)

func _palm(at: Vector3, height: float) -> void:
	var palm := _group("DatePalm",at)
	var lean := Vector3(0.35,0,0.18)
	for i in range(12):
		var t0 := float(i)/12.0
		var t1 := float(i+1)/12.0
		var a := Vector3(lean.x*t0*t0,height*t0,lean.z*t0*t0)
		var b := Vector3(lean.x*t1*t1,height*t1,lean.z*t1*t1)
		_beam(palm,a,b,lerpf(0.23,0.17,t0),mats.bark)
	for i in range(int(height*2.8)):
		var t := float(i)/(height*2.8)
		var ring := _cylinder(palm,lerpf(0.235,0.18,t),0.025,Vector3(lean.x*t*t,float(i)/2.8,lean.z*t*t),mats.bark,-1.0,12)
		ring.rotation.y = float(i)*0.8
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for frond in range(21):
		var a := float(frond)*2.39996
		var direction := Vector3(cos(a),0,sin(a))
		var across := Vector3(-sin(a),0,cos(a))
		var tier := frond%3
		var origin := Vector3(lean.x,height+float(tier)*0.12,lean.z)
		var length := 4.15-float(tier)*0.36
		var rise := 0.7+float(tier)*0.72
		var droop := 2.1-float(tier)*0.65
		var tint := Color(0.30,0.43,0.23).lerp(Color(0.43,0.53,0.29),float(frond%5)/7.0)
		var spine := PackedVector3Array()
		for segment in range(17):
			spine.append(_frond_point(origin,direction,length,rise,droop,float(segment)/16.0))
		_leaf_ribbon(surface,spine,0.027,Color(0.34,0.35,0.22))
		for pair in range(26):
			var t := 0.10+float(pair)*0.032
			var center := _frond_point(origin,direction,length,rise,droop,t)
			var leaf_length := (0.17+sin(t*PI)*0.68)*(0.94+sin(float(pair)*2.1)*0.06)
			for side in [-1.0,1.0]:
				var points := PackedVector3Array()
				for step in range(5):
					var s := float(step)/4.0
					points.append(center+across*leaf_length*float(side)*s+direction*(0.16*s+0.10*sin(s*PI))-Vector3.UP*((0.16+t*0.36)*s*s))
				_leaf_ribbon(surface,points,(0.032+t*0.014)*1.85,tint)
	surface.generate_normals()
	_mesh(palm,surface.commit(),mats.foliage)

func _lounger(at: Vector3, angle: float) -> void:
	var group := _group("BeachLounger",at)
	group.rotation.y = angle
	_box(group,Vector3(0.64,0.055,1.35),Vector3(0,0.32,0.15),mats.cream)
	var back := _box(group,Vector3(0.64,0.05,0.72),Vector3(0,0.57,-0.75),mats.cream)
	back.rotation.x = -0.65
	for x in [-0.27,0.27]:
		_beam(group,Vector3(x,0,0.6),Vector3(x,0.35,0.45),0.035,mats.white_metal)
		_beam(group,Vector3(x,0,-0.6),Vector3(x,0.35,-0.45),0.035,mats.white_metal)

func _lifeguard_tower(at: Vector3) -> void:
	var tower := _group("OranimWhiteTurquoiseLifeguardTower",at)
	_box(tower,Vector3(3.5,2.3,3.0),Vector3(0,3.25,0),mats.plaster,true)
	_box(tower,Vector3(3.8,0.22,3.3),Vector3(0,2.0,0),mats.turquoise,true)
	for x in [-1.5,1.5]:
		for z in [-1.2,1.2]:
			_box(tower,Vector3(0.18,2.0,0.18),Vector3(x,1.0,z),mats.turquoise,true)
	_box(tower,Vector3(4.2,0.18,3.6),Vector3(0,4.49,0),mats.red)
	for x in [-0.9,0.9]:
		_box(tower,Vector3(1.05,0.9,0.05),Vector3(x,3.5,1.52),mats.glass)
	for i in range(10):
		_box(tower,Vector3(1.0,0.18,0.35),Vector3(2.3,0.12+float(i)*0.2,2.2-float(i)*0.3),mats.turquoise,true)
	_beam(tower,Vector3(2.85,0.8,2.3),Vector3(2.85,2.8,-0.55),0.04,mats.white_metal)
	_label(tower,"02 · אורנים",Vector3(0,2.85,1.54),Color(0.18,0.29,0.32),0.006)
	_beam(tower,Vector3(0,4.5,0),Vector3(0,6.7,0),0.025,mats.metal)

func _build_foodcourt() -> void:
	# The east edge is an inhabited frontage, not an empty road.
	for i in range(4):
		var front := _group("LidoFoodcourtUnit_%d"%i,Vector3(21,0,29.0-float(i)*15.0))
		front.rotation.y = -PI*0.5
		_shop(front,13.5,7.0,i)
		for x in [-4.5,0.0,4.5]:
			_table_set(Vector3(x,0,6.7),0.3,front)
		_string_lights(front,Vector3(-6.6,3.4,8.8),Vector3(6.6,3.4,8.8))
	for z in [34.0,19.0,4.0,-11.0]:
		_palm(Vector3(14.8,0,z),7.9)
		_bin(Vector3(13.0,0,z+2.0))
	# White and amber fixed shades photographed at Lido.
	for z in [27.0,12.0,-3.0,-18.0]:
		_parasol(Vector3(14,0,z),mats.yellow)
	# A food trailer extends the Oranim outdoor-food vocabulary documented by Visit Ashdod.
	_food_trailer(Vector3(5.5,0,64.0),0.2)

func _shop(parent: Node3D, width: float, depth: float, variant: int) -> void:
	var facade: Material = mats.ochre if variant==0 else mats.plaster
	# The ground floor is an actual shallow interior behind glazing. Upper
	# masonry, side piers and the back wall leave real depth in the shop bays.
	_box(parent,Vector3(width,3.65,depth),Vector3(0,4.975,-depth*0.5),facade,true)
	_box(parent,Vector3(width,3.15,0.24),Vector3(0,1.575,-depth+0.12),facade,true)
	_box(parent,Vector3(width,0.10,depth),Vector3(0,0.05,-depth*0.5),mats.stone,true)
	_box(parent,Vector3(width,0.10,depth),Vector3(0,3.10,-depth*0.5),mats.interior)
	for side in [-1.0,1.0]:
		_box(parent,Vector3(0.28,3.15,depth),Vector3(float(side)*(width*0.5-0.14),1.575,-depth*0.5),facade,true)
	var bays := [-4.6,-1.55,1.55,4.6]
	for bay in range(bays.size()):
		var x: float = bays[bay]
		_shop_bay(parent,x,variant,bay)
		_box(parent,Vector3(2.85,2.45,0.055),Vector3(x,1.45,0.065),mats.display_glass,true)
		for edge in [-1.41,1.41]:
			_box(parent,Vector3(0.08,2.5,0.14),Vector3(x+edge,1.45,0.13),mats.dark_wood)
		for rail_y in [0.22,0.96,2.68]:
			_box(parent,Vector3(2.85,0.065,0.14),Vector3(x,rail_y,0.13),mats.dark_wood)
		_box(parent,Vector3(0.065,2.45,0.14),Vector3(x+0.42,1.45,0.13),mats.dark_wood)
		_beam(parent,Vector3(x+0.55,1.0,0.24),Vector3(x+0.55,1.4,0.24),0.023,mats.white_metal)
	_box(parent,Vector3(width+0.2,0.2,0.62),Vector3(0,3.02,0.28),mats.cream)
	for i in range(14):
		var stripe: Material = mats.cream if i%2==0 else mats.yellow
		var stripe_x := -width*0.5+(float(i)+0.5)*width/14.0
		var awning := _box(parent,Vector3(width/14.0,0.07,2.5),Vector3(stripe_x,2.85,1.35),stripe)
		awning.rotation.x = 0.12
		_box(parent,Vector3(width/14.0,0.22,0.055),Vector3(stripe_x,2.59,2.58),stripe)
	for x in [-6.2,6.2]:
		_beam(parent,Vector3(x,0,2.4),Vector3(x,2.7,2.4),0.055,mats.metal)
		_beam(parent,Vector3(x,2.97,0.15),Vector3(x,2.73,2.55),0.033,mats.metal)
	var names := ["לידו · מטבח ים", "קפה בטיילת", "שווארמה", "בר חוף"]
	_box(parent,Vector3(6.0,0.7,0.12),Vector3(0,3.6,0.12),mats.dark_wood)
	_label(parent,names[variant],Vector3(0,3.6,0.20),Color(0.97,0.88,0.68),0.007)
	var windows := [-4.8,-1.6,1.6,4.8]
	for window_index in range(windows.size()):
		var x: float = windows[window_index]
		_box(parent,Vector3(2.32,1.96,0.15),Vector3(x,5.18,0.06),mats.dark_wood)
		for pane in range(3):
			var pane_x := x+(float(pane)-1.0)*0.74
			_box(parent,Vector3(0.69,1.79,0.04),Vector3(pane_x,5.18,0.15),mats.window_light if (window_index+variant+pane)%3==0 else mats.glass)
			_box(parent,Vector3(0.045,1.90,0.12),Vector3(pane_x+0.36,5.18,0.19),mats.cream)
			if (window_index+variant)%2==0:
				for slat in range(7+pane):
					_box(parent,Vector3(0.67,0.058,0.055),Vector3(pane_x,5.99-float(slat)*0.12,0.21),mats.curtain)
			elif pane!=1:
				_box(parent,Vector3(0.34,1.73,0.035),Vector3(pane_x,5.18,0.205),mats.curtain)
		_box(parent,Vector3(2.3,0.055,0.12),Vector3(x,5.12,0.21),mats.cream)
		_box(parent,Vector3(2.35,0.13,0.4),Vector3(x,4.21,0.15),mats.cream)
	_box(parent,Vector3(width+0.35,0.2,depth+0.3),Vector3(0,6.88,-depth*0.5),mats.cream)
	for x in [-4.0,4.0]:
		_box(parent,Vector3(1.0,0.65,0.4),Vector3(x,3.55,0.40),mats.white_metal)
		var fan := _cylinder(parent,0.23,0.025,Vector3(x,3.55,0.62),mats.metal)
		fan.rotation.x = PI*0.5
	# Furnished counter frontage and operational-looking food display, all modeled.
	_box(parent,Vector3(2.6,1.0,0.8),Vector3(-3.9,0.5,3.0),mats.wood,true)
	_box(parent,Vector3(2.8,0.09,0.94),Vector3(-3.9,1.04,3.0),mats.white_metal)
	for i in range(4):
		_box(parent,Vector3(0.42,0.04,0.55),Vector3(-4.8+float(i)*0.57,1.10,3.0),mats.metal)
		var loaf := _sphere(parent,0.17,Vector3(-4.8+float(i)*0.57,1.20,3.0),mats.bread)
		loaf.scale = Vector3(1.0,0.45,0.70)
	_menu_board(parent,Vector3(0.15,1.13,3.12),1.15)
	if variant==2:
		var station := _group("ShawarmaFryerStation",Vector3(3.8,0,3.2),parent)
		station.add_to_group("environment_stations")
		_box(station,Vector3(2.0,0.96,0.82),Vector3(0,0.48,0),mats.white_metal,true)
		_box(station,Vector3(1.6,0.08,0.64),Vector3(0,0.99,0),mats.metal)
		for x in [-0.4,0.4]:
			_box(station,Vector3(0.55,0.03,0.44),Vector3(x,1.04,0),_plain(Color(0.31,0.20,0.08),0.18))
			_box(station,Vector3(0.1,0.06,0.42),Vector3(x,1.10,0.45),mats.rubber)
		var approach := Marker3D.new()
		approach.name="Approach"
		approach.position=Vector3(-0.4,0,1.4)
		station.add_child(approach)
		var contact := Marker3D.new()
		contact.name="Contact"
		contact.position=Vector3(-0.4,1.08,0.0)
		station.add_child(contact)

func _menu_panel(parent: Node3D, at: Vector3, width: float) -> void:
	_box(parent,Vector3(width+0.09,width*2.0/3.0+0.09,0.065),at-Vector3(0,0,0.025),mats.dark_wood)
	var panel := QuadMesh.new()
	panel.size = Vector2(width,width*2.0/3.0)
	_mesh(parent,panel,mats.menu,at+Vector3(0,0,0.012))

func _menu_board(parent: Node3D, at: Vector3, width: float) -> void:
	var board := _group("PrintedMenuAFrame",at,parent)
	board.rotation.x = -0.12
	_menu_panel(board,Vector3.ZERO,width)
	for x in [-width*0.43,width*0.43]:
		_beam(board,Vector3(x,-at.y,0.28),Vector3(x,width*0.36,0),0.032,mats.dark_wood)
		_beam(board,Vector3(x,-at.y,-0.36),Vector3(x,width*0.36,0),0.032,mats.dark_wood)

func _shop_bay(parent: Node3D, x: float, variant: int, bay: int) -> void:
	var interior := _group("VisibleShopInterior",Vector3(x,0,0),parent)
	_box(interior,Vector3(2.8,2.8,0.12),Vector3(0,1.45,-2.6),mats.interior)
	_box(interior,Vector3(2.45,0.92,0.50),Vector3(0,0.56,-0.65),mats.wood,true)
	_box(interior,Vector3(2.58,0.075,0.64),Vector3(0,1.05,-0.65),mats.cream)
	if bay==0 or bay==3:
		_menu_panel(interior,Vector3(0,1.98,-2.48),2.35)
	else:
		for shelf in range(3):
			var y := 0.88+float(shelf)*0.57
			_box(interior,Vector3(2.55,0.065,0.38),Vector3(0,y,-2.25),mats.dark_wood)
			for item in range(8):
				var item_x := -1.06+float(item)*0.30
				var drink_mat: Material = mats.bottle if (item+shelf+variant)%3!=0 else mats.jar
				_cylinder(interior,0.065,0.25,Vector3(item_x,y+0.16,-2.20),drink_mat,0.056,8)
				_cylinder(interior,0.031,0.08,Vector3(item_x,y+0.325,-2.20),drink_mat,-1.0,8)
				_box(interior,Vector3(0.11,0.10,0.025),Vector3(item_x,y+0.16,-2.13),mats.cream)
	for cup in range(4):
		_cylinder(interior,0.06,0.15,Vector3(-0.76+float(cup)*0.23,1.16,-0.58),mats.cream,0.075,12)
	if variant==1:
		_box(interior,Vector3(0.66,0.42,0.44),Vector3(0.60,1.30,-0.71),mats.white_metal)
		_box(interior,Vector3(0.51,0.16,0.04),Vector3(0.60,1.32,-0.46),mats.metal)
	else:
		for pastry in range(3):
			var loaf := _sphere(interior,0.14,Vector3(0.46+float(pastry)*0.20,1.16,-0.58),mats.bread)
			loaf.scale=Vector3(0.9,0.50,0.7)

func _string_lights(parent: Node3D, a: Vector3, b: Vector3) -> void:
	_beam(parent,Vector3(a.x,0,a.z),a,0.035,mats.metal)
	_beam(parent,Vector3(b.x,0,b.z),b,0.035,mats.metal)
	var last := a
	for i in range(1,19):
		var t := float(i)/18.0
		var point := a.lerp(b,t)-Vector3(0,sin(t*PI)*0.46,0)
		_beam(parent,last,point,0.012,mats.metal)
		_sphere(parent,0.065,point-Vector3(0,0.1,0),mats.light)
		last=point

func _food_trailer(at: Vector3, angle: float) -> void:
	var trailer := _group("OranimFoodTrailer",at)
	trailer.rotation.y=angle
	_box(trailer,Vector3(4.6,2.4,2.3),Vector3(0,1.6,0),mats.turquoise,true)
	_box(trailer,Vector3(3.3,1.0,0.06),Vector3(0,1.8,1.18),mats.glass)
	_box(trailer,Vector3(3.6,0.10,0.75),Vector3(0,1.30,1.45),mats.wood)
	var hatch := _box(trailer,Vector3(3.7,0.07,1.0),Vector3(0,2.46,1.6),mats.cream)
	hatch.rotation.x=-0.12
	for x in [-1.4,1.4]:
		var wheel := _cylinder(trailer,0.37,0.22,Vector3(x,0.37,1.17),mats.rubber)
		wheel.rotation.x=PI*0.5
	_label(trailer,"אורנים · אוכל מול הים",Vector3(0,2.79,1.18),Color(0.96,0.91,0.72),0.005)
	_table_set(Vector3(-2,0,3.6),0,trailer)
	_table_set(Vector3(2,0,3.6),0.5,trailer)

func _build_city() -> void:
	# The commercial plinth and residential towers follow the 2024 Ashdod Mall photo:
	# white textured cladding, blue window ribbons, green balcony rails and roof frames.
	_box(self,Vector3(10,0.13,200),Vector3(39,-0.04,0),mats.asphalt,true)
	for z in range(-90,91,10):
		_box(self,Vector3(0.10,0.015,3.8),Vector3(39,0.035,float(z)),mats.cream)
	for x in [33.6,44.4]:
		_box(self,Vector3(0.35,0.3,200),Vector3(x,0.12,0),mats.stone,true)
	var mall := _group("AshdodSeafrontCommercialPlinth",Vector3(55,0,10))
	mall.rotation.y=-PI*0.5
	_box(mall,Vector3(43,8.8,13),Vector3(0,4.4,-6.5),mats.plaster,true)
	for floor_index in range(3):
		for bay in range(18):
			var x := -20.0+float(bay)*2.35
			var y := 1.4+float(floor_index)*2.8
			_box(mall,Vector3(2.20,1.85,0.09),Vector3(x,y,0.1),mats.glass)
			_box(mall,Vector3(0.055,1.9,0.13),Vector3(x,y,0.16),mats.white_metal)
	_box(mall,Vector3(43.4,0.22,13.4),Vector3(0,8.9,-6.5),mats.cream)
	_label(mall,"אשדוד · מרכז הטיילת",Vector3(0,7.95,0.22),Color(0.15,0.31,0.37),0.012)
	_tower(Vector3(60,8.9,8),10,8,7,0)
	_tower(Vector3(64,0,-30),12,12,9,1)
	_tower(Vector3(49,0,57),11,11,11,2)
	_tower(Vector3(67,0,-67),15,13,8,3)
	_tower(Vector3(85,0,45),15,16,14,0)
	for z in [-42.0,-27.0,-11.0,7.0,22.0,43.0,64.0]:
		_car(Vector3(31.0,0.0,z),PI*0.5,int(z))

func _tower(at: Vector3, width: float, depth: float, floors: int, variant: int) -> void:
	var tower := _group("WhiteCoastalResidentialTower",at)
	tower.rotation.y=-PI*0.5
	var height := float(floors)*2.8
	_box(tower,Vector3(width,height,depth),Vector3(0,height*0.5,-depth*0.5),mats.plaster,true)
	for floor_index in range(floors):
		var y := float(floor_index)*2.8+1.4
		for side in [-1.0,1.0]:
			var x: float = float(side)*width*0.28
			_box(tower,Vector3(width*0.33,1.75,0.075),Vector3(x,y,0.06),mats.glass)
			_box(tower,Vector3(width*0.39,0.16,1.55),Vector3(x,y-0.95,0.65),mats.cream)
			_box(tower,Vector3(width*0.36,0.86,0.065),Vector3(x,y-0.45,1.37),mats.balcony)
			_box(tower,Vector3(0.07,0.9,1.35),Vector3(x-side*width*0.18,y-0.43,0.7),mats.white_metal)
			_beam(tower,Vector3(x-width*0.18,y+0.02,1.40),Vector3(x+width*0.18,y+0.02,1.40),0.035,mats.white_metal)
			if (floor_index+variant)%3==0:
				_box(tower,Vector3(0.7,0.3,0.3),Vector3(x, y-0.72,1.1),mats.ochre)
				_shrub(tower,Vector3(x,y-0.55,1.1),0.24,floor_index)
			_box(tower,Vector3(0.8,0.6,0.33),Vector3(side*width*0.46,y-0.5,0.22),mats.cream)
		# Narrow side windows, visible from the promenade oblique view.
		for z in [-depth*0.28,-depth*0.7]:
			_box(tower,Vector3(0.07,1.4,1.1),Vector3(-width*0.5-0.04,y,z),mats.glass)
	_box(tower,Vector3(width+0.3,0.24,depth+0.3),Vector3(0,height+0.12,-depth*0.5),mats.cream)
	for x in [-width*0.4,width*0.4]:
		_box(tower,Vector3(0.3,2.0,0.3),Vector3(x,height+1.0,-depth*0.3),mats.plaster)
	_box(tower,Vector3(width*0.83,0.30,0.3),Vector3(0,height+2.0,-depth*0.3),mats.plaster)
	_cylinder(tower,0.65,1.1,Vector3(1.3,height+0.7,-depth*0.65),mats.white_metal)
	_beam(tower,Vector3(-1,height,-depth*0.5),Vector3(-1,height+3.4,-depth*0.5),0.028,mats.metal)

func _car(at: Vector3, angle: float, variant: int) -> void:
	var car := _group("ParkedSeafrontCar",at)
	car.rotation.y=angle
	var color := Color(0.77,0.79,0.78) if variant%2==0 else Color(0.17,0.22,0.25)
	var body_mat := _plain(color,0.23,0.5)
	_box(car,Vector3(1.75,0.55,4.0),Vector3(0,0.65,0),body_mat,true)
	_box(car,Vector3(1.55,0.67,2.1),Vector3(0,1.16,-0.2),mats.glass)
	_box(car,Vector3(1.58,0.1,2.15),Vector3(0,1.52,-0.2),body_mat)
	for x in [-0.88,0.88]:
		for z in [-1.22,1.22]:
			var wheel := _cylinder(car,0.34,0.22,Vector3(x,0.34,z),mats.rubber)
			wheel.rotation.z=PI*0.5
	for x in [-0.6,0.6]:
		_box(car,Vector3(0.43,0.17,0.08),Vector3(x,0.69,2.02),mats.cream)
		_box(car,Vector3(0.40,0.16,0.08),Vector3(x,0.68,-2.02),mats.red)

func _arch(parent: Node3D, at: Vector3, radius: float, spring: float, top: float, depth: float) -> void:
	var group := _group("MasonryArch",at,parent)
	var pillar := 0.65
	_box(group,Vector3(pillar,top,depth),Vector3(-radius-pillar*0.5,top*0.5,0),mats.stone,true)
	_box(group,Vector3(pillar,top,depth),Vector3(radius+pillar*0.5,top*0.5,0),mats.stone,true)
	var mesh_value := SurfaceTool.new()
	mesh_value.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(28):
		var x0 := -radius+2.0*radius*float(i)/28.0
		var x1 := -radius+2.0*radius*float(i+1)/28.0
		var y0 := spring+sqrt(maxf(0.0,radius*radius-x0*x0))
		var y1 := spring+sqrt(maxf(0.0,radius*radius-x1*x1))
		var p := [Vector3(x0,y0,depth*0.5),Vector3(x1,y1,depth*0.5),Vector3(x1,top,depth*0.5),Vector3(x0,top,depth*0.5),Vector3(x0,y0,-depth*0.5),Vector3(x1,y1,-depth*0.5),Vector3(x1,top,-depth*0.5),Vector3(x0,top,-depth*0.5)]
		for face in [[0,1,2,0,2,3],[5,4,7,5,7,6],[4,5,1,4,1,0],[3,2,6,3,6,7]]:
			for n in face:
				mesh_value.set_uv(Vector2(p[n].x,p[n].y)*0.5)
				mesh_value.add_vertex(p[n])
	mesh_value.generate_normals()
	var instance := _mesh(group,mesh_value.commit(),mats.stone)
	instance.create_trimesh_collision()

func _build_arches() -> void:
	var plaza := _group("HaKshatotArchesAndFoodPlaza",Vector3(5,0,-62))
	_box(plaza,Vector3(49,0.26,37),Vector3(0,-0.13,0),mats.paving,true)
	for i in range(5):
		var x := (float(i)-2.0)*6.2
		var height := 8.9 if i==2 else 8.0
		_arch(plaza,Vector3(x,0,-5),2.75,5.0 if i==2 else 4.1,height,1.2)
		if i<4:
			_box(plaza,Vector3(6.2,0.32,3.5),Vector3(x+3.1,3.45,-6.1),mats.stone,true)
	for side in [-1.0,1.0]:
		var wing := _group("ArchedRestaurantWing",Vector3(side*19.0,0,-4),plaza)
		_box(wing,Vector3(8.5,4.0,11),Vector3(0,2,-5),mats.stone,true)
		_arch(wing,Vector3(0,0,0.8),2.6,1.2,4.2,0.7)
		_box(wing,Vector3(4.9,2.7,0.08),Vector3(0,1.35,0.4),mats.glass)
		_box(wing,Vector3(7.0,0.13,3.2),Vector3(0,2.9,2.2),mats.cream)
		_label(wing,"אוכל · קפה · ים",Vector3(0,3.57,1.2),Color(0.25,0.29,0.25),0.0055)
		for x in [-2.1,2.1]:
			_table_set(Vector3(x,0,3.5),0,wing)
		_palm(Vector3(5+side*16.0,0,-51),9.5)
		_bench(Vector3(5+side*15.8,0,-47),0)
	# Access steps and a physically continuous elevated promenade, useful for later traversal.
	for i in range(7):
		var step_height := float(i+1)*0.18
		_box(plaza,Vector3(2.8,step_height,0.65),Vector3(13.8,step_height*0.5,-10.0-float(i)*0.65),mats.stone,true)
	_box(plaza,Vector3(7.5,1.25,3.0),Vector3(11.5,0.625,-15.1),mats.stone,true)

func _build_review_camera() -> void:
	camera=Camera3D.new()
	camera.name="EnvironmentReviewCamera"
	camera.fov=66
	camera.far=750
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
	panel.position=Vector2(22,20)
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.04,0.09,0.11,0.82)
	style.content_margin_left=16
	style.content_margin_right=16
	style.content_margin_top=12
	style.content_margin_bottom=12
	panel.add_theme_stylebox_override("panel",style)
	hud.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text="АШДОД · НАБЕРЕЖНАЯ"
	title.add_theme_font_size_override("font_size",20)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text="Лидо / Ораним / площадь арок\nПКМ — осмотр · WASD — движение · Q/E — вниз/вверх\nShift — быстрее · Tab — убрать интерфейс"
	subtitle.add_theme_font_size_override("font_size",12)
	column.add_child(subtitle)
	var row := HBoxContainer.new()
	column.add_child(row)
	var captions := ["Набережная","Кафе","Арки","Пляж","Панорама"]
	for i in range(captions.size()):
		var button := Button.new()
		button.text=captions[i]
		button.custom_minimum_size=Vector2(70,36)
		button.pressed.connect(_viewpoint.bind(i))
		row.add_child(button)
	var note := Label.new()
	note.text="Сцена по фотографиям реального Ашдода. Расстояния сжаты для игры."
	note.add_theme_font_size_override("font_size",11)
	column.add_child(note)

func _viewpoint(index: int) -> void:
	var positions := [Vector3(-1.5,2.5,38),Vector3(3.3,2.1,10),Vector3(4,2.8,-33),Vector3(-22,2.4,7),Vector3(-36,19,66)]
	var targets := [Vector3(7,3,-17),Vector3(22,3,0),Vector3(5,5,-64),Vector3(-7,3,-18),Vector3(17,7,-24)]
	camera.position=positions[index]
	camera.look_at(targets[index])
	fly_yaw=camera.rotation.y
	fly_pitch=camera.rotation.x

func _unhandled_input(event: InputEvent) -> void:
	if not review_camera_enabled:
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		looking=event.pressed
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and looking:
		fly_yaw-=event.relative.x*0.003
		fly_pitch=clampf(fly_pitch-event.relative.y*0.003,-1.4,1.4)
		camera.rotation=Vector3(fly_pitch,fly_yaw,0)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_TAB:
			hud.visible=not hud.visible
		if event.physical_keycode==KEY_ESCAPE:
			looking=false
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if not review_camera_enabled or camera==null:
		return
	var movement := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):movement.z-=1
	if Input.is_physical_key_pressed(KEY_S):movement.z+=1
	if Input.is_physical_key_pressed(KEY_A):movement.x-=1
	if Input.is_physical_key_pressed(KEY_D):movement.x+=1
	if Input.is_physical_key_pressed(KEY_Q):movement.y-=1
	if Input.is_physical_key_pressed(KEY_E):movement.y+=1
	var speed := 18.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 5.5
	if movement.length()>0:
		camera.position+=camera.global_transform.basis*movement.normalized()*speed*delta
		camera.position.y=maxf(0.35,camera.position.y)
