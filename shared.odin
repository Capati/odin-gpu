package gpu

// Local libs
import "shared"

Range                      :: shared.Range
Range_Iterator             :: shared.Range_Iterator
range_init                 :: shared.range_init
range_len                  :: shared.range_len
range_is_empty             :: shared.range_is_empty
range_contains             :: shared.range_contains
range_create_iterator      :: shared.range_create_iterator
range_iterator_next        :: shared.range_iterator_next

align                      :: shared.align
align_size                 :: shared.align_size
is_aligned                 :: shared.is_aligned

Handle                     :: shared.Handle
Internal_Handle            :: shared.Internal_Handle
Pool_Entry                 :: shared.Pool_Entry
Pool                       :: shared.Pool
from_handle                :: shared.from_handle
to_handle                  :: shared.to_handle
handle_from_ptr            :: shared.handle_from_ptr
handle_is_empty            :: shared.handle_is_empty
handle_is_valid            :: shared.handle_is_valid
handle_index               :: shared.handle_index
handle_gen                 :: shared.handle_gen
pool_set_defaults          :: shared.pool_set_defaults
pool_init                  :: shared.pool_init
pool_create                :: shared.pool_create
pool_get                   :: shared.pool_get
pool_get_from_index        :: shared.pool_get_from_index
pool_get_handle            :: shared.pool_get_handle
pool_find_handle           :: shared.pool_find_handle
pool_remove                :: shared.pool_remove
pool_len                   :: shared.pool_len
pool_is_empty              :: shared.pool_is_empty
pool_clear                 :: shared.pool_clear
pool_destroy               :: shared.pool_destroy

String_Buffer_Small        :: shared.String_Buffer_Small
string_buffer_init         :: shared.string_buffer_init
string_buffer_append       :: shared.string_buffer_append
string_buffer_append_int   :: shared.string_buffer_append_int
string_buffer_append_f64   :: shared.string_buffer_append_f64
string_buffer_clear        :: shared.string_buffer_clear
string_buffer_capacity     :: shared.string_buffer_capacity
string_buffer_is_full      :: shared.string_buffer_is_full
string_buffer_is_empty     :: shared.string_buffer_is_empty
string_buffer_get_string   :: shared.string_buffer_get_string
string_buffer_get_cstring  :: shared.string_buffer_get_cstring
string_buffer_clone_string :: shared.string_buffer_clone_string

to_bytes                   :: shared.to_bytes
to_bytes_contextless       :: shared.to_bytes_contextless
