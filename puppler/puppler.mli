type document
type page

val document_new_from_file : string -> string -> document
val document_get_n_pages : document -> int
val document_get_page : document -> int -> page
val page_get_size : page -> float * float
val page_render : page -> Cairo.context -> unit
