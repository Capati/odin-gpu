#+build js
package gltf

parse_file :: proc(path: string, options := Options{}) -> (document: ^Document, err: Error) {
    _ = path
    _ = options
    return nil, .Unknown_Format
}
