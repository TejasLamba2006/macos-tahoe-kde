#!/usr/bin/env python3
"""Build scoped Plasma UI overrides; never replace unrelated desktop configuration."""
import argparse
import os
import pwd
import shutil
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def resolve_rcc() -> str:
    for candidate in ("/usr/lib/qt6/rcc", "/usr/libexec/rcc", shutil.which("rcc")):
        if candidate and Path(candidate).is_file():
            return candidate
    raise FileNotFoundError("Qt rcc binary not found (/usr/lib/qt6/rcc or rcc)")


def resolve_fullname() -> str:
    user = os.environ.get("USER", "user")
    try:
        gecos = pwd.getpwuid(os.getuid()).pw_gecos.split(",")[0].strip()
        if gecos:
            return gecos
    except KeyError:
        pass
    return user


def build(output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    rcc_bin = resolve_rcc()
    fullname = resolve_fullname()
    with tempfile.TemporaryDirectory(prefix="macos-ui-build-") as directory:
        staged = Path(directory) / "bartender"
        shutil.copytree(ROOT / "patches/bartender/src", staged)
        for source in staged.rglob("*.qml"):
            source.write_text(source.read_text().replace("@HOME@", str(Path.home()))
                              .replace("@USER_FULLNAME@", fullname))
        subprocess.run([rcc_bin, "-binary", str(staged / "bartender.qrc"),
                        "-o", str(output / "bartender.rcc")], check=True)
        for name in ("notification-center", "dock"):
            manifest = ROOT / "patches" / name / "src" / f"{name}.qrc"
            if manifest.exists():
                subprocess.run([rcc_bin, "-binary", str(manifest), "-o",
                                str(output / f"{name}.rcc")], check=True)
    flags = subprocess.check_output(["pkg-config", "--cflags", "--libs", "Qt6Core", "Qt6Qml"], text=True).split()
    subprocess.run(["g++", "-shared", "-fPIC", "-O2",
                    str(ROOT / "patches/bartender/bartender_preload.cpp"),
                    *flags, "-ldl", "-o", str(output / "libmacos_bartender.so")], check=True)


def install(output: Path) -> None:
    home = Path.home()
    data = home / ".local/share/macos-tahoe"
    library = home / ".local/lib"
    backup = data / "backups" / (datetime.now().strftime("%Y%m%d-%H%M%S-%f") + "-ui")
    backup.mkdir(parents=True)
    library.mkdir(parents=True, exist_ok=True)
    for stale in ("notification-center.rcc", "dock.rcc", "brightness.rcc"):
        stale_path = data / stale
        if stale_path.exists() and not (output / stale).exists():
            shutil.copy2(stale_path, backup / stale_path.name)
            stale_path.unlink()
    for source in output.iterdir():
        if source.suffix not in (".rcc", ".so"):
            continue
        target = (library if source.suffix == ".so" else data) / source.name
        if target.exists():
            shutil.copy2(target, backup / target.name)
        staged = target.with_name(target.name + ".new")
        shutil.copy2(source, staged)
        os.replace(staged, target)
    shutil.rmtree(home / ".cache/plasmashell/qmlcache", ignore_errors=True)
    print(f"Installed UI resources; backup: {backup}")
    print("Restart Plasma explicitly with systemctl --user restart plasma-plasmashell.service")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()
    build(args.output.resolve())
    if args.install:
        install(args.output.resolve())
