extends Node3D

const SCREEN_SIZE := Vector2(2.80, 1.575)
const SCREEN_RES := Vector2(1280.0, 720.0)
const ROOM_SIZE := Vector3(6.0, 3.0, 6.0)

var screen: MeshInstance3D
var screen_body: StaticBody3D
var texture: ImageTexture
var panel: Control
var ip_edit: LineEdit
var status: Label
var left_controller: XRController3D
var right_controller: XRController3D
var left_ray: RayCast3D
var right_ray: RayCast3D
var pointer: MeshInstance3D
var last_trigger_left := false
var last_trigger_right := false
var keyboard_keys: Array[StaticBody3D] = []

func _ready() -> void:
    var xr := XRServer.find_interface("OpenXR")
    if xr and not xr.is_initialized():
        xr.initialize()
    if xr and xr.is_initialized():
        XRServer.primary_interface = xr
        get_viewport().use_xr = true

    _build_environment()
    _build_xr_rig()
    _build_connect_ui()
    Network.frame_ready.connect(_on_frame)

func _build_environment() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.025, 0.03, 0.045)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.42, 0.45, 0.52)
    environment.ambient_light_energy = 0.8
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = environment
    add_child(env)

    _add_box("Floor", Vector3(0, -0.06, -1.0), Vector3(5.5, 0.12, 5.5), Color(0.07, 0.08, 0.10), false)
    _add_box("BackWall", Vector3(0, 1.7, -3.4), Vector3(5.5, 3.4, 0.12), Color(0.055, 0.06, 0.075), false)
    _add_box("Desk", Vector3(0, 0.78, -1.35), Vector3(4.2, 0.18, 1.65), Color(0.20, 0.13, 0.09), false)
    _add_box("DeskFront", Vector3(0, 0.40, -0.62), Vector3(4.2, 0.65, 0.12), Color(0.15, 0.09, 0.06), false)

    _add_box("MonitorFrame", Vector3(0, 1.68, -2.05), Vector3(3.05, 1.80, 0.14), Color(0.025, 0.028, 0.035), false)
    _add_box("MonitorStand", Vector3(0, 0.98, -2.02), Vector3(0.16, 0.72, 0.16), Color(0.07, 0.075, 0.09), false)
    _add_box("MonitorFoot", Vector3(0, 0.86, -2.02), Vector3(1.05, 0.08, 0.50), Color(0.06, 0.065, 0.075), false)

    var quad := QuadMesh.new()
    quad.size = SCREEN_SIZE
    screen = MeshInstance3D.new()
    screen.name = "TouchscreenMonitor"
    screen.mesh = quad
    screen.position = Vector3(0, 1.68, -2.125)
    var screen_mat := StandardMaterial3D.new()
    screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    screen_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    screen_mat.albedo_color = Color.WHITE
    screen.material_override = screen_mat
    add_child(screen)

    screen_body = _make_box_body("TouchscreenInput", screen.position, Vector3(SCREEN_SIZE.x, SCREEN_SIZE.y, 0.10), Color.TRANSPARENT, false)
    screen_body.get_child(0).visible = false
    screen_body.set_meta("pcvr_type", "screen")

    _add_box("PC_Tower", Vector3(1.55, 0.95, -1.55), Vector3(0.62, 1.10, 0.72), Color(0.045, 0.05, 0.06), false)
    _add_box("TowerGlass", Vector3(1.55, 0.97, -1.19), Vector3(0.48, 0.82, 0.025), Color(0.08, 0.12, 0.15), false)
    _add_box("TowerLight", Vector3(1.55, 0.62, -1.14), Vector3(0.32, 0.025, 0.025), Color(0.15, 0.55, 1.0), false)

    _build_keyboard(Vector3(-0.25, 0.91, -1.12))
    _build_mouse(Vector3(1.12, 0.92, -1.13))
    _build_speakers()

func _build_xr_rig() -> void:
    var origin := XROrigin3D.new()
    origin.name = "XROrigin3D"
    origin.current = true
    origin.world_scale = 1.0
    add_child(origin)

    var camera := XRCamera3D.new()
    camera.name = "XRCamera3D"
    camera.near = 0.03
    camera.far = 100.0
    origin.add_child(camera)

    left_controller = _make_controller(origin, "LeftHand", "/user/hand/left")
    right_controller = _make_controller(origin, "RightHand", "/user/hand/right")
    left_ray = _make_ray(left_controller)
    right_ray = _make_ray(right_controller)

    pointer = MeshInstance3D.new()
    var pointer_mesh := SphereMesh.new()
    pointer_mesh.radius = 0.018
    pointer_mesh.height = 0.036
    pointer.mesh = pointer_mesh
    var pointer_mat := StandardMaterial3D.new()
    pointer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    pointer_mat.albedo_color = Color(0.2, 0.85, 1.0)
    pointer.material_override = pointer_mat
    add_child(pointer)
    pointer.visible = false

func _make_controller(parent: Node, controller_name: String, tracker_name: String) -> XRController3D:
    var controller := XRController3D.new()
    controller.name = controller_name
    controller.tracker = tracker_name
    controller.pose = "aim"
    controller.show_when_tracked = true
    parent.add_child(controller)
    return controller

func _make_ray(parent: Node3D) -> RayCast3D:
    var ray := RayCast3D.new()
    ray.name = "InteractionRay"
    ray.target_position = Vector3(0, 0, -5.0)
    ray.collision_mask = 1
    ray.collide_with_bodies = true
    ray.enabled = true
    parent.add_child(ray)
    return ray

func _build_connect_ui() -> void:
    panel = Control.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(panel)

    var box := PanelContainer.new()
    box.position = Vector2(40, 40)
    box.size = Vector2(420, 230)
    panel.add_child(box)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_bottom", 16)
    box.add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    margin.add_child(column)

    var title := Label.new()
    title.text = "CONNECT TO PC VR"
    title.add_theme_font_size_override("font_size", 26)
    column.add_child(title)

    ip_edit = LineEdit.new()
    ip_edit.placeholder_text = "PC IP, e.g. 192.168.1.20"
    ip_edit.text = "192.168.1.20"
    column.add_child(ip_edit)

    var connect := Button.new()
    connect.text = "CONNECT TO PC"
    connect.custom_minimum_size = Vector2(0, 44)
    connect.pressed.connect(_connect)
    column.add_child(connect)

    status = Label.new()
    status.text = "Enter the PC IP address."
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(status)

    var hint := Label.new()
    hint.text = "After connecting: point at the monitor, squeeze the trigger to click, and point at keyboard keys to type."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(hint)

func _connect() -> void:
    var ip := ip_edit.text.strip_edges()
    status.text = Network.connect_to_pc(ip)
    panel.visible = false

func _build_keyboard(base: Vector3) -> void:
    var keyboard_base := _make_box_body("Keyboard", base + Vector3(0, 0.04, 0), Vector3(2.65, 0.10, 0.86), Color(0.035, 0.04, 0.05), false)
    keyboard_base.set_meta("pcvr_type", "keyboard")

    var rows := [
        [["ESC", "esc"], ["1", "1"], ["2", "2"], ["3", "3"], ["4", "4"], ["5", "5"], ["6", "6"], ["7", "7"], ["8", "8"], ["9", "9"], ["0", "0"], ["BACK", "backspace"]],
        [["TAB", "tab"], ["Q", "q"], ["W", "w"], ["E", "e"], ["R", "r"], ["T", "t"], ["Y", "y"], ["U", "u"], ["I", "i"], ["O", "o"], ["P", "p"]],
        [["CAPS", "capslock"], ["A", "a"], ["S", "s"], ["D", "d"], ["F", "f"], ["G", "g"], ["H", "h"], ["J", "j"], ["K", "k"], ["L", "l"], ["ENTER", "enter"]],
        [["SHIFT", "shift"], ["Z", "z"], ["X", "x"], ["C", "c"], ["V", "v"], ["B", "b"], ["N", "n"], ["M", "m"], [",", ","], [".", "."], ["SHIFT", "shift"]]
    ]
    var row_z := [-0.31, -0.10, 0.11, 0.32]
    for r in range(rows.size()):
        var row = rows[r]
        var total_width := float(row.size()) * 0.22
        var x := -total_width * 0.5 + 0.11
        for item in row:
            var key_label: String = item[0]
            var key_value: String = item[1]
            var width := 0.19
            if key_label == "BACK" or key_label == "ENTER":
                width = 0.30
            elif key_label == "SHIFT" or key_label == "CAPS":
                width = 0.30
            elif key_label == "TAB":
                width = 0.27
            var key_body := _add_key(key_label, key_value, base + Vector3(x + width * 0.5, 0.14, row_z[r]), Vector3(width - 0.018, 0.10, 0.17))
            keyboard_keys.append(key_body)
            x += width + 0.03

    var space := _add_key("SPACE", "space", base + Vector3(0, 0.14, 0.49), Vector3(1.05, 0.10, 0.17))
    keyboard_keys.append(space)

func _add_key(label: String, key: String, pos: Vector3, size: Vector3) -> StaticBody3D:
    var body := _make_box_body("Key_" + label, pos, size, Color(0.075, 0.085, 0.10), true)
    body.set_meta("pcvr_type", "key")
    body.set_meta("pcvr_key", key)
    var text := Label3D.new()
    text.text = label
    text.font_size = 32
    text.outline_size = 6
    text.modulate = Color(0.88, 0.92, 1.0)
    text.position = Vector3(0, size.y * 0.52 + 0.002, 0)
    text.rotation_degrees = Vector3(-90, 0, 0)
    body.add_child(text)
    return body

func _build_mouse(pos: Vector3) -> void:
    var body := _make_box_body("Mouse", pos, Vector3(0.34, 0.13, 0.55), Color(0.045, 0.05, 0.06), true)
    body.set_meta("pcvr_type", "mouse")
    var left := _add_mesh_box(body, Vector3(-0.085, 0.075, -0.07), Vector3(0.15, 0.025, 0.32), Color(0.08, 0.09, 0.11))
    left.name = "MouseLeftButton"
    var right := _add_mesh_box(body, Vector3(0.085, 0.075, -0.07), Vector3(0.15, 0.025, 0.32), Color(0.08, 0.09, 0.11))
    right.name = "MouseRightButton"
    var wheel := MeshInstance3D.new()
    var wheel_mesh := CylinderMesh.new()
    wheel_mesh.top_radius = 0.035
    wheel_mesh.bottom_radius = 0.035
    wheel_mesh.height = 0.075
    wheel.mesh = wheel_mesh
    wheel.rotation_degrees = Vector3(90, 0, 0)
    wheel.position = Vector3(0, 0.095, 0.02)
    var wheel_mat := StandardMaterial3D.new()
    wheel_mat.albedo_color = Color(0.2, 0.22, 0.25)
    wheel.material_override = wheel_mat
    body.add_child(wheel)

func _build_speakers() -> void:
    for x in [-1.72, 1.72]:
        _add_box("Speaker", Vector3(x, 1.0, -1.95), Vector3(0.34, 0.58, 0.30), Color(0.035, 0.038, 0.045), false)
        _add_box("SpeakerGrille", Vector3(x, 1.0, -1.785), Vector3(0.23, 0.36, 0.02), Color(0.075, 0.08, 0.09), false)

func _add_box(name: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> Node3D:
    if collision:
        return _make_box_body(name, pos, size, color, false)
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mesh_node.material_override = mat
    add_child(mesh_node)
    return mesh_node

func _add_mesh_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mesh_node.material_override = mat
    parent.add_child(mesh_node)
    return mesh_node

func _make_box_body(name: String, pos: Vector3, size: Vector3, color: Color, collision_only: bool) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = name
    body.position = pos
    body.collision_layer = 1
    body.collision_mask = 1
    add_child(body)

    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    if collision_only:
        mat.metallic = 0.05
        mat.roughness = 0.45
    mesh_node.material_override = mat
    body.add_child(mesh_node)

    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = size
    shape.shape = box_shape
    body.add_child(shape)
    return body

func _physics_process(_delta: float) -> void:
    _process_controller(right_controller, right_ray, true)
    _process_controller(left_controller, left_ray, false)

func _process_controller(controller: XRController3D, ray: RayCast3D, primary: bool) -> void:
    if controller == null or ray == null:
        return
    if not controller.get_is_active():
        return

    ray.force_raycast_update()
    if ray.is_colliding():
        var point := ray.get_collision_point()
        pointer.global_position = point
        pointer.visible = primary
        var collider := ray.get_collider()
        if collider is Node and collider.has_meta("pcvr_type"):
            var kind: String = collider.get_meta("pcvr_type")
            if kind == "screen":
                _update_mouse_from_screen(point)

    var trigger := controller.is_button_pressed("trigger_click")
    var just_pressed := trigger and (not last_trigger_right if primary else not last_trigger_left)
    if just_pressed and ray.is_colliding():
        var collider := ray.get_collider()
        if collider is Node and collider.has_meta("pcvr_type"):
            _activate_target(collider, ray.get_collision_point())

    if primary:
        last_trigger_right = trigger
    else:
        last_trigger_left = trigger

func _update_mouse_from_screen(point: Vector3) -> void:
    var local := screen.to_local(point)
    var nx := clamp(local.x / SCREEN_SIZE.x + 0.5, 0.0, 1.0)
    var ny := clamp(0.5 - local.y / SCREEN_SIZE.y, 0.0, 1.0)
    Network.mouse_move(nx, ny)

func _activate_target(collider: Node, _point: Vector3) -> void:
    var kind: String = collider.get_meta("pcvr_type")
    if kind == "screen":
        Network.mouse_click("left")
    elif kind == "key":
        Network.key_press(str(collider.get_meta("pcvr_key")))
    elif kind == "mouse":
        Network.mouse_click("left")

func _on_frame(image: Image) -> void:
    if texture == null:
        texture = ImageTexture.create_from_image(image)
        var mat := screen.material_override as StandardMaterial3D
        mat.albedo_texture = texture
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
    else:
        texture.update(image)
