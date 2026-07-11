#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickImageProvider>
#include <QPdfDocument>
#include <QPainter>
#include <QMutex>
#include <QMutexLocker>
#include <QUrl>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <cstdio>
#include <cstdlib>
#include <cmath>

static void printHelp(const char *prog) {
    printf("Usage: %s [OPTIONS] PDF_FILE\n", prog);
    printf("       %s -n DIRECTORY\n\n", prog);
    printf("Options:\n");
    printf("  -n DIRECTORY    Copy template contents into DIRECTORY and exit\n");
    printf("  -t MINUTES      Set presentation duration in minutes (default: 5)\n");
    printf("  -h, --help      Show this help message and exit\n\n");
    printf("Keys:\n");
    printf("  Space           Start or pause the presentation timer\n");
    printf("  Left / Right    Move to the previous or next page\n");
    printf("  Home / End      Move to the first or last page\n");
    printf("  Esc             Quit\n");
}

static bool copyTemplateFile(const QString &resourcePath, const QString &destinationPath) {
    QFile source(resourcePath);
    if (!source.open(QIODevice::ReadOnly)) {
        fprintf(stderr, "Error: failed to read template file: %s\n", qPrintable(resourcePath));
        return false;
    }

    QFileInfo info(destinationPath);
    if (!QDir().mkpath(info.path())) {
        fprintf(stderr, "Error: failed to create directory: %s\n", qPrintable(info.path()));
        return false;
    }

    QFile destination(destinationPath);
    if (!destination.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        fprintf(stderr, "Error: failed to write template file: %s\n", qPrintable(destinationPath));
        return false;
    }

    destination.write(source.readAll());
    return true;
}

static int createFromTemplate(const QString &directoryName) {
    if (!QDir().mkpath(directoryName)) {
        fprintf(stderr, "Error: failed to create directory: %s\n", qPrintable(directoryName));
        return 1;
    }

    const QList<QString> files = {
        "Makefile",
        "header.tex",
        "img/takibi-icon-v3.jpg",
        "slide.md",
    };

    for (const QString &file : files) {
        if (!copyTemplateFile(":/template/" + file, QDir(directoryName).filePath(file)))
            return 1;
    }

    printf("Created %s from template\n", qPrintable(directoryName));
    return 0;
}

// Renders PDF pages into QImage on demand.
// Image URL: "image://pdf/<page-index>"
// Fills the requested size with black and centers the page (aspect-ratio preserved).
class PdfImageProvider : public QQuickImageProvider {
    QPdfDocument m_doc;
    QMutex       m_mutex;

public:
    explicit PdfImageProvider(const QString &path)
        : QQuickImageProvider(QQuickImageProvider::Image)
    {
        if (m_doc.load(path) != QPdfDocument::Error::None) {
            fprintf(stderr, "Failed to load PDF: %s\n", qPrintable(path));
            std::exit(1);
        }
    }

    int pageCount() const { return m_doc.pageCount(); }

    QImage requestImage(const QString &id, QSize *size,
                        const QSize &requestedSize) override
    {
        QMutexLocker lock(&m_mutex);
        int page   = id.toInt();
        QSize target = requestedSize.isEmpty() ? QSize(1024, 768) : requestedSize;

        QImage result(target, QImage::Format_RGB32);
        result.fill(Qt::black);

        if (page >= 0 && page < m_doc.pageCount()) {
            QSizeF ps    = m_doc.pagePointSize(page);
            double scale = std::min(target.width()  / ps.width(),
                                    target.height() / ps.height());
            QSize renderSize(static_cast<int>(ps.width()  * scale),
                             static_cast<int>(ps.height() * scale));
            QImage pageImg = m_doc.render(page, renderSize);
            QPainter painter(&result);
            painter.drawImage((target.width()  - renderSize.width())  / 2,
                              (target.height() - renderSize.height()) / 2,
                              pageImg);
        }

        if (size) *size = target;
        return result;
    }
};

int main(int argc, char *argv[]) {
    double  totalTimeSec = 300.0;
    QString newDirectory;
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
            bool ok;
            double m = QString(argv[++i]).toDouble(&ok);
            if (!ok || m <= 0.0) {
                fprintf(stderr, "Error: presentation minutes must be greater than 0\n");
                return 1;
            }
            totalTimeSec = m * 60.0;
        } else if (arg == "-n") {
            if (i + 1 >= argc) {
                fprintf(stderr, "Error: -n requires a directory name\n");
                printHelp(argv[0]);
                return 1;
            }
            newDirectory = argv[++i];
        } else {
            pdfPath = arg;
        }
    }

    if (!newDirectory.isEmpty()) {
        if (!pdfPath.isEmpty()) {
            fprintf(stderr, "Error: -n cannot be used with a PDF file\n");
            printHelp(argv[0]);
            return 1;
        }
        return createFromTemplate(newDirectory);
    }

    if (pdfPath.isEmpty()) {
        printHelp(argv[0]);
        return 0;
    }

    QGuiApplication app(argc, argv);

    auto *provider = new PdfImageProvider(pdfPath);
    int   pageCount = provider->pageCount();

    QQmlApplicationEngine engine;
    engine.addImageProvider("pdf", provider);

    QQmlContext *ctx = engine.rootContext();
    ctx->setContextProperty("pageCount",    pageCount);
    ctx->setContextProperty("totalTimeSec", totalTimeSec);
    engine.load(QUrl("qrc:/pusagi.qml"));

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
