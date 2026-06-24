/// pusagi - PDF presentation tool
/// Ported from Vala to Rust using GTK4 + Cairo + Poppler (via FFI)

use std::cell::RefCell;
use std::rc::Rc;
use std::time::Instant;

use gtk4::prelude::*;
use gtk4::{Application, ApplicationWindow, DrawingArea, EventControllerKey, Overlay};

// ---------------------------------------------------------------------------
// Poppler GLib FFI
// ---------------------------------------------------------------------------

#[allow(non_camel_case_types)]
mod poppler_ffi {
    use std::ffi::{c_char, c_double, c_int, c_void};

    pub type PopplerDocument = c_void;
    pub type PopplerPage = c_void;
    pub type GError = c_void;
    pub type CairoT = c_void;

    #[link(name = "poppler-glib")]
    extern "C" {
        pub fn poppler_document_new_from_file(
            uri: *const c_char,
            password: *const c_char,
            error: *mut *mut GError,
        ) -> *mut PopplerDocument;

        pub fn poppler_document_get_n_pages(document: *mut PopplerDocument) -> c_int;

        pub fn poppler_document_get_page(
            document: *mut PopplerDocument,
            index: c_int,
        ) -> *mut PopplerPage;

        pub fn poppler_page_get_size(
            page: *mut PopplerPage,
            width: *mut c_double,
            height: *mut c_double,
        );

        pub fn poppler_page_render(page: *mut PopplerPage, cairo: *mut CairoT);

        pub fn g_object_unref(object: *mut c_void);
    }
}

// ---------------------------------------------------------------------------
// Safe wrappers
// ---------------------------------------------------------------------------

struct PopplerDoc(*mut poppler_ffi::PopplerDocument);
struct PopplerPage(*mut poppler_ffi::PopplerPage);

// SAFETY: We only ever access from the GTK main thread.
unsafe impl Send for PopplerDoc {}
unsafe impl Send for PopplerPage {}

impl Drop for PopplerDoc {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe { poppler_ffi::g_object_unref(self.0) };
        }
    }
}

impl Drop for PopplerPage {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe { poppler_ffi::g_object_unref(self.0) };
        }
    }
}

impl PopplerDoc {
    fn from_file(path: &str) -> Result<Self, String> {
        let uri = if path.starts_with('/') {
            format!("file://{path}")
        } else {
            let abs = std::fs::canonicalize(path).map_err(|e| e.to_string())?;
            format!("file://{}", abs.display())
        };

        let uri_cstr = std::ffi::CString::new(uri).map_err(|e| e.to_string())?;
        let mut error: *mut poppler_ffi::GError = std::ptr::null_mut();

        let doc = unsafe {
            poppler_ffi::poppler_document_new_from_file(
                uri_cstr.as_ptr(),
                std::ptr::null(),
                &mut error,
            )
        };

        if doc.is_null() {
            Err(format!("Failed to open PDF: {path}"))
        } else {
            Ok(PopplerDoc(doc))
        }
    }

    fn n_pages(&self) -> i32 {
        unsafe { poppler_ffi::poppler_document_get_n_pages(self.0) }
    }

    fn get_page(&self, index: i32) -> Option<PopplerPage> {
        let p = unsafe { poppler_ffi::poppler_document_get_page(self.0, index) };
        if p.is_null() {
            None
        } else {
            Some(PopplerPage(p))
        }
    }
}

impl PopplerPage {
    fn size(&self) -> (f64, f64) {
        let mut w: f64 = 0.0;
        let mut h: f64 = 0.0;
        unsafe { poppler_ffi::poppler_page_get_size(self.0, &mut w, &mut h) };
        (w, h)
    }

    fn render(&self, cr: &cairo::Context) {
        // Get the raw cairo_t pointer using glib's NativeObject trait
        use glib::translate::ToGlibPtr;
        let raw_cr: *mut cairo::ffi::cairo_t = cr.to_glib_none().0;
        let raw_cr = raw_cr as *mut poppler_ffi::CairoT;
        unsafe { poppler_ffi::poppler_page_render(self.0, raw_cr) };
    }
}

// ---------------------------------------------------------------------------
// Application state (shared via Rc<RefCell<...>>)
// ---------------------------------------------------------------------------

const DEFAULT_TOTAL_TIME_SEC: f64 = 300.0;

struct AppStateInner {
    doc: PopplerDoc,
    current_page: i32,
    total_pages: i32,
    presentation_running: bool,
    elapsed_time_sec: f64,
    last_update: Option<Instant>,
    displayed_timer_progress: f64,
    displayed_page_progress: f64,
    total_time_sec: f64,
}

#[derive(Clone)]
struct AppState(Rc<RefCell<AppStateInner>>);

impl AppState {
    fn new(doc: PopplerDoc, total_time_sec: f64) -> Self {
        let total_pages = doc.n_pages().max(1);
        AppState(Rc::new(RefCell::new(AppStateInner {
            doc,
            current_page: 0,
            total_pages,
            presentation_running: false,
            elapsed_time_sec: 0.0,
            last_update: None,
            displayed_timer_progress: 0.0,
            displayed_page_progress: 0.0,
            total_time_sec,
        })))
    }

    fn toggle_timer(&self) {
        let mut s = self.0.borrow_mut();
        if s.presentation_running {
            if let Some(t) = s.last_update.take() {
                s.elapsed_time_sec += t.elapsed().as_secs_f64();
            }
            s.presentation_running = false;
        } else {
            s.last_update = Some(Instant::now());
            s.presentation_running = true;
        }
    }

    fn update_timer(&self) {
        let mut s = self.0.borrow_mut();
        if !s.presentation_running {
            return;
        }
        if let Some(t) = s.last_update {
            let elapsed = t.elapsed().as_secs_f64();
            s.elapsed_time_sec += elapsed;
            s.last_update = Some(Instant::now());
        }
    }

    fn next_page(&self) {
        let mut s = self.0.borrow_mut();
        let max = s.total_pages - 1;
        s.current_page = (s.current_page + 1).min(max);
    }

    fn prev_page(&self) {
        let mut s = self.0.borrow_mut();
        s.current_page = (s.current_page - 1).max(0);
    }

    fn first_page(&self) {
        self.0.borrow_mut().current_page = 0;
    }

    fn last_page(&self) {
        let total = self.0.borrow().total_pages;
        self.0.borrow_mut().current_page = total - 1;
    }
}

// ---------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------

fn draw_pdf(cr: &cairo::Context, width: i32, height: i32, state: &AppState) {
    // Black background
    cr.set_source_rgb(0.0, 0.0, 0.0);
    let _ = cr.paint();

    let s = state.0.borrow();
    if let Some(page) = s.doc.get_page(s.current_page) {
        let (pw, ph) = page.size();
        let scale = (width as f64 / pw).min(height as f64 / ph);
        let x = (width as f64 - pw * scale) / 2.0;
        let y = (height as f64 - ph * scale) / 2.0;

        cr.save().unwrap();
        cr.translate(x, y);
        cr.scale(scale, scale);
        page.render(cr);
        cr.restore().unwrap();
    }
}

fn draw_overlay(cr: &cairo::Context, width: i32, height: i32, state: &AppState) {
    let mut s = state.0.borrow_mut();

    let page_progress = if s.total_pages > 1 {
        s.current_page as f64 / (s.total_pages - 1) as f64
    } else {
        0.0
    };
    let timer_progress = (s.elapsed_time_sec / s.total_time_sec).min(1.0);

    if s.presentation_running {
        s.displayed_timer_progress += (timer_progress - s.displayed_timer_progress) * 0.1;
    }
    s.displayed_page_progress += (page_progress - s.displayed_page_progress) * 0.1;

    let disp_timer = s.displayed_timer_progress;
    let disp_page = s.displayed_page_progress;
    let running = s.presentation_running;
    drop(s);

    let bar_h: i32 = 30;
    let bar_y = (height - bar_h) as f64;

    // Semi-transparent background bar
    cr.set_source_rgba(0.0, 0.0, 0.0, 0.3);
    cr.rectangle(0.0, bar_y, width as f64, bar_h as f64);
    let _ = cr.fill();

    // 🐢 timer progress (green)
    let turtle_text = if running { "🐢" } else { "🐢💤" };
    draw_progress_emoji(cr, turtle_text, disp_timer, width, height, bar_h, 0.2, 0.8, 0.2);

    // 🐇 page progress (red)
    draw_progress_emoji(cr, "🐇", disp_page, width, height, bar_h, 0.9, 0.3, 0.3);
}

fn draw_progress_emoji(
    cr: &cairo::Context,
    text: &str,
    progress: f64,
    width: i32,
    height: i32,
    bar_h: i32,
    r: f64,
    g: f64,
    b: f64,
) {
    cr.save().unwrap();
    cr.set_source_rgb(r, g, b);

    let layout = pangocairo::functions::create_layout(cr);
    let desc = pango::FontDescription::from_string("Noto Color Emoji 20");
    layout.set_font_description(Some(&desc));
    layout.set_text(text);

    let (text_w, text_h) = layout.pixel_size();

    let bar_y = (height - bar_h) as f64;
    let clamped = progress.clamp(0.0, 1.0);
    let max_x = (width - text_w).max(0) as f64;
    let x = clamped * max_x;
    let y = bar_y + (bar_h as f64 - text_h as f64) / 2.0;

    cr.move_to(x, y);
    pangocairo::functions::show_layout(cr, &layout);

    cr.restore().unwrap();
}

// ---------------------------------------------------------------------------
// UI construction
// ---------------------------------------------------------------------------

fn build_ui(app: &Application, state: AppState) {
    let window = ApplicationWindow::builder()
        .application(app)
        .title("Pusagi (Rust)")
        .default_width(1024)
        .default_height(768)
        .build();

    let pdf_area = DrawingArea::new();
    pdf_area.set_focusable(true);
    pdf_area.set_hexpand(true);
    pdf_area.set_vexpand(true);

    let overlay_area = DrawingArea::new();
    overlay_area.set_can_target(false);
    overlay_area.set_hexpand(true);
    overlay_area.set_vexpand(true);

    {
        let state = state.clone();
        pdf_area.set_draw_func(move |_area, cr, w, h| {
            draw_pdf(cr, w, h, &state);
        });
    }

    {
        let state = state.clone();
        overlay_area.set_draw_func(move |_area, cr, w, h| {
            draw_overlay(cr, w, h, &state);
        });
    }

    let overlay = Overlay::new();
    overlay.set_child(Some(&pdf_area));
    overlay.add_overlay(&overlay_area);
    window.set_child(Some(&overlay));

    // Key events
    let key_ctrl = EventControllerKey::new();
    {
        let state = state.clone();
        let pdf_ref = pdf_area.clone();
        let ovl_ref = overlay_area.clone();
        let win_ref = window.clone();

        key_ctrl.connect_key_pressed(move |_ctrl, keyval, _code, _mods| {
            use gtk4::gdk::Key;
            match keyval {
                Key::Escape => {
                    win_ref.close();
                }
                Key::space | Key::KP_Space => {
                    state.toggle_timer();
                    ovl_ref.queue_draw();
                }
                Key::Home => {
                    state.first_page();
                    pdf_ref.queue_draw();
                    ovl_ref.queue_draw();
                }
                Key::End => {
                    state.last_page();
                    pdf_ref.queue_draw();
                    ovl_ref.queue_draw();
                }
                Key::Right => {
                    state.next_page();
                    pdf_ref.queue_draw();
                    ovl_ref.queue_draw();
                }
                Key::Left => {
                    state.prev_page();
                    pdf_ref.queue_draw();
                    ovl_ref.queue_draw();
                }
                _ => {}
            }
            glib::Propagation::Stop
        });
    }

    pdf_area.add_controller(key_ctrl);
    pdf_area.grab_focus();

    // ~60 fps refresh timer
    {
        let state = state.clone();
        let ovl_ref = overlay_area.clone();
        glib::timeout_add_local(std::time::Duration::from_millis(16), move || {
            state.update_timer();
            ovl_ref.queue_draw();
            glib::ControlFlow::Continue
        });
    }

    window.present();
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn print_help(prog: &str) {
    println!("Usage: {prog} [OPTIONS] PDF_FILE");
    println!();
    println!("Options:");
    println!("  -t MINUTES      Set presentation duration in minutes (default: 5)");
    println!("  -h, --help      Show this help message and exit");
    println!();
    println!("Keys:");
    println!("  Space           Start or pause the presentation timer");
    println!("  Left / Right    Move to the previous or next page");
    println!("  Home / End      Move to the first or last page");
    println!("  Esc             Quit");
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let prog = args[0].clone();

    let mut total_time_sec = DEFAULT_TOTAL_TIME_SEC;
    let mut pdf_path: Option<String> = None;

    let mut i = 1usize;
    while i < args.len() {
        let arg = &args[i];
        if arg == "-h" || arg == "--help" {
            print_help(&prog);
            return;
        } else if arg == "-t" {
            i += 1;
            if i >= args.len() {
                eprintln!("Error: -t requires a value in minutes");
                print_help(&prog);
                std::process::exit(1);
            }
            let minutes: f64 = match args[i].parse() {
                Ok(v) => v,
                Err(_) => {
                    eprintln!("Error: invalid number of minutes '{}'", args[i]);
                    std::process::exit(1);
                }
            };
            if minutes <= 0.0 {
                eprintln!("Error: presentation minutes must be greater than 0");
                std::process::exit(1);
            }
            total_time_sec = minutes * 60.0;
        } else {
            pdf_path = Some(arg.clone());
        }
        i += 1;
    }

    let pdf_path = match pdf_path {
        Some(p) => p,
        None => {
            print_help(&prog);
            return;
        }
    };

    // Load PDF before GTK init so we fail fast
    let doc = PopplerDoc::from_file(&pdf_path).unwrap_or_else(|e| {
        eprintln!("{e}");
        std::process::exit(1);
    });

    let state = AppState::new(doc, total_time_sec);

    // Pass only argv[0] to GTK to avoid it consuming our arguments
    let app = Application::builder()
        .application_id("com.metasepi-design.pusagi")
        .build();

    app.connect_activate(move |app| {
        build_ui(app, state.clone());
    });

    app.run_with_args(&[prog.as_str()]);
}
