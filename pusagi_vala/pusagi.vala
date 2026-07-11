using Gtk;
using GLib;
using Poppler;
using Cairo;

public class PusagiWindow : ApplicationWindow {

    public const double DEFAULT_TOTAL_TIME_SEC = 300.0; // 5分

    private Poppler.Document doc;
    private int current_page = 0;

    private DrawingArea pdf_area;
    private DrawingArea overlay_area;

    private int total_pages = 1;
    private bool presentation_running = false;
    private double elapsed_time_sec = 0.0;
    private double last_update_time_sec = 0.0;
    private double displayed_timer_progress = 0.0;
    private double displayed_page_progress = 0.0;
    private double total_time_sec = DEFAULT_TOTAL_TIME_SEC;

    public PusagiWindow(
        Gtk.Application app, string? filename, double total_time_sec
        ) {
        Object(application: app, title: "Pusagi (Vala)");

        this.total_time_sec = total_time_sec;

        set_default_size(1024, 768);

        // PDF読み込み
        if (filename == null)
        {
            stderr.printf("Error: No PDF file specified\n");
            Process.exit(1);
        }
        string uri = GLib.File.new_for_path(filename).get_uri();
        try {
            doc = new Poppler.Document.from_file(uri, null);
            total_pages = doc.get_n_pages();
        }
        catch (GLib.Error e) {
            stderr.printf("Failed to load PDF: %s\n", e.message);
            return;
        }

        // Stackで重ねる
        var overlay = new Overlay();
        set_child(overlay);

        // PDF描画
        pdf_area = new DrawingArea();
        pdf_area.set_draw_func((area, cr, width, height) => {
            draw_pdf(cr, width, height);
        });

        pdf_area.set_focusable(true);

        // Overlay描画（🐢🐇）
        overlay_area = new DrawingArea();
        overlay_area.set_draw_func((area, cr, width, height) => {
            draw_overlay(cr, width, height);
        });

        overlay.set_child(pdf_area);
        overlay.add_overlay(overlay_area);

        // キー操作
        var controller = new EventControllerKey();

        controller.key_pressed.connect((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Escape)
            {
                close();
            }
            else if (keyval == Gdk.Key.space || keyval == Gdk.Key.KP_Space)
            {
                toggle_presentation_timer();
                overlay_area.queue_draw();
            }
            else if (keyval == Gdk.Key.Home)
            {
                current_page = 0;
                pdf_area.queue_draw();
                overlay_area.queue_draw();
            }
            else if (keyval == Gdk.Key.End)
            {
                current_page = total_pages - 1;
                pdf_area.queue_draw();
                overlay_area.queue_draw();
            }
            else if (keyval == Gdk.Key.Right)
            {
                current_page = int.min(current_page + 1, total_pages - 1);
                pdf_area.queue_draw();
                overlay_area.queue_draw();
            }
            else if (keyval == Gdk.Key.Left)
            {
                current_page = int.max(current_page - 1, 0);
                pdf_area.queue_draw();
                overlay_area.queue_draw();
            }
            return true;
        });

        pdf_area.add_controller(controller);
        pdf_area.grab_focus();

        Timeout.add(16, () => {
            update_presentation_timer();
            overlay_area.queue_draw();
            return true;
        });
    }

    private void draw_pdf(
        Context cr, int width, int height
        ) {
        var page = doc.get_page(current_page);

        double pw, ph;
        page.get_size(out pw, out ph);

        double scale = double.min(width / pw, height / ph);
        double x = (width - pw * scale) / 2.0;
        double y = (height - ph * scale) / 2.0;

        cr.save();
        cr.translate(x, y);
        cr.scale(scale, scale);
        page.render(cr);
        cr.restore();
    }

    private void draw_overlay(
        Context cr, int width, int height
        ) {
        double page_progress = (total_pages > 1)
            ? (double) current_page / (double) (total_pages - 1)
            : 0.0;
        double timer_progress = double.min(elapsed_time_sec / total_time_sec, 1.0);

        if (presentation_running)
        {
            displayed_timer_progress += (timer_progress - displayed_timer_progress) * 0.1;
        }
        displayed_page_progress += (page_progress - displayed_page_progress) * 0.1;

        int bar_y = height - 60;

        // 背景
        cr.set_source_rgba(0, 0, 0, 0.3);
        cr.rectangle(0, height - 30, width, 30);
        cr.fill();

        cr.set_font_size(32);

        // 🐢（プレゼン時間）
        cr.set_source_rgb(0.2, 0.8, 0.2);
        draw_progress_text(
            cr,
            presentation_running ? "🐢" : "🐢💤",
            displayed_timer_progress,
            width,
            bar_y + 30
            );

        // 🐇（ページ進捗）
        cr.set_source_rgb(0.9, 0.3, 0.3);
        draw_progress_text(cr, "🐇", displayed_page_progress, width, bar_y + 30);
    }

    private void toggle_presentation_timer() {
        if (presentation_running)
        {
            update_presentation_timer();
            presentation_running = false;
        }
        else
        {
            last_update_time_sec = get_monotonic_time() / 1000000.0;
            presentation_running = true;
        }
    }

    private void update_presentation_timer() {
        if (!presentation_running)
        {
            return;
        }

        double now = get_monotonic_time() / 1000000.0;
        elapsed_time_sec += now - last_update_time_sec;
        last_update_time_sec = now;
    }

    private void draw_progress_text(
        Context cr, string text, double progress, int width, double y
        ) {
        cr.save();
        var layout = Pango.cairo_create_layout(cr);
        var desc = Pango.FontDescription.from_string("Sans Bold 20");

        layout.set_font_description(desc);
        layout.set_text(text, -1);

        int text_width, text_height;
        layout.get_pixel_size(out text_width, out text_height);

        double clamped_progress = double.min(double.max(progress, 0.0), 1.0);
        double x = clamped_progress * double.max(width - text_width, 0);

        cr.move_to(x, y);
        Pango.cairo_show_layout(cr, layout);
        cr.restore();
    }

}

public class PusagiApp : Gtk.Application {
    private string? filename;
    private double total_time_sec;

    public PusagiApp(double total_time_sec) {
        Object(
            application_id: "com.metasepi-design.pusagi",
            flags: ApplicationFlags.HANDLES_OPEN
            );
        this.total_time_sec = total_time_sec;
    }

    protected override void activate() {
        var win = new PusagiWindow(this, filename, total_time_sec);
        win.present();
    }

    protected override void open(File[] files, string hint) {
        if (files.length > 0)
        {
            filename = files[0].get_path();
        }
        activate();
    }
}

int main(
    string[] args
    ) {
    double total_time_sec = PusagiWindow.DEFAULT_TOTAL_TIME_SEC;
    string? new_directory = null;
    string[] app_args = {};

    app_args += args[0];

    for (int i = 1; i < args.length; i++)
    {
        string arg = args[i];

        if (arg == "-h" || arg == "--help")
        {
            print_help(args[0]);
            return 0;
        }
        else if (arg == "-t")
        {
            if (i + 1 >= args.length)
            {
                stderr.printf("Error: %s requires a value in minutes\n", arg);
                print_help(args[0]);
                return 1;
            }

            total_time_sec = parse_presentation_minutes(args[++i]);
        }
        else if (arg == "-n")
        {
            if (i + 1 >= args.length)
            {
                stderr.printf("Error: %s requires a directory name\n", arg);
                print_help(args[0]);
                return 1;
            }

            new_directory = args[++i];
        }
        else
        {
            app_args += arg;
        }
    }

    if (new_directory != null)
    {
        if (app_args.length > 1)
        {
            stderr.printf("Error: -n cannot be used with a PDF file\n");
            print_help(args[0]);
            return 1;
        }

        return create_from_template(new_directory);
    }

    if (app_args.length == 1)
    {
        print_help(args[0]);
        return 0;
    }

    return new PusagiApp(total_time_sec).run(app_args);
}

void print_help(string program_name) {
    stdout.printf("Usage: %s [OPTIONS] PDF_FILE\n", program_name);
    stdout.printf("       %s -n DIRECTORY\n", program_name);
    stdout.printf("\n");
    stdout.printf("Options:\n");
    stdout.printf("  -n DIRECTORY    Copy template contents into DIRECTORY and exit\n");
    stdout.printf("  -t MINUTES      Set presentation duration in minutes (default: 5)\n");
    stdout.printf("  -h, --help      Show this help message and exit\n");
    stdout.printf("\n");
    stdout.printf("Keys:\n");
    stdout.printf("  Space           Start or pause the presentation timer\n");
    stdout.printf("  Left / Right    Move to the previous or next page\n");
    stdout.printf("  Home / End      Move to the first or last page\n");
    stdout.printf("  Esc             Quit\n");
}

double parse_presentation_minutes(string text) {
    double minutes = double.parse(text);

    if (minutes <= 0.0)
    {
        stderr.printf("Error: presentation minutes must be greater than 0\n");
        Process.exit(1);
    }

    return minutes * 60.0;
}

int create_from_template(string directory_name) {
    File destination = File.new_for_path(directory_name);

    try {
        create_directory_if_needed(destination);
        copy_resource_directory_contents(
            "/com/metasepi-design/pusagi/template/",
            destination
            );
    }
    catch (GLib.Error e) {
        stderr.printf("Error: failed to copy template: %s\n", e.message);
        return 1;
    }

    stdout.printf("Created %s from template\n", directory_name);
    return 0;
}

void create_directory_if_needed(File directory) throws GLib.Error {
    try {
        directory.make_directory_with_parents();
    }
    catch (IOError.EXISTS e) {
        FileInfo info = directory.query_info(
            FileAttribute.STANDARD_TYPE,
            FileQueryInfoFlags.NONE
            );

        if (info.get_file_type() != FileType.DIRECTORY)
        {
            throw e;
        }
    }
}

void copy_resource_directory_contents(string resource_path, File destination) throws GLib.Error {
    string[] children = resources_enumerate_children(
        resource_path,
        ResourceLookupFlags.NONE
        );

    foreach (string child in children)
    {
        string child_resource_path = resource_path + child;
        string child_name = child.has_suffix("/") ? child.substring(0, child.length - 1) : child;
        File child_destination = destination.get_child(child_name);

        if (child.has_suffix("/"))
        {
            create_directory_if_needed(child_destination);
            copy_resource_directory_contents(child_resource_path, child_destination);
        }
        else
        {
            Bytes data = resources_lookup_data(
                child_resource_path,
                ResourceLookupFlags.NONE
                );
            unowned uint8[] bytes = data.get_data();

            FileUtils.set_data(child_destination.get_path(), bytes);
        }
    }
}
