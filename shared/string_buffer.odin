package shared

// Core
import "core:mem"
import "core:strings"

_ :: strings

STRLEN :: max(uint)

GPU_STRING_BUFFER_SIZE :: #config(GPU_STRING_BUFFER_SIZE, 256)

// Fixed-size buffer for building strings.
String_Buffer :: struct($N: int) {
    data:   [N]u8,
    length: uint,
}

String_Buffer_Base :: String_Buffer(GPU_STRING_BUFFER_SIZE)
String_Buffer_Small :: String_Buffer(128)

string_buffer_init :: proc "contextless" (
    buffer: ^$T/String_Buffer,
    str: string,
) -> string {
    string_buffer_clear(buffer)
    string_buffer_append(buffer, str)
    return string_buffer_get_string(buffer)
}

string_buffer_append :: proc "contextless" (self: ^$T/String_Buffer, str: string) {
    max_size := uint(len(self.data))

    // Check if we have enough space (leaving room for null terminator)
    if self.length + len(str) >= max_size - 1 {
        // Truncate if necessary
        remaining := max_size - self.length - 1
        copy(self.data[self.length:], (transmute([]u8)str)[:remaining])
        self.length += remaining
    } else {
        // Copy entire string
        copy(self.data[self.length:], (transmute([]u8)str)[:])
        self.length += uint(len(str))
    }
    self.data[self.length] = 0 // Ensure null termination
}

string_buffer_append_int :: proc "contextless" (
    self: ^$T/String_Buffer,
    buffer: []u8,
    #any_int value: int,
) {
    if value == 0 {
        buffer[0] = '0'
        string_buffer_append(self, string(buffer[:1]))
        return
    }

    // Convert backwards
    i := len(buffer) - 1
    temp_value := value

    for temp_value > 0 && i >= 0 {
        buffer[i] = u8('0' + (temp_value % 10))
        temp_value /= 10
        i -= 1
    }

    string_buffer_append(self, string(buffer[i + 1:]))
}

string_buffer_append_f64 :: proc "contextless" (
    self: ^$T/String_Buffer,
    buffer: []u8,
    value: f64,
    #any_int decimals: int = 1,
) {
    value := value
    if value < 0 {
        string_buffer_append(self, "-")
        value = -value
    }

    int_part := u64(value)
    frac_part := value - f64(int_part)

    pow10: u64 = 1
    frac_int: u64 = 0
    for _ in 0..<decimals {
        pow10 *= 10
    }
    frac_int = u64((frac_part * f64(pow10) + 0.5))
    if frac_int >= pow10 {
        frac_int -= pow10
        int_part += 1
    }

    // Append integer part
    if int_part == 0 {
        string_buffer_append(self, "0")
    } else {
        i := len(buffer) - 1
        temp := int_part
        for temp > 0 && i >= 0 {
            buffer[i] = u8('0' + (temp % 10))
            temp /= 10
            i -= 1
        }
        string_buffer_append(self, string(buffer[i + 1:]))
    }

    if decimals > 0 {
        string_buffer_append(self, ".")
        // Append fractional part
        i := decimals - 1
        temp := frac_int
        for temp > 0 && i >= 0 {
            buffer[i] = u8('0' + (temp % 10))
            temp /= 10
            i -= 1
        }
        for j := 0; j <= i; j += 1 {
            buffer[j] = '0'
        }
        string_buffer_append(self, string(buffer[:decimals]))
    }
}

string_buffer_clear :: proc "contextless" (self: ^$T/String_Buffer) {
    mem.zero_slice(self.data[:])
    self.length = 0
}

string_buffer_capacity :: proc "contextless" (self: ^$T/String_Buffer) -> uint {
    max_size := uint(len(self.data))
    return max_size - self.length - 1 // -1 for null terminator
}

string_buffer_is_full :: proc "contextless" (self: ^$T/String_Buffer) -> bool {
    max_size := uint(len(self.data))
    return self.length >= max_size - 1
}

string_buffer_is_empty :: proc "contextless" (self: ^$T/String_Buffer) -> bool {
    return self.length == 0
}

string_buffer_get_string :: proc "contextless" (self: ^$T/String_Buffer) -> string {
    return self.length > 0 ? string(self.data[:self.length]) : ""
}

string_buffer_get_cstring :: proc "contextless" (self: ^$T/String_Buffer) -> cstring {
    return cstring(raw_data(self.data[:]))
}

string_buffer_clone_string :: proc(
    self: ^$T/String_Buffer,
    allocator := context.allocator,
) -> (
    res: string,
    err: mem.Allocator_Error,
) #optional_allocator_error {
    return strings.clone(string_buffer_get_string(self), allocator)
}
