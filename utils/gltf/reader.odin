package gltf

// Core
import "core:bytes"
import "core:encoding/json"
import "core:mem"
import "core:strconv"

Tok_Kind :: enum u8 {
    Invalid,
    EOF,
    Open_Brace,
    Close_Brace,
    Open_Bracket,
    Close_Bracket,
    Comma,
    Colon,
    Null,
    True,
    False,
    Integer,
    Float,
    String,
    // String containing backslash escapes. Scan detected the escapes so
    // rd_string can go straight to unquoting without re-scanning.
    String_Escaped,
}

Token :: struct {
    kind:   Tok_Kind,
    text:   string,
    offset: int,
}

Reader :: struct {
    src:      []byte,
    pos:      int,
    alloc:    mem.Allocator,
    err:      Error,
    first:    bool, // true right after '{' or '[': no comma expected yet
    has_peek: bool,
    peeked:   Token,
}

reader_make :: #force_inline proc "contextless" (src: []byte, alloc: mem.Allocator) -> Reader {
    return {src = src, alloc = alloc}
}

@(private = "file")
scan :: proc "contextless" (r: ^Reader) -> Token {
    s := r.src
    i := r.pos
    for i < len(s) && (s[i] == ' ' || s[i] == '\n' || s[i] == '\r' || s[i] == '\t') {i += 1}
    if i >= len(s) {
        r.pos = i
        return {kind = .EOF, offset = i}
    }

    start := i
    kind := Tok_Kind.Invalid
    switch s[i] {
    case '{':
        kind = .Open_Brace; i += 1
    case '}':
        kind = .Close_Brace; i += 1
    case '[':
        kind = .Open_Bracket; i += 1
    case ']':
        kind = .Close_Bracket; i += 1
    case ',':
        kind = .Comma; i += 1
    case ':':
        kind = .Colon; i += 1
    case 'n':
        if len(s) - i >= 4 && s[i + 1] == 'u' && s[i + 2] == 'l' && s[i + 3] == 'l' {
            kind = .Null; i += 4
        }
    case 't':
        if len(s) - i >= 4 && s[i + 1] == 'r' && s[i + 2] == 'u' && s[i + 3] == 'e' {
            kind = .True; i += 4
        }
    case 'f':
        if len(s) - i >= 5 &&
           s[i + 1] == 'a' &&
           s[i + 2] == 'l' &&
           s[i + 3] == 's' &&
           s[i + 4] == 'e' {
            kind = .False; i += 5
        }
    case '"':
        i += 1
        q := bytes.index_byte(s[i:], '"')
        if q >= 0 && bytes.index_byte(s[i:i + q], '\\') < 0 {
            // Fast path: no escapes. Two byte searches, no per-rune decoding.
            i += q + 1
            kind = .String
        } else {
            // Slow path: walk byte by byte, skipping escaped characters.
            saw_backslash := false
            for i < len(s) && s[i] != '"' {
                if s[i] == '\\' {
                    saw_backslash = true
                    i += 1
                }
                i += 1
            }
            if i < len(s) {
                i += 1
                kind = .String_Escaped if saw_backslash else .String
            }
        }
    case '-', '0' ..= '9':
        // Conversion is left to rd_int/rd_f32
        kind = .Integer
        i += 1
        num: for i < len(s) {
            switch s[i] {
            case '0' ..= '9':
            case '.', 'e', 'E', '+', '-':
                kind = .Float
            case:
                break num
            }
            i += 1
        }
    }
    if kind == .Invalid {
        i = len(s) // stop scanning after garbage
    }
    r.pos = i
    return {kind = kind, text = transmute(string)s[start:i], offset = start}
}

@(cold)
rd_fail :: proc "contextless" (r: ^Reader, e: Error = .Invalid_Schema) {
    if r.err == .None {r.err = e}
}

@(cold)
rd_bad :: proc "contextless" (r: ^Reader, tok: Token) {
    #partial switch tok.kind {
    case .Invalid, .EOF:
        rd_fail(r, .Invalid_Json)
    case:
        rd_fail(r)
    }
}

rd_next :: #force_inline proc "contextless" (r: ^Reader) -> Token {
    if r.err != .None {return {}}
    tok: Token
    if r.has_peek {
        tok = r.peeked
        r.has_peek = false
    } else {
        tok = scan(r)
    }
    if tok.kind == .Invalid {rd_fail(r, .Invalid_Json)}
    r.first = tok.kind == .Open_Brace || tok.kind == .Open_Bracket
    return tok
}

rd_peek :: #force_inline proc "contextless" (r: ^Reader) -> Token {
    if r.err != .None {return {}}
    if !r.has_peek {
        r.peeked = scan(r)
        r.has_peek = true
    }
    return r.peeked
}

rd_expect :: #force_inline proc "contextless" (r: ^Reader, kind: Tok_Kind) -> bool {
    tok := rd_next(r)
    if r.err == .None && tok.kind != kind {rd_bad(r, tok)}
    return r.err == .None
}

// for key in rd_next_key(r) { ... }   (call after consuming '{')
// Members whose value is `null` are skipped, which matches "absent".
rd_next_key :: proc(r: ^Reader) -> (key: string, ok: bool) {
    for {
        tok := rd_peek(r)
        if r.err != .None {return}
        if tok.kind == .Close_Brace {rd_next(r); return}
        if !r.first {
            if tok.kind != .Comma {rd_bad(r, tok); return}
            rd_next(r)
        }
        k := rd_next(r)
        if k.kind == .String {
            // Fast path: keys never contain escapes in practice.
        } else if k.kind == .String_Escaped {
            // Slow path: unquote an escaped key (vanishingly rare).
            s, e := json.unquote_string(json.Token{kind = .String, text = k.text}, .JSON, r.alloc)
            if e != .None {rd_fail(r, .Invalid_Json); return}
            if !rd_expect(r, .Colon) {return}
            if rd_peek(r).kind == .Null {
                rd_next(r); continue // null == absent
            }
            return s, true
        } else {
            rd_fail(r, .Invalid_Json); return
        }
        if !rd_expect(r, .Colon) {return}
        if rd_peek(r).kind == .Null {
            rd_next(r); continue // null == absent
        }
        return k.text[1:len(k.text) - 1], true
    }
}

// for rd_has_next(r) { ... }   (call after consuming '[')
rd_has_next :: #force_inline proc "contextless" (r: ^Reader) -> bool {
    tok := rd_peek(r)
    if r.err != .None {return false}
    if tok.kind == .Close_Bracket {rd_next(r); return false}
    if !r.first {
        if tok.kind != .Comma {rd_bad(r, tok); return false}
        rd_next(r)
        // trailing comma
        if rd_peek(r).kind == .Close_Bracket {rd_fail(r, .Invalid_Json); return false}
    }
    if rd_peek(r).kind == .EOF {rd_fail(r, .Invalid_Json); return false}
    return true
}

// Skips one value, returns the byte offset just past it.
rd_skip_value :: proc(r: ^Reader) -> (end: int) {
    depth := 0
    for r.err == .None {
        tok := rd_next(r)
        end = tok.offset + len(tok.text)
        #partial switch tok.kind {
        case .Open_Brace, .Open_Bracket:
            depth += 1
        case .Close_Brace, .Close_Bracket:
            depth -= 1
        case .EOF, .Invalid:
            rd_fail(r, .Invalid_Json); return
        }
        if depth <= 0 {return}
    }
    return
}

// For extras / extensions / min / max: parse just that subtree into a json.Value.
rd_value :: proc(r: ^Reader) -> (v: json.Value) {
    start := rd_peek(r).offset
    end := rd_skip_value(r)
    if r.err != .None {return}
    err: json.Error
    v, err = json.parse(r.src[start:end], .JSON, true, r.alloc)
    if err != .None {rd_fail(r, .Invalid_Json)}
    return
}

rd_int :: #force_inline proc(r: ^Reader) -> int {
    tok := rd_next(r)
    if tok.kind != .Integer {rd_bad(r, tok); return 0}
    if v, ok := strconv.parse_int(tok.text, 10); ok {
        return v
    }
    rd_bad(r, tok)
    return 0
}

rd_f32 :: #force_inline proc(r: ^Reader) -> f32 {
    tok := rd_next(r)
    if tok.kind != .Integer && tok.kind != .Float {rd_bad(r, tok); return 0}
    if v, ok := strconv.parse_f32(tok.text); ok {
        return v
    }
    rd_bad(r, tok)
    return 0
}

rd_bool :: #force_inline proc "contextless" (r: ^Reader) -> bool {
    tok := rd_next(r)
    #partial switch tok.kind {
    case .True:
        return true
    case .False:
        return false
    }
    rd_bad(r, tok)
    return false
}

// Zero-copy slice of the JSON chunk unless the string contains escapes.
rd_string :: #force_inline proc(r: ^Reader) -> string {
    tok := rd_next(r)
    #partial switch tok.kind {
    case .String:
        return tok.text[1:len(tok.text) - 1]
    case .String_Escaped:
        s, e := json.unquote_string(json.Token{kind = .String, text = tok.text}, .JSON, r.alloc)
        if e != .None {rd_fail(r, .Invalid_Json)}
        return s
    }
    rd_bad(r, tok)
    return ""
}

rd_floats :: #force_inline proc(r: ^Reader, $N: int) -> (out: [N]f32) {
    if !rd_expect(r, .Open_Bracket) {return}
    i := 0
    for rd_has_next(r) {
        v := rd_f32(r)
        if i < N {out[i] = v}
        i += 1
    }
    if i != N {rd_fail(r)}
    return
}

rd_array :: proc(r: ^Reader, $T: typeid, read: proc(r: ^Reader) -> T) -> []T {
    if !rd_expect(r, .Open_Bracket) {return nil}
    // Small initial cap: min/max/weights hold 1-4 elems. large top-level arrays
    // pay just two extra doublings (12 elements recopied, negligible).
    out := make([dynamic]T, 0, 4, r.alloc)
    for rd_has_next(r) {append(&out, read(r))}
    return out[:]
}

read_asset :: proc(r: ^Reader) -> (o: Raw_Asset) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "name":
            o.name = rd_string(r)
        case "copyright":
            o.copyright = rd_string(r)
        case "generator":
            o.generator = rd_string(r)
        case "version":
            o.version = rd_string(r)
        case "minVersion":
            o.min_version = rd_string(r)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_buffer_view :: proc(r: ^Reader) -> (o: Raw_Buffer_View) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        // Cases in file order (buffer, byteLength, byteOffset, ...), mirroring
        // a sequential key chain: the first key in the file matches
        // the first case, minimizing average compares.
        switch key {
        case "buffer":
            o.buffer = rd_int(r)
        case "byteLength":
            o.byte_length = rd_int(r)
        case "byteOffset":
            o.byte_offset = rd_int(r)
        case "byteStride":
            o.byte_stride = rd_int(r)
        case "target":
            o.target = rd_int(r)
        case "name":
            o.name = rd_string(r)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_buffer :: proc(r: ^Reader) -> (o: Raw_Buffer) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "name":
            o.name = rd_string(r)
        case "byteLength":
            o.byte_length = rd_int(r)
        case "uri":
            o.uri = rd_string(r)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_sparse_indices :: proc(r: ^Reader) -> (o: Raw_Sparse_Indices) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "bufferView":
            o.buffer_view = rd_int(r)
        case "byteOffset":
            o.byte_offset = rd_int(r)
        case "componentType":
            o.component_type = rd_int(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_sparse_values :: proc(r: ^Reader) -> (o: Raw_Sparse_Values) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "bufferView":
            o.buffer_view = rd_int(r)
        case "byteOffset":
            o.byte_offset = rd_int(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_sparse :: proc(r: ^Reader) -> (o: Raw_Sparse) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "count":
            o.count = rd_int(r)
        case "indices":
            o.indices = read_sparse_indices(r)
        case "values":
            o.values = read_sparse_values(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_accessor :: proc(r: ^Reader) -> (o: Raw_Accessor) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        // Cases in file order (bufferView, componentType, type, count,
        // byteOffset, min, max, ...), so each key matches with minimal prior
        // compares given exporters emit stable key order.
        switch key {
        case "bufferView":
            o.buffer_view = rd_int(r)
        case "componentType":
            o.component_type = rd_int(r)
        case "type":
            o.type = rd_string(r)
        case "count":
            o.count = rd_int(r)
        case "byteOffset":
            o.byte_offset = rd_int(r)
        case "min":
            o.min = rd_array(r, f32, rd_f32)
        case "max":
            o.max = rd_array(r, f32, rd_f32)
        case "name":
            o.name = rd_string(r)
        case "normalized":
            o.normalized = rd_bool(r)
        case "sparse":
            o.sparse = read_sparse(r)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_image :: proc(r: ^Reader) -> (o: Raw_Image) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "name":
            o.name = rd_string(r)
        case "uri":
            o.uri = rd_string(r) // data: URIs stay zero-copy
        case "mimeType":
            o.mime_type = rd_string(r)
        case "bufferView":
            o.buffer_view = rd_int(r)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_sampler :: proc(r: ^Reader) -> (o: Raw_Sampler) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "name":
            o.name = rd_string(r)
        case "magFilter":
            o.mag_filter = rd_int(r)
        case "minFilter":
            o.min_filter = rd_int(r)
        case "wrapS":
            o.wrap_s = rd_int(r)
        case "wrapT":
            o.wrap_t = rd_int(r)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_texture :: proc(r: ^Reader) -> (o: Raw_Texture) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "name":
            o.name = rd_string(r)
        case "sampler":
            o.sampler = rd_int(r)
        case "source":
            o.source = rd_int(r)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_texture_info :: proc(r: ^Reader) -> (o: Raw_Texture_Info) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "index":
            o.index = rd_int(r)
        case "texCoord":
            o.tex_coord = rd_int(r)
        case "scale":
            o.scale = rd_f32(r)
        case "strength":
            o.strength = rd_f32(r)
        case "extensions":
            o.extensions = rd_value(r)
        case "extras":
            o.extras = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_pbr :: proc(r: ^Reader) -> (o: Raw_Pbr) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "baseColorFactor":
            o.base_color_factor = rd_floats(r, 4)
        case "baseColorTexture":
            o.base_color_texture = read_texture_info(r)
        case "metallicFactor":
            o.metallic_factor = rd_f32(r)
        case "roughnessFactor":
            o.roughness_factor = rd_f32(r)
        case "metallicRoughnessTexture":
            o.metallic_roughness_texture = read_texture_info(r)
        case "extras":
            o.extras = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_material :: proc(r: ^Reader) -> (o: Raw_Material) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "name":
            o.name = rd_string(r)
        case "pbrMetallicRoughness":
            o.pbr = read_pbr(r)
        case "normalTexture":
            o.normal_texture = read_texture_info(r)
        case "occlusionTexture":
            o.occlusion_texture = read_texture_info(r)
        case "emissiveTexture":
            o.emissive_texture = read_texture_info(r)
        case "emissiveFactor":
            o.emissive_factor = rd_floats(r, 3)
        case "alphaMode":
            o.alpha_mode = rd_string(r)
        case "alphaCutoff":
            o.alpha_cutoff = rd_f32(r)
        case "doubleSided":
            o.double_sided = rd_bool(r)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

rd_attributes :: proc(r: ^Reader) -> []Raw_Attribute {
    if !rd_expect(r, .Open_Brace) {return nil}
    // Primitives carry 3-4 attributes; cap 4 fits without growth or waste
    // (cap 0 would grow to 8 and waste half on every primitive).
    out := make([dynamic]Raw_Attribute, 0, 4, r.alloc)
    for key in rd_next_key(r) {
        append(&out, Raw_Attribute{key, rd_int(r)})
    }
    return out[:]
}

read_primitive :: proc(r: ^Reader) -> (o: Raw_Primitive) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "attributes":
            o.attributes = rd_attributes(r)
        case "indices":
            o.indices = rd_int(r)
        case "material":
            o.material = rd_int(r)
        case "mode":
            o.mode = rd_int(r)
        case "targets":
            o.targets = rd_array(r, []Raw_Attribute, rd_attributes)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_mesh :: proc(r: ^Reader) -> (o: Raw_Mesh) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "name":
            o.name = rd_string(r)
        case "primitives":
            o.primitives = rd_array(r, Raw_Primitive, read_primitive)
        case "weights":
            o.weights = rd_array(r, f32, rd_f32)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_skin :: proc(r: ^Reader) -> (o: Raw_Skin) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "name":
            o.name = rd_string(r)
        case "inverseBindMatrices":
            o.inverse_bind_matrices = rd_int(r)
        case "skeleton":
            o.skeleton = rd_int(r)
        case "joints":
            o.joints = rd_array(r, int, rd_int)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_camera_perspective :: proc(r: ^Reader) -> (o: Raw_Camera_Perspective) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "aspectRatio":
            o.aspect_ratio = rd_f32(r)
        case "yfov":
            o.yfov = rd_f32(r)
        case "zfar":
            o.zfar = rd_f32(r)
        case "znear":
            o.znear = rd_f32(r)
        case "extras":
            o.extras = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_camera_orthographic :: proc(r: ^Reader) -> (o: Raw_Camera_Orthographic) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "xmag":
            o.xmag = rd_f32(r)
        case "ymag":
            o.ymag = rd_f32(r)
        case "zfar":
            o.zfar = rd_f32(r)
        case "znear":
            o.znear = rd_f32(r)
        case "extras":
            o.extras = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_camera :: proc(r: ^Reader) -> (o: Raw_Camera) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "name":
            o.name = rd_string(r)
        case "type":
            o.type = rd_string(r)
        case "perspective":
            o.perspective = read_camera_perspective(r)
        case "orthographic":
            o.orthographic = read_camera_orthographic(r)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_node :: proc(r: ^Reader) -> (o: Raw_Node) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "name":
            o.name = rd_string(r)
        case "children":
            o.children = rd_array(r, int, rd_int)
        case "mesh":
            o.mesh = rd_int(r)
        case "camera":
            o.camera = rd_int(r)
        case "skin":
            o.skin = rd_int(r)
        case "matrix":
            o.matrix_ = rd_floats(r, 16)
        case "translation":
            o.translation = rd_floats(r, 3)
        case "rotation":
            o.rotation = rd_floats(r, 4)
        case "scale":
            o.scale = rd_floats(r, 3)
        case "weights":
            o.weights = rd_array(r, f32, rd_f32)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_scene :: proc(r: ^Reader) -> (o: Raw_Scene) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "name":
            o.name = rd_string(r)
        case "nodes":
            o.nodes = rd_array(r, int, rd_int)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_animation_sampler :: proc(r: ^Reader) -> (o: Raw_Animation_Sampler) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "input":
            o.input = rd_int(r)
        case "output":
            o.output = rd_int(r)
        case "interpolation":
            o.interpolation = rd_string(r)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_animation_channel :: proc(r: ^Reader) -> (o: Raw_Animation_Channel) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "sampler":
            o.sampler = rd_int(r)
        case "target":
            // anonymous struct in the schema, so it's read inline here
            if rd_expect(r, .Open_Brace) {
                for k in rd_next_key(r) {
                    switch k {
                    case "node":
                        o.target.node = rd_int(r)
                    case "path":
                        o.target.path = rd_string(r)
                    case "extensions":
                        o.target.extensions = rd_value(r)
                    case:
                        rd_skip_value(r)
                    }
                }
            }
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_animation :: proc(r: ^Reader) -> (o: Raw_Animation) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "name":
            o.name = rd_string(r)
        case "channels":
            o.channels = rd_array(r, Raw_Animation_Channel, read_animation_channel)
        case "samplers":
            o.samplers = rd_array(r, Raw_Animation_Sampler, read_animation_sampler)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}

read_root :: proc(r: ^Reader) -> (o: Raw_Root) {
    if !rd_expect(r, .Open_Brace) {return}
    for key in rd_next_key(r) {
        switch key {
        case "asset":
            o.asset = read_asset(r)
        case "scene":
            o.scene = rd_int(r)
        case "scenes":
            o.scenes = rd_array(r, Raw_Scene, read_scene)
        case "nodes":
            o.nodes = rd_array(r, Raw_Node, read_node)
        case "meshes":
            o.meshes = rd_array(r, Raw_Mesh, read_mesh)
        case "accessors":
            o.accessors = rd_array(r, Raw_Accessor, read_accessor)
        case "bufferViews":
            o.buffer_views = rd_array(r, Raw_Buffer_View, read_buffer_view)
        case "buffers":
            o.buffers = rd_array(r, Raw_Buffer, read_buffer)
        case "materials":
            o.materials = rd_array(r, Raw_Material, read_material)
        case "textures":
            o.textures = rd_array(r, Raw_Texture, read_texture)
        case "images":
            o.images = rd_array(r, Raw_Image, read_image)
        case "samplers":
            o.samplers = rd_array(r, Raw_Sampler, read_sampler)
        case "cameras":
            o.cameras = rd_array(r, Raw_Camera, read_camera)
        case "animations":
            o.animations = rd_array(r, Raw_Animation, read_animation)
        case "skins":
            o.skins = rd_array(r, Raw_Skin, read_skin)
        case "extensionsUsed":
            o.extensions_used = rd_array(r, string, rd_string)
        case "extensionsRequired":
            o.extensions_required = rd_array(r, string, rd_string)
        case "extras":
            o.extras = rd_value(r)
        case "extensions":
            o.extensions = rd_value(r)
        case:
            rd_skip_value(r)
        }
    }
    return
}
