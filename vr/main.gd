extends Node3D

const SCREEN_SIZE := Vector2(2.80, 1.575)
var screen: MeshInstance3D
var screen_body: StaticBody3D
var texture: ImageTexture
var camera: Camera3D
var panel: Control
var ip_edit: LineEdit
var status: Label
var dragging := false
var last_touch := Vector2.ZERO

func _ready() -> void:
    _build_environment()
    _build_camera()
    _build_connect_ui()
    Network.frame_ready.connect(_on_frame)

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 1.55, 3.8)
    camera.look_at_from_position(camera.position, Vector3(0, 1.25, -1.5))
    camera.current = true
    camera.fov = 65.0
    add_child(camera)

func _build_environment() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.025, 0.03, 0.045)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.55, 0.58, 0.65)
    env.ambient_light_energy = 1.0
    env_node.environment = env
    add_child(env_node)

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
    screen_mat.albedo_color = Color(0.08, 0.09, 0.11)
    screen.material_override = screen_mat
    add_child(screen)
    screen_body = _make_box_body("TouchscreenInput", screen.position, Vector3(SCREEN_SIZE.x, SCREEN_SIZE.y, 0.10), Color.TRANSPARENT)
    screen_body.get_child(0).visible = false
    screen_body.set_meta("pcvr_type", "screen")

    _add_box("PC_Tower", Vector3(1.55, 0.95, -1.55), Vector3(0.62, 1.10, 0.72), Color(0.045, 0.05, 0.06), false)
    _add_box("TowerGlass", Vector3(1.55, 0.97, -1.19), Vector3(0.48, 0.82, 0.025), Color(0.08, 0.12, 0.15), false)
    _build_keyboard(Vector3(-0.25, 0.91, -1.12))
    _build_mouse(Vector3(1.12, 0.92, -1.13))
    _build_speakers()

func _build_connect_ui() -> void:
    panel = Control.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(panel)
    var box := PanelContainer.new()
    box.position = Vector2(24, 24)
    box.size = Vector2(430, 245)
    panel.add_child(box)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 16)
    box.add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    margin.add_child(column)
    var title := Label.new()
    title.text = "CONNECT TO PC"
    title.add_theme_font_size_override("font_size", 26)
    column.add_child(title)
    ip_edit = LineEdit.new()
    ip_edit.placeholder_text = "PC IP, e.g. 192.168.1.20"
    ip_edit.text = "192.168.1.20"
    column.add_child(ip_edit)
    var connect := Button.new()
    connect.text = "CONNECT"
    connect.custom_minimum_size = Vector2(0, 48)
    connect.pressed.connect(_connect)
    column.add_child(connect)
    status = Label.new()
    status.text = "Same Wi-Fi network required."
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(status)
    var hint := Label.new()
    hint.text = "After connecting, tap the virtual monitor, keyboard or mouse."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(hint)

func _connect() -> void:
    var ip := ip_edit.text.strip_edges()
    status.text = Network.connect_to_pc(ip)
    panel.visible = false

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            last_touch = event.position
            dragging = true
            _touch_world(event.position)
        else:
            dragging = false
    elif event is InputEventScreenDrag:
        if dragging:
            _touch_world(event.position)

func _touch_world(screen_pos: Vector2) -> void:
    if camera == null:
        return
    var from := camera.project_ray_origin(screen_pos)
    var to := from + camera.project_ray_normal(screen_pos) * 20.0
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var collider = hit["collider"]
    var point: Vector3 = hit["position"]
    if collider is Node and collider.has_meta("pcvr_type"):
        var kind: String = collider.get_meta("pcvr_type")
        if kind == "screen":
            _update_mouse_from_screen(point)
        elif event_is_tap():
            _activate_target(collider)

func event_is_tap() -> bool:
    return true

func _update_mouse_from_screen(point: Vector3) -> void:
    var local := screen.to_local(point)
    var nx := clamp(local.x / SCREEN_SIZE.x + 0.5, 0.0, 1.0)
    var ny := clamp(0.5 - local.y / SCREEN_SIZE.y, 0.0, 1.0)
    Network.mouse_move(nx, ny)

func _activate_target(collider: Node) -> void:
    var kind: String = collider.get_meta("pcvr_type")
    if kind == "screen":
        Network.mouse_click("left")
    elif kind == "key":
        Network.key_press(str(collider.get_meta("pcvr_key")))
    elif kind == "mouse":
        Network.mouse_click("left")

func _build_keyboard(base: Vector3) -> void:
    var keyboard_base := _make_box_body("Keyboard", base + Vector3(0, 0.04, 0), Vector3(2.65, 0.10, 0.86), Color(0.035, 0.04, 0.05))
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
        var x := -float(row.size()) * 0.11
        for item in row:
            var label: String = item[0]
            var value: String = item[1]
            var width := 0.19
            if label in ["BACK", "ENTER", "SHIFT", "CAPS"]: width = 0.30
            elif label == "TAB": width = 0.27
            var key_body := _make_box_body("Key_" + label, base + Vector3(x + width * 0.5, 0.14, row_z[r]), Vector3(width - 0.018, 0.10, 0.17), Color(0.075, 0.085, 0.10))
            key_body.set_meta("pcvr_type", "key")
            key_body.set_meta("pcvr_key", value)
            var text := Label3D.new()
            text.text = label
            text.font_size = 28
            text.outline_size = 5
            text.position = Vector3(0, 0.055, 0)
            text.rotation_degrees = Vector3(-90, 0, 0)
            key_body.add_child(text)
            x += width + 0.03
    var space := _make_box_body("Key_SPACE", base + Vector3(0, 0.14, 0.49), Vector3(1.05, 0.10, 0.17), Color(0.075, 0.085, 0.10))
    space.set_meta("pcvr_type", "key")
    space.set_meta("pcvr_key", "space")
    var space_text := Label3D.new()
    space_text.text = "SPACE"
    space_text.font_size = 28
    space_text.rotation_degrees = Vector3(-90, 0, 0)
    space.add_child(space_text)

func _build_mouse(pos: Vector3) -> void:
    var body := _make_box_body("Mouse", pos, Vector3(0.34, 0.13, 0.55), Color(0.045, 0.05, 0.06))
    body.set_meta("pcvr_type", "mouse")
    var label := Label3D.new()
    label.text = "MOUSE"
    label.font_size = 26
    label.rotation_degrees = Vector3(-90, 0, 0)
    body.add_child(label)

func _build_speakers() -> void:
    for x in [-1.72, 1.72]:
        _add_box("Speaker", Vector3(x, 1.0, -1.95), Vector3(0.34, 0.58, 0.30), Color(0.035, 0.038, 0.045), false)

func _add_box(name: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> Node3D:
    if collision:
        return _make_box_body(name, pos, size, color)
    var node := MeshInstance3D.new()
    node.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    node.material_override = mat
    add_child(node)
    return node

func _make_box_body(name: String, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
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
    mesh_node.material_override = mat
    body.add_child(mesh_node)
    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = size
    shape.shape = box_shape
    body.add_child(shape)
    return body

func _on_frame(image: Image) -> void:
    if texture == null:
        texture = ImageTexture.create_from_image(image)
        var mat := screen.material_override as StandardMaterial3D
        mat.albedo_texture = texture
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
    else:
        texture.update(image)
