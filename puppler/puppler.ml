type document
type page

external document_new_from_file : string -> string -> document
  = "caml_poppler_document_new_from_file"

external document_get_n_pages : document -> int
  = "caml_poppler_document_get_n_pages"

external document_get_page : document -> int -> page
  = "caml_poppler_document_get_page"

external page_get_size : page -> float * float
  = "caml_poppler_page_get_size"

external page_render : page -> Cairo.context -> unit
  = "caml_poppler_page_render"
