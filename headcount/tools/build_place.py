#!/usr/bin/env python3
"""Packs src/ into Headcount.rbxlx, a place file Roblox Studio opens directly.

Use this if you do not want to install Rojo. Run from the headcount folder:
    python3 tools/build_place.py
File naming follows Rojo: x.server.lua = Script, x.client.lua = LocalScript,
x.lua = ModuleScript, a folder = Folder.
"""
import os
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "Headcount.rbxlx")

counter = 0


def ref():
    global counter
    counter += 1
    return "RBX%d" % counter


def item(class_name, name, body="", extra_props=""):
    return (
        '<Item class="%s" referent="%s"><Properties><string name="Name">%s</string>%s</Properties>%s</Item>\n'
        % (class_name, ref(), escape(name), extra_props, body)
    )


def script(class_name, name, path):
    with open(path, encoding="utf-8") as handle:
        source = handle.read()
    source = source.replace("]]>", "]]]]><![CDATA[>")
    return item(class_name, name, "", '<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString>' % source)


def walk(directory):
    out = ""
    for entry in sorted(os.listdir(directory)):
        path = os.path.join(directory, entry)
        if os.path.isdir(path):
            out += item("Folder", entry, walk(path))
        elif entry.endswith(".server.lua"):
            out += script("Script", entry[: -len(".server.lua")], path)
        elif entry.endswith(".client.lua"):
            out += script("LocalScript", entry[: -len(".client.lua")], path)
        elif entry.endswith(".lua"):
            out += script("ModuleScript", entry[: -len(".lua")], path)
    return out


def main():
    body = ""
    body += item("Workspace", "Workspace")
    # Technology 4 = Future. Verify in Studio: Lighting > Technology.
    body += item("Lighting", "Lighting", "", '<token name="Technology">4</token>')
    body += item("ReplicatedFirst", "ReplicatedFirst", walk(os.path.join(SRC, "ReplicatedFirst")))
    body += item("ReplicatedStorage", "ReplicatedStorage", walk(os.path.join(SRC, "ReplicatedStorage")))
    body += item("ServerScriptService", "ServerScriptService", walk(os.path.join(SRC, "ServerScriptService")))
    starter_scripts = item(
        "StarterPlayerScripts",
        "StarterPlayerScripts",
        walk(os.path.join(SRC, "StarterPlayer", "StarterPlayerScripts")),
    )
    body += item("StarterPlayer", "StarterPlayer", starter_scripts)
    body += item("SoundService", "SoundService")
    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write('<roblox version="4">\n' + body + "</roblox>\n")
    print("wrote", OUT, "with", counter, "instances")


if __name__ == "__main__":
    main()
