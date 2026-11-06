#include <QResource>
#include <QString>
#include <QtQml/qqmlprivate.h>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>

static bool is_plasmashell() {
    static int cached = -1;
    if (cached != -1) return cached == 1;
    FILE* f = fopen("/proc/self/comm", "r");
    if (!f) { cached = 0; return false; }
    char comm[64] = {0};
    if (!fgets(comm, sizeof(comm), f)) {
        fclose(f);
        cached = 0;
        return false;
    }
    fclose(f);
    if (std::strncmp(comm, "plasmashell", 11) == 0) {
        // Clear LD_PRELOAD from environment immediately so child apps spawned by plasmashell
        // (Konsole, Chrome, scripts, etc.) never inherit LD_PRELOAD!
        unsetenv("LD_PRELOAD");
        cached = 1;
        return true;
    }
    cached = 0;
    return false;
}

__attribute__((constructor))
static void register_bartender_rcc() {
    if (!is_plasmashell()) return;
    const char* home = std::getenv("HOME");
    if (home) {
        QResource::registerResource(QString::fromUtf8(home) + QStringLiteral("/.local/share/macos-tahoe/bartender.rcc"));
    }
}

namespace QQmlPrivate {
int qmlregister(RegistrationType type, void *data) {
    using OrigFn = int (*)(RegistrationType, void *);
    static OrigFn orig = reinterpret_cast<OrigFn>(dlsym(RTLD_NEXT, "_ZN11QQmlPrivate11qmlregisterENS_16RegistrationTypeEPv"));
    if (type == QmlUnitCacheHookRegistration && is_plasmashell() && data) {
        auto *hook = reinterpret_cast<RegisterQmlUnitCacheHook *>(data);
        if (hook->lookupCachedQmlUnit) {
            Dl_info info{};
            if (dladdr(reinterpret_cast<void *>(hook->lookupCachedQmlUnit), &info) && info.dli_fname) {
                if (std::strstr(info.dli_fname, "org.kde.plasma.systemtray.so") ||
                    std::strstr(info.dli_fname, "org.kde.plasma.digitalclock.so") ||
                    std::strstr(info.dli_fname, "org.kde.plasma.kickoff.so")) {
                    return 0;
                }
            }
        }
    }
    return orig ? orig(type, data) : 0;
}
}
