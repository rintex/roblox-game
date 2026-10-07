"""Check packaged services, scripts and geometry; Roblox Studio runs gameplay."""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
place = ET.parse(ROOT / 'build/HouseTycoon.rbxlx').getroot()

def props(item):
    return {p.attrib['name']: p for p in item.find('Properties')}

def name(item):
    return props(item)['Name'].text

def child(item, target):
    return next(i for i in item.findall('Item') if name(i) == target)

workspace = child(place, 'Workspace')
plots = child(workspace, 'TycoonPlots').findall('Item')
assert len(plots) == 4
for plot in plots:
    assert plot.attrib['class'] == 'Model'
    assert child(plot, 'Structure').attrib['class'] == 'Folder'
    for pad, prompt in [('ClaimPad', 'ClaimPrompt'), ('Collector', 'CollectPrompt'),
                        ('UpgradePad', 'FloorPrompt'), ('DropperUpgradePad', 'DropperPrompt'),
                        ('BonusPad', 'BonusPrompt')]:
        instance = child(child(plot, pad), prompt)
        assert instance.attrib['class'] == 'ProximityPrompt'
        assert props(instance)['Enabled'].text == ('true' if prompt == 'ClaimPrompt' else 'false')
    # The third-floor bonus is hidden before a house is built.
    assert props(child(plot, 'BonusPad'))['Transparency'].text == '1'

items = list(place.iter('Item'))
assert sum(i.attrib['class'] == 'SpawnLocation' for i in items) == 1
for item in items:
    if item.attrib['class'] in ('Part', 'SpawnLocation'):
        assert props(item)['Anchored'].text == 'true'
    siblings = [name(c) for c in item.findall('Item')]
    assert len(siblings) == len(set(siblings)), f'Duplicated objects inside {name(item)}'

server = child(place, 'ServerScriptService')
storage = child(place, 'ReplicatedStorage')
starter = child(child(place, 'StarterPlayer'), 'StarterPlayerScripts')
expected = [
    (child(server, 'Stage1Map'), 'Script', 'src/server/Stage1Map.server.luau'),
    (child(server, 'TycoonServer'), 'Script', 'src/server/TycoonServer.server.luau'),
    (child(child(storage, 'Shared'), 'TycoonConfig'), 'ModuleScript', 'src/shared/TycoonConfig.luau'),
]
for module in ('HouseWorld', 'TycoonService', 'ProfileService', 'ProfileSchema'):
    expected.append((child(child(server, 'Modules'), module), 'ModuleScript', f'src/server/Modules/{module}.luau'))
for client in ('TycoonUI', 'DropperEffects'):
    expected.append((child(starter, client), 'LocalScript', f'src/client/{client}.client.luau'))
for instance, class_name, source in expected:
    assert instance.attrib['class'] == class_name
    assert props(instance)['Source'].text == (ROOT / source).read_text()
assert sum(i.attrib['class'] in ('Script', 'ModuleScript', 'LocalScript') for i in items) == len(expected)
assert child(child(storage, 'TycoonRemotes'), 'Notice').attrib['class'] == 'RemoteEvent'
assert sum(i.attrib['class'] == 'RemoteEvent' for i in items) == 1
assert child(child(place, 'StarterGui'), 'TycoonHUD').attrib['class'] == 'ScreenGui'
camera = child(workspace, 'Camera')
assert props(workspace)['CurrentCamera'].text == camera.attrib['referent']
assert (ROOT / 'build/HouseTycoon.rbxl').read_bytes()[:14] == b'<roblox!\x89\xff\r\n\x1a\n'
print('Place validation passed: four plots, one spawn, 9 matching scripts in correct services, prompts, HUD, and camera.')
