#!/usr/bin/env python3
import subprocess
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

def toggle():
    subprocess.Popen(["/usr/bin/vicinae", "toggle"])

def clipboard():
    subprocess.Popen(["/usr/bin/vicinae", "cmd", "launch", "clipboard:history"])

class KRunnerApp(dbus.service.Object):
    def __init__(self, bus, path):
        super().__init__(bus, path)

    @dbus.service.method("org.kde.krunner.App", in_signature="", out_signature="")
    def display(self):
        toggle()

    @dbus.service.method("org.kde.krunner.App", in_signature="s", out_signature="")
    def query(self, term):
        toggle()

    @dbus.service.method("org.kde.krunner.App", in_signature="", out_signature="")
    def toggleDisplay(self):
        toggle()

    @dbus.service.method("org.kde.krunner.App", in_signature="", out_signature="")
    def displayWithClipboardContents(self):
        clipboard()

    @dbus.service.method("org.kde.krunner.App", in_signature="", out_signature="")
    def Teardown(self):
        pass

    @dbus.service.method("org.freedesktop.Application", in_signature="a{sv}", out_signature="")
    def Activate(self, platform_data):
        toggle()

    @dbus.service.method("org.freedesktop.Application", in_signature="asa{sv}", out_signature="")
    def Open(self, uris, platform_data):
        toggle()

    @dbus.service.method("org.freedesktop.Application", in_signature="sava{sv}", out_signature="")
    def ActivateAction(self, action_name, parameter, platform_data):
        if action_name == "RunClipboard":
            clipboard()
        else:
            toggle()

if __name__ == "__main__":
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName("org.kde.krunner", bus, do_not_queue=True)
    objs = [
        KRunnerApp(bus, "/App"),
        KRunnerApp(bus, "/org/kde/krunner"),
        KRunnerApp(bus, "/krunner"),
        KRunnerApp(bus, "/")
    ]
    GLib.MainLoop().run()
