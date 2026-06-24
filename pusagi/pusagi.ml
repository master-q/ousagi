external poppler_document_new_from_file : string -> string -> 'doc
  = "caml_poppler_document_new_from_file"

external poppler_document_get_n_pages : 'doc -> int
  = "caml_poppler_document_get_n_pages"

external poppler_document_get_page : 'doc -> int -> 'page
  = "caml_poppler_document_get_page"

external poppler_page_get_size : 'page -> float * float
  = "caml_poppler_page_get_size"

external poppler_page_render : 'page -> Cairo.context -> unit
  = "caml_poppler_page_render"

let default_total_time_sec = 300.0

type 'doc state = {
  doc : 'doc;
  total_pages : int;
  current_page : int ref;
  presentation_running : bool ref;
  elapsed_time_sec : float ref;
  last_update_time_sec : float ref;
  displayed_timer_progress : float ref;
  displayed_page_progress : float ref;
  total_time_sec : float;
}

let monotonic_sec () = Unix.gettimeofday ()

let toggle_presentation_timer state =
  if !(state.presentation_running) then begin
    let now = monotonic_sec () in
    state.elapsed_time_sec := !(state.elapsed_time_sec) +. (now -. !(state.last_update_time_sec));
    state.presentation_running := false
  end else begin
    state.last_update_time_sec := monotonic_sec ();
    state.presentation_running := true
  end

let update_presentation_timer state =
  if !(state.presentation_running) then begin
    let now = monotonic_sec () in
    state.elapsed_time_sec := !(state.elapsed_time_sec) +. (now -. !(state.last_update_time_sec));
    state.last_update_time_sec := now
  end

let draw_progress_text cr text progress width y =
  Cairo.save cr;
  let layout = Cairo_pango.create_layout cr in
  let desc = Pango.Font.from_string "Sans Bold 20" in
  Pango.Layout.set_font_description layout desc;
  Pango.Layout.set_text layout text;
  let (text_width, _) = Pango.Layout.get_pixel_size layout in
  let clamped = Float.min (Float.max progress 0.0) 1.0 in
  let x = clamped *. Float.max (float_of_int (width - text_width)) 0.0 in
  Cairo.move_to cr x y;
  Cairo_pango.show_layout cr layout;
  Cairo.restore cr

let draw cr state width height =
  let page = poppler_document_get_page state.doc !(state.current_page) in
  let (pw, ph) = poppler_page_get_size page in
  let fw = float_of_int width in
  let fh = float_of_int height in
  let scale = Float.min (fw /. pw) (fh /. ph) in
  let ox = (fw -. pw *. scale) /. 2.0 in
  let oy = (fh -. ph *. scale) /. 2.0 in
  Cairo.save cr;
  Cairo.set_source_rgb cr 0.0 0.0 0.0;
  Cairo.rectangle cr 0.0 0.0 ~w:fw ~h:fh;
  Cairo.fill cr;
  Cairo.translate cr ox oy;
  Cairo.scale cr scale scale;
  poppler_page_render page cr;
  Cairo.restore cr;
  let page_progress =
    if state.total_pages > 1
    then float_of_int !(state.current_page) /. float_of_int (state.total_pages - 1)
    else 0.0
  in
  let timer_progress = Float.min (!(state.elapsed_time_sec) /. state.total_time_sec) 1.0 in
  if !(state.presentation_running) then
    state.displayed_timer_progress :=
      !(state.displayed_timer_progress)
      +. (timer_progress -. !(state.displayed_timer_progress)) *. 0.1;
  state.displayed_page_progress :=
    !(state.displayed_page_progress)
    +. (page_progress -. !(state.displayed_page_progress)) *. 0.1;
  Cairo.set_source_rgba cr 0.0 0.0 0.0 0.3;
  Cairo.rectangle cr 0.0 (fh -. 30.0) ~w:fw ~h:30.0;
  Cairo.fill cr;
  Cairo.set_source_rgb cr 0.2 0.8 0.2;
  let turtle_text =
    if !(state.presentation_running) then "\xF0\x9F\x90\xA2"
    else "\xF0\x9F\x90\xA2\xF0\x9F\x92\xA4"
  in
  draw_progress_text cr turtle_text !(state.displayed_timer_progress) width (fh -. 30.0);
  Cairo.set_source_rgb cr 0.9 0.3 0.3;
  draw_progress_text cr "\xF0\x9F\x90\x87" !(state.displayed_page_progress) width (fh -. 30.0)

let print_help prog =
  Printf.printf "Usage: %s [OPTIONS] PDF_FILE\n\n" prog;
  Printf.printf "Options:\n";
  Printf.printf "  -t MINUTES      Set presentation duration in minutes (default: 5)\n";
  Printf.printf "  -h, --help      Show this help message and exit\n\n";
  Printf.printf "Keys:\n";
  Printf.printf "  Space           Start or pause the presentation timer\n";
  Printf.printf "  Left / Right    Move to the previous or next page\n";
  Printf.printf "  Home / End      Move to the first or last page\n";
  Printf.printf "  Esc             Quit\n"

let parse_minutes s =
  let m = float_of_string s in
  if m <= 0.0 then begin
    Printf.eprintf "Error: presentation minutes must be greater than 0\n";
    exit 1
  end;
  m *. 60.0

let () =
  let argv = Sys.argv in
  let argc = Array.length argv in
  let total_time_sec = ref default_total_time_sec in
  let pdf_file = ref None in
  let i = ref 1 in
  while !i < argc do
    let arg = argv.(!i) in
    if arg = "-h" || arg = "--help" then begin
      print_help argv.(0); exit 0
    end else if arg = "-t" then begin
      if !i + 1 >= argc then begin
        Printf.eprintf "Error: -t requires a value in minutes\n";
        print_help argv.(0); exit 1
      end;
      incr i;
      total_time_sec := parse_minutes argv.(!i)
    end else
      pdf_file := Some arg;
    incr i
  done;
  let filename = match !pdf_file with
    | None -> print_help argv.(0); exit 0
    | Some f -> f
  in
  ignore (GMain.init ());
  let uri =
    if Filename.is_relative filename then
      "file://" ^ Filename.concat (Sys.getcwd ()) filename
    else
      "file://" ^ filename
  in
  let doc =
    try poppler_document_new_from_file uri ""
    with Failure msg ->
      Printf.eprintf "Failed to load PDF: %s\n" msg; exit 1
  in
  let n_pages = poppler_document_get_n_pages doc in
  let state = {
    doc;
    total_pages = n_pages;
    current_page = ref 0;
    presentation_running = ref false;
    elapsed_time_sec = ref 0.0;
    last_update_time_sec = ref 0.0;
    displayed_timer_progress = ref 0.0;
    displayed_page_progress = ref 0.0;
    total_time_sec = !total_time_sec;
  } in
  let window = GWindow.window ~title:"Pusagi (OCaml)" ~width:1024 ~height:768 () in
  window#connect#destroy ~callback:GMain.quit |> ignore;
  let area = GMisc.drawing_area ~packing:window#add () in
  area#misc#set_can_focus true;
  area#misc#connect#draw ~callback:(fun cr ->
    let alloc = area#misc#allocation in
    draw cr state alloc.Gtk.width alloc.Gtk.height;
    false
  ) |> ignore;
  window#event#connect#key_press ~callback:(fun ev ->
    let key = GdkEvent.Key.keyval ev in
    if key = GdkKeysyms._Escape then begin
      window#destroy (); true
    end else if key = GdkKeysyms._space || key = GdkKeysyms._KP_Space then begin
      toggle_presentation_timer state;
      area#misc#queue_draw (); true
    end else if key = GdkKeysyms._Home then begin
      state.current_page := 0;
      area#misc#queue_draw (); true
    end else if key = GdkKeysyms._End then begin
      state.current_page := n_pages - 1;
      area#misc#queue_draw (); true
    end else if key = GdkKeysyms._Right then begin
      state.current_page := min (!(state.current_page) + 1) (n_pages - 1);
      area#misc#queue_draw (); true
    end else if key = GdkKeysyms._Left then begin
      state.current_page := max (!(state.current_page) - 1) 0;
      area#misc#queue_draw (); true
    end else false
  ) |> ignore;
  GMain.Timeout.add ~ms:16 ~callback:(fun () ->
    update_presentation_timer state;
    area#misc#queue_draw ();
    true
  ) |> ignore;
  window#show ();
  area#misc#grab_focus ();
  GMain.main ()
