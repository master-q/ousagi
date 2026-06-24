#include <QApplication>
#include <QWidget>
#include <QPainter>
#include <QTimer>
#include <QKeyEvent>
#include <QElapsedTimer>
#include <QPdfDocument>
#include <QPdfDocumentRenderOptions>
#include <QSizeF>
#include <QFontMetrics>
#include <cmath>
#include <cstdio>
#include <cstdlib>

static constexpr double DEFAULT_TOTAL_TIME_SEC = 300.0;

class PusagiWidget : public QWidget {
    Q_OBJECT

    QPdfDocument m_doc;
    int m_currentPage = 0;
    int m_totalPages = 1;

    bool   m_running = false;
    double m_elapsedSec = 0.0;
    double m_totalTimeSec;
    QElapsedTimer m_clock;

    double m_dispTimerProgress = 0.0;
    double m_dispPageProgress  = 0.0;

public:
    PusagiWidget(const QString &path, double totalTimeSec, QWidget *parent = nullptr)
        : QWidget(parent), m_totalTimeSec(totalTimeSec)
    {
        auto err = m_doc.load(path);
        if (err != QPdfDocument::Error::None) {
            fprintf(stderr, "Failed to load PDF: %s\n", qPrintable(path));
            std::exit(1);
        }
        m_totalPages = m_doc.pageCount();

        setWindowTitle("Pusagi (Qt6)");
        resize(1024, 768);
        setFocusPolicy(Qt::StrongFocus);

        auto *timer = new QTimer(this);
        connect(timer, &QTimer::timeout, this, [this] {
            updateTimer();
            update();
        });
        timer->start(16);
    }

protected:
    void paintEvent(QPaintEvent *) override {
        QPainter p(this);
        drawPage(p);
        drawOverlay(p);
    }

    void keyPressEvent(QKeyEvent *ev) override {
        switch (ev->key()) {
        case Qt::Key_Escape:
            close();
            break;
        case Qt::Key_Space:
            toggleTimer();
            update();
            break;
        case Qt::Key_Home:
            m_currentPage = 0;
            update();
            break;
        case Qt::Key_End:
            m_currentPage = m_totalPages - 1;
            update();
            break;
        case Qt::Key_Right:
            m_currentPage = std::min(m_currentPage + 1, m_totalPages - 1);
            update();
            break;
        case Qt::Key_Left:
            m_currentPage = std::max(m_currentPage - 1, 0);
            update();
            break;
        default:
            QWidget::keyPressEvent(ev);
        }
    }

private:
    void toggleTimer() {
        if (m_running) {
            m_elapsedSec += m_clock.elapsed() / 1000.0;
            m_running = false;
        } else {
            m_clock.restart();
            m_running = true;
        }
    }

    void updateTimer() {
        if (!m_running) return;
        m_elapsedSec += m_clock.restart() / 1000.0;
    }

    void drawPage(QPainter &p) {
        QSizeF pointSize = m_doc.pagePointSize(m_currentPage);
        int w = width(), h = height();
        double scale = std::min(w / pointSize.width(), h / pointSize.height());
        QSize renderSize(
            static_cast<int>(pointSize.width()  * scale),
            static_cast<int>(pointSize.height() * scale)
        );
        QImage img = m_doc.render(m_currentPage, renderSize);
        int ox = (w - renderSize.width())  / 2;
        int oy = (h - renderSize.height()) / 2;
        p.fillRect(rect(), Qt::black);
        p.drawImage(ox, oy, img);
    }

    void drawOverlay(QPainter &p) {
        int w = width(), h = height();

        double pageProgress = (m_totalPages > 1)
            ? static_cast<double>(m_currentPage) / (m_totalPages - 1)
            : 0.0;
        double timerProgress = std::min(m_elapsedSec / m_totalTimeSec, 1.0);

        if (m_running)
            m_dispTimerProgress += (timerProgress - m_dispTimerProgress) * 0.1;
        m_dispPageProgress += (pageProgress - m_dispPageProgress) * 0.1;

        // Background bar
        p.fillRect(0, h - 30, w, 30, QColor(0, 0, 0, 76));

        QFont emojiFont("Noto Color Emoji");
        emojiFont.setPointSize(20);
        p.setFont(emojiFont);

        // 🐢 timer progress
        p.setPen(QColor(51, 204, 51));
        QString turtleText = m_running
            ? QString::fromUtf8("\U0001F422")
            : QString::fromUtf8("\U0001F422\U0001F4A4");
        drawProgressText(p, turtleText, m_dispTimerProgress, w, h - 30);

        // 🐇 page progress
        p.setPen(QColor(230, 76, 76));
        drawProgressText(p, QString::fromUtf8("\U0001F407"), m_dispPageProgress, w, h - 30);
    }

    void drawProgressText(QPainter &p, const QString &text, double progress,
                          int totalWidth, int y) {
        QFontMetrics fm(p.font());
        int textWidth = fm.horizontalAdvance(text);
        double clamped = std::max(0.0, std::min(progress, 1.0));
        int x = static_cast<int>(clamped * std::max(totalWidth - textWidth, 0));
        p.drawText(x, y, totalWidth, 30, Qt::AlignLeft | Qt::AlignVCenter, text);
    }
};

static void printHelp(const char *prog) {
    printf("Usage: %s [OPTIONS] PDF_FILE\n\n", prog);
    printf("Options:\n");
    printf("  -t MINUTES      Set presentation duration in minutes (default: 5)\n");
    printf("  -h, --help      Show this help message and exit\n\n");
    printf("Keys:\n");
    printf("  Space           Start or pause the presentation timer\n");
    printf("  Left / Right    Move to the previous or next page\n");
    printf("  Home / End      Move to the first or last page\n");
    printf("  Esc             Quit\n");
}

static double parseMinutes(const char *s) {
    double m = atof(s);
    if (m <= 0.0) {
        fprintf(stderr, "Error: presentation minutes must be greater than 0\n");
        std::exit(1);
    }
    return m * 60.0;
}

#include "pusagi.moc"

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);

    double totalTimeSec = DEFAULT_TOTAL_TIME_SEC;
    QString pdfPath;

    for (int i = 1; i < argc; ++i) {
        QString arg = argv[i];
        if (arg == "-h" || arg == "--help") {
            printHelp(argv[0]);
            return 0;
        } else if (arg == "-t") {
            if (i + 1 >= argc) {
                fprintf(stderr, "Error: -t requires a value in minutes\n");
                printHelp(argv[0]);
                return 1;
            }
            totalTimeSec = parseMinutes(argv[++i]);
        } else {
            pdfPath = arg;
        }
    }

    if (pdfPath.isEmpty()) {
        printHelp(argv[0]);
        return 0;
    }

    PusagiWidget w(pdfPath, totalTimeSec);
    w.show();
    return app.exec();
}
