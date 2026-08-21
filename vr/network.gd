extends Node

const PORT := 48150
const MAGIC := "PCVR1"
var socket := PacketPeerUDP.new()
var connected := false
var frame_id := -1
var chunks := {}
var expected := 0
signal frame_ready(image: Image)
signal connection_lost

func connect_to_pc(ip: String) -> String:
    socket.close()
    var err := socket.bind(0)
    if err != OK:
        return "Could not open UDP socket: %s" % err
    socket.set_dest_address(ip, PORT)
    socket.put_packet("HELLO PCVR1".to_utf8_buffer())
    connected = true
    return "Connecting to %s:%d" % [ip, PORT]

func send_input(message: String) -> void:
    if not connected:
        return
    socket.put_packet(("INPUT " + message).to_utf8_buffer())

func mouse_move(x: float, y: float) -> void:
    send_input("MOUSE %.5f %.5f" % [clamp(x, 0.0, 1.0), clamp(y, 0.0, 1.0)])

func mouse_click(button: String = "left") -> void:
    send_input("CLICK %s" % button)

func key_press(key: String) -> void:
    send_input("KEY " + key)

func _process(_delta: float) -> void:
    if not connected:
        return
    while socket.get_available_packet_count() > 0:
        var p := socket.get_packet()
        if p.size() >= 7 and p.slice(0, 7) == "WELCOME".to_utf8_buffer():
            continue
        if p.size() < 13 or p.slice(0, 5) != MAGIC.to_utf8_buffer():
            continue
        var id := p.decode_u32(5)
        var index := p.decode_u16(9)
        var count := p.decode_u16(11)
        if id != frame_id:
            frame_id = id
            chunks.clear()
            expected = count
        chunks[index] = p.slice(13)
        if chunks.size() == expected:
            var bytes := PackedByteArray()
            var complete := true
            for i in range(expected):
                if not chunks.has(i):
                    complete = false
                    break
                bytes.append_array(chunks[i])
            if complete:
                var image := Image.new()
                if image.load_jpg_from_buffer(bytes) == OK:
                    frame_ready.emit(image)
            chunks.clear()
