extends Node

const PORT := 48150
const MAGIC := "PCVR1".to_utf8_buffer()
var socket := PacketPeerUDP.new()
var connected := false
var frame_id := -1
var chunks := {}
var expected := 0
signal frame_ready(image: Image)

func connect_to_pc(ip: String) -> String:
    socket.close()
    var err = socket.bind(0)
    if err != OK:
        return "Could not open UDP socket: %s" % err
    socket.set_dest_address(ip, PORT)
    socket.put_packet("HELLO PCVR1".to_utf8_buffer())
    connected = true
    return "Connecting to %s:%d" % [ip, PORT]

func _process(_delta):
    if not connected:
        return
    while socket.get_available_packet_count() > 0:
        var p := socket.get_packet()
        if p.size() < 13:
            continue
        if p.slice(0, 5) != MAGIC:
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
            for i in range(expected):
                if not chunks.has(i):
                    return
                bytes.append_array(chunks[i])
            var image := Image.new()
            if image.load_jpg_from_buffer(bytes) == OK:
                frame_ready.emit(image)
            chunks.clear()
