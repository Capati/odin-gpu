#+build !js
package gltf

// Core
import "core:encoding/json"
import "core:strconv"
import "core:testing"

@(private = "file")
_make_reader :: proc(text: string) -> Reader {
    return reader_make(transmute([]byte)text, context.temp_allocator)
}

@(test)
test_reader_punctuation_kinds :: proc(t: ^testing.T) {
    r := _make_reader("{ } [ ] , :")
    kinds := []Tok_Kind{.Open_Brace, .Close_Brace, .Open_Bracket, .Close_Bracket, .Comma, .Colon}
    for expected in kinds {
        tok := rd_next(&r)
        testing.expect_value(t, tok.kind, expected)
        testing.expect_value(t, r.err, Error.None)
    }
    testing.expect_value(t, rd_next(&r).kind, Tok_Kind.EOF)
    testing.expect_value(t, r.err, Error.None)
}

@(test)
test_reader_literals_and_bad_prefixes :: proc(t: ^testing.T) {
    r := _make_reader("null true false")
    testing.expect_value(t, rd_next(&r).kind, Tok_Kind.Null)
    testing.expect_value(t, rd_next(&r).kind, Tok_Kind.True)
    testing.expect_value(t, rd_next(&r).kind, Tok_Kind.False)
    testing.expect_value(t, r.err, Error.None)

    // Prefixes must not lex as literals; garbage stops the scan.
    bads := []string{"nul", "tru", "fals", "!"}
    for bad in bads {
        b := _make_reader(bad)
        testing.expect_value(t, rd_next(&b).kind, Tok_Kind.Invalid)
        testing.expect_value(t, b.err, Error.Invalid_Json)
    }
}

@(test)
test_reader_number_classification :: proc(t: ^testing.T) {
    ints := []string{"0", "-3", "123", "46356"}
    for text in ints {
        r := _make_reader(text)
        testing.expect_value(t, rd_next(&r).kind, Tok_Kind.Integer)
        testing.expect_value(t, r.err, Error.None)
    }
    floats := []string{"1.5", "-0.5", "1e10", "1E-5", "1e+10", "0.9424954"}
    for text in floats {
        r := _make_reader(text)
        testing.expect_value(t, rd_next(&r).kind, Tok_Kind.Float)
        testing.expect_value(t, r.err, Error.None)
    }
}

@(test)
test_reader_string_kinds :: proc(t: ^testing.T) {
    r := _make_reader(`"abc"`)
    testing.expect_value(t, rd_next(&r).kind, Tok_Kind.String)

    e := _make_reader(`"a\"b"`)
    testing.expect_value(t, rd_next(&e).kind, Tok_Kind.String_Escaped)

    u := _make_reader(`"unterminated`)
    testing.expect_value(t, rd_next(&u).kind, Tok_Kind.Invalid)
    testing.expect_value(t, u.err, Error.Invalid_Json)

    empty := _make_reader("")
    testing.expect_value(t, rd_next(&empty).kind, Tok_Kind.EOF)
    testing.expect_value(t, empty.err, Error.None)
}

@(test)
test_reader_int_values :: proc(t: ^testing.T) {
    texts := []string {
        "0",
        "123",
        "-123",
        "-0",
        "4611686018427387904",
        "9223372036854775807",
        "-9223372036854775808",
    }
    expected := []int{0, 123, -123, 0, 4611686018427387904, 9223372036854775807, min(int)}
    for text, i in texts {
        r := _make_reader(text)
        testing.expect_value(t, rd_int(&r), expected[i])
        testing.expect_value(t, r.err, Error.None)
    }

    // Malformed and overflowed integers are still Integer tokens, so callers
    // raise Invalid_Schema (not Invalid_Json).
    bad_ints := []string{"-", "99999999999999999999", "9223372036854775808"}
    for text in bad_ints {
        k := _make_reader(text)
        testing.expect_value(t, rd_next(&k).kind, Tok_Kind.Integer)
        r := _make_reader(text)
        testing.expect_value(t, rd_int(&r), 0)
        testing.expect_value(t, r.err, Error.Invalid_Schema)
    }
}

@(test)
test_reader_rd_int :: proc(t: ^testing.T) {
    r := _make_reader("123 -45 0")
    testing.expect_value(t, rd_int(&r), 123)
    testing.expect_value(t, rd_int(&r), -45)
    testing.expect_value(t, rd_int(&r), 0)
    testing.expect_value(t, r.err, Error.None)

    f := _make_reader("1.5")
    testing.expect_value(t, rd_int(&f), 0)
    testing.expect_value(t, f.err, Error.Invalid_Schema)

    e := _make_reader("")
    testing.expect_value(t, rd_int(&e), 0)
    testing.expect_value(t, e.err, Error.Invalid_Json)

    o := _make_reader("99999999999999999999")
    testing.expect_value(t, rd_int(&o), 0)
    testing.expect_value(t, o.err, Error.Invalid_Schema)
}

@(test)
test_reader_rd_f32 :: proc(t: ^testing.T) {
    r := _make_reader("3 0.5 -3.0 1e3")
    testing.expect_value(t, rd_f32(&r), f32(3))
    testing.expect_value(t, rd_f32(&r), f32(0.5))
    testing.expect_value(t, rd_f32(&r), f32(-3))
    testing.expect_value(t, rd_f32(&r), f32(1000))
    testing.expect_value(t, r.err, Error.None)

    big := _make_reader("1e30")
    v := rd_f32(&big)
    testing.expect_value(t, big.err, Error.None)
    testing.expect(t, v > f32(9e29) && v < f32(1.1e30))

    bad := _make_reader("1e")
    testing.expect_value(t, rd_f32(&bad), f32(0))
    testing.expect_value(t, bad.err, Error.Invalid_Schema)

    s := _make_reader(`"x"`)
    testing.expect_value(t, rd_f32(&s), f32(0))
    testing.expect_value(t, s.err, Error.Invalid_Schema)
}

@(test)
test_reader_rd_string :: proc(t: ^testing.T) {
    r := _make_reader(`"hello" "a"`)
    testing.expect_value(t, rd_string(&r), "hello")
    testing.expect_value(t, rd_string(&r), "a")
    testing.expect_value(t, r.err, Error.None)

    e := _make_reader(`"a\nb" "a\"c"`)
    testing.expect_value(t, rd_string(&e), "a\nb")
    testing.expect_value(t, rd_string(&e), "a\"c")
    testing.expect_value(t, e.err, Error.None)

    u := _make_reader(`"a\u0041"`)
    testing.expect_value(t, rd_string(&u), "aA")

    n := _make_reader("123")
    testing.expect_value(t, rd_string(&n), "")
    testing.expect_value(t, n.err, Error.Invalid_Schema)
}

@(test)
test_reader_next_key_skips_null :: proc(t: ^testing.T) {
    r := _make_reader(`{"a":1,"b":null,"c":2}`)
    testing.expect(t, rd_expect(&r, .Open_Brace))
    key, ok := rd_next_key(&r)
    testing.expect_value(t, string(key), "a")
    testing.expect(t, ok)
    testing.expect_value(t, rd_int(&r), 1)
    // "b":null is skipped, so the next key is "c".
    key, ok = rd_next_key(&r)
    testing.expect_value(t, string(key), "c")
    testing.expect(t, ok)
    testing.expect_value(t, rd_int(&r), 2)
    _, ok = rd_next_key(&r)
    testing.expect(t, !ok)
    testing.expect_value(t, r.err, Error.None)

    m := _make_reader(`{"a" 1}`)
    testing.expect(t, rd_expect(&m, .Open_Brace))
    _, ok = rd_next_key(&m)
    testing.expect(t, !ok)
    testing.expect_value(t, m.err, Error.Invalid_Schema)
}

@(test)
test_reader_has_next :: proc(t: ^testing.T) {
    r := _make_reader(`[1,2]`)
    testing.expect(t, rd_expect(&r, .Open_Bracket))
    testing.expect(t, rd_has_next(&r))
    testing.expect_value(t, rd_int(&r), 1)
    testing.expect(t, rd_has_next(&r))
    testing.expect_value(t, rd_int(&r), 2)
    testing.expect(t, !rd_has_next(&r))
    testing.expect_value(t, r.err, Error.None)

    e := _make_reader(`[]`)
    testing.expect(t, rd_expect(&e, .Open_Bracket))
    testing.expect(t, !rd_has_next(&e))

    trailing := _make_reader(`[1,]`)
    testing.expect(t, rd_expect(&trailing, .Open_Bracket))
    testing.expect(t, rd_has_next(&trailing))
    testing.expect_value(t, rd_int(&trailing), 1)
    testing.expect(t, !rd_has_next(&trailing))
    testing.expect_value(t, trailing.err, Error.Invalid_Json)
}

@(test)
test_reader_skip_and_value :: proc(t: ^testing.T) {
    r := _make_reader(`[1,2] tail`)
    end := rd_skip_value(&r)
    testing.expect_value(t, r.err, Error.None)
    testing.expect_value(t, end, 5) // just past ']'
    testing.expect_value(t, rd_string(&r), "")
    testing.expect(t, r.err != .None) // "tail" is garbage

    v := _make_reader(`{"a":1} `)
    testing.expect(t, rd_expect(&v, .Open_Brace))
    // Consume the "a" pair's value as a generic Value subtree.
    key, ok := rd_next_key(&v)
    testing.expect(t, ok)
    testing.expect_value(t, string(key), "a")
    got := rd_int(&v)
    testing.expect_value(t, got, 1)

    w := _make_reader(`[1,{"b":2}]`)
    testing.expect(t, rd_expect(&w, .Open_Bracket))
    testing.expect(t, rd_has_next(&w))
    testing.expect_value(t, rd_int(&w), 1)
    testing.expect(t, rd_has_next(&w))
    end = rd_skip_value(&w)
    testing.expect_value(t, w.err, Error.None)
    testing.expect(t, end > 0)
}

@(test)
test_reader_rd_value_object :: proc(t: ^testing.T) {
    r := _make_reader(`{"a":1,"b":[true,null]}`)
    val := rd_value(&r)
    testing.expect_value(t, r.err, Error.None)
    obj, is_obj := val.(json.Object)
    testing.expect(t, is_obj)
    a, found := member(obj, "a")
    testing.expect(t, found)
    testing.expect_value(t, a.(json.Integer), json.Integer(1))
}

@(test)
test_reader_rd_floats_exact :: proc(t: ^testing.T) {
    r := _make_reader(`[1,2.5,-3]`)
    got := rd_floats(&r, 3)
    testing.expect_value(t, got, [3]f32{1, 2.5, -3})
    testing.expect_value(t, r.err, Error.None)

    short := _make_reader(`[1,2]`)
    _ = rd_floats(&short, 3)
    testing.expect_value(t, short.err, Error.Invalid_Schema)

    long := _make_reader(`[1,2,3,4]`)
    _ = rd_floats(&long, 3)
    testing.expect_value(t, long.err, Error.Invalid_Schema)
}

@(test)
test_reader_rd_attributes :: proc(t: ^testing.T) {
    r := _make_reader(`{"POSITION":0,"NORMAL":1}`)
    attrs := rd_attributes(&r)
    testing.expect_value(t, len(attrs), 2)
    testing.expect_value(t, r.err, Error.None)
}

@(test)
test_reader_strconv_float_parity :: proc(t: ^testing.T) {
    v, ok := strconv.parse_f32("1.5")
    testing.expect(t, ok)
    testing.expect_value(t, v, f32(1.5))

    v, ok = strconv.parse_f32("1e30")
    testing.expect(t, ok)
    testing.expect(t, v > f32(9e29) && v < f32(1.1e30))

    _, ok = strconv.parse_f32("not-a-number")
    testing.expect(t, !ok)
}
