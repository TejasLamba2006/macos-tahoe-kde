#include <QResource>
#include <QString>
#include <cstdlib>

__attribute__((constructor))
static void register_bartender_rcc() {
    const char* home = std::getenv("HOME");
    if (home) {
        QResource::registerResource(QString::fromUtf8(home) + QStringLiteral("/.local/share/macos-tahoe/bartender.rcc"));
    }
}
