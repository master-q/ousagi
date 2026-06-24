#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <poppler/glib/poppler.h>
#include <cairo.h>

/* --- PopplerDocument finalization --- */
static void poppler_doc_finalize(value v) {
    PopplerDocument *doc = *((PopplerDocument **)Data_custom_val(v));
    if (doc) g_object_unref(doc);
}

static struct custom_operations poppler_doc_ops = {
    "poppler_document",
    poppler_doc_finalize,
    custom_compare_default,
    custom_hash_default,
    custom_serialize_default,
    custom_deserialize_default,
    custom_compare_ext_default,
    custom_fixed_length_default
};

/* --- PopplerPage finalization --- */
static void poppler_page_finalize(value v) {
    PopplerPage *page = *((PopplerPage **)Data_custom_val(v));
    if (page) g_object_unref(page);
}

static struct custom_operations poppler_page_ops = {
    "poppler_page",
    poppler_page_finalize,
    custom_compare_default,
    custom_hash_default,
    custom_serialize_default,
    custom_deserialize_default,
    custom_compare_ext_default,
    custom_fixed_length_default
};

/* poppler_document_new_from_file : string -> string -> document */
CAMLprim value caml_poppler_document_new_from_file(value uri, value password) {
    CAMLparam2(uri, password);
    CAMLlocal1(result);
    GError *err = NULL;
    const char *pw = (String_val(password)[0] == '\0') ? NULL : String_val(password);
    PopplerDocument *doc = poppler_document_new_from_file(String_val(uri), pw, &err);
    if (!doc) {
        caml_failwith(err ? err->message : "poppler: failed to open document");
    }
    result = caml_alloc_custom(&poppler_doc_ops, sizeof(PopplerDocument *), 0, 1);
    *((PopplerDocument **)Data_custom_val(result)) = doc;
    CAMLreturn(result);
}

/* poppler_document_get_n_pages : document -> int */
CAMLprim value caml_poppler_document_get_n_pages(value doc) {
    CAMLparam1(doc);
    PopplerDocument *d = *((PopplerDocument **)Data_custom_val(doc));
    CAMLreturn(Val_int(poppler_document_get_n_pages(d)));
}

/* poppler_document_get_page : document -> int -> page */
CAMLprim value caml_poppler_document_get_page(value doc, value index) {
    CAMLparam2(doc, index);
    CAMLlocal1(result);
    PopplerDocument *d = *((PopplerDocument **)Data_custom_val(doc));
    PopplerPage *page = poppler_document_get_page(d, Int_val(index));
    if (!page) caml_failwith("poppler: page not found");
    result = caml_alloc_custom(&poppler_page_ops, sizeof(PopplerPage *), 0, 1);
    *((PopplerPage **)Data_custom_val(result)) = page;
    CAMLreturn(result);
}

/* poppler_page_get_size : page -> float * float */
CAMLprim value caml_poppler_page_get_size(value page) {
    CAMLparam1(page);
    CAMLlocal1(pair);
    PopplerPage *p = *((PopplerPage **)Data_custom_val(page));
    double w, h;
    poppler_page_get_size(p, &w, &h);
    pair = caml_alloc_tuple(2);
    Store_field(pair, 0, caml_copy_double(w));
    Store_field(pair, 1, caml_copy_double(h));
    CAMLreturn(pair);
}

/* poppler_page_render : page -> Cairo.context -> unit */
CAMLprim value caml_poppler_page_render(value page, value cr_val) {
    CAMLparam2(page, cr_val);
    PopplerPage *p = *((PopplerPage **)Data_custom_val(page));
    /* cairo2 stores cairo_t* as a custom block; pointer is at Data_custom_val */
    cairo_t *cr = *((cairo_t **)Data_custom_val(cr_val));
    poppler_page_render(p, cr);
    CAMLreturn(Val_unit);
}
