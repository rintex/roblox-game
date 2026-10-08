"""Check the shipped place against the source project; Studio verifies gameplay."""
from pathlib import Path
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
place = ET.parse(ROOT / 'build/QuarterHeroes.rbxlx').getroot()

def props(item):
    return {p.attrib['name']: p for p in item.find('Properties')}

def name(item):
    return props(item)['Name'].text

def child(item, target):
    return next(i for i in item.findall('Item') if name(i) == target)

workspace = child(place, 'Workspace')
plots = child(workspace, 'TycoonPlots').findall('Item')
assert len(plots) == 6
for plot in plots:
    assert plot.attrib['class'] == 'Model'
    assert child(plot, 'Structure').attrib['class'] == 'Folder'
    for pad, prompt in [('ClaimPad', 'ClaimPrompt'), ('Collector', 'CollectPrompt'),
                        ('UpgradePad', 'FloorPrompt'), ('DropperUpgradePad', 'DropperPrompt'),
                        ('BonusPad', 'BonusPrompt'), ('HeroPad', 'HeroPrompt')]:
        instance = child(child(plot, pad), prompt)
        assert instance.attrib['class'] == 'ProximityPrompt'
        assert props(instance)['Enabled'].text == ('true' if prompt == 'ClaimPrompt' else 'false')
    assert props(child(plot, 'BonusPad'))['Transparency'].text == '1'
    assert float(props(child(plot, 'Base'))['size'].find('X').text) == 66

campus = child(workspace, 'HeroCampus')
for pad, prompt in [('DailyStand', 'ClaimDailyPrompt'), ('QuestStand', 'QuestPrompt'),
                    ('ArenaPortal', 'EnterArenaPrompt'), ('ReturnStand', 'ReturnPrompt'),
                    ('RebirthStand', 'RebirthPrompt')]:
    assert child(child(campus, pad), prompt).attrib['class'] == 'ProximityPrompt'

items = list(place.iter('Item'))
assert sum(i.attrib['class'] == 'SpawnLocation' for i in items) == 1
for item in items:
    if item.attrib['class'] in ('Part', 'SpawnLocation'):
        assert props(item)['Anchored'].text == 'true'
    siblings = [name(c) for c in item.findall('Item')]
    assert len(siblings) == len(set(siblings)), f'Duplicated objects inside {name(item)}'

expected_scripts = 0
expected_remotes = 0
mapped_sources = set()
def check_project(node, instance):
    global expected_scripts, expected_remotes
    if '$path' in node:
        source = node['$path']
        expected_class = 'LocalScript' if source.endswith('.client.luau') else 'Script' if source.endswith('.server.luau') else 'ModuleScript'
        assert instance.attrib['class'] == expected_class
        assert props(instance)['Source'].text == (ROOT / source).read_text(), source
        mapped_sources.add(source)
        expected_scripts += 1
    elif '$className' in node:
        assert instance.attrib['class'] == node['$className']
        if node['$className'] == 'RemoteEvent':
            expected_remotes += 1
    for key, value in node.items():
        if not key.startswith('$'):
            check_project(value, child(instance, key))

project = json.loads((ROOT / 'default.project.json').read_text())
for key, value in project['tree'].items():
    if not key.startswith('$'):
        check_project(value, child(place, key))
assert sum(i.attrib['class'] in ('Script', 'ModuleScript', 'LocalScript') for i in items) == expected_scripts
assert sum(i.attrib['class'] == 'RemoteEvent' for i in items) == expected_remotes
assert mapped_sources == {str(p.relative_to(ROOT)) for p in (ROOT / 'src').rglob('*.luau')}, 'Production source is missing from the place project'
lighting = child(place, 'Lighting')
for effect, kind in [('HeroCityAtmosphere', 'Atmosphere'), ('HeroCityBloom', 'BloomEffect'),
                     ('HeroCityColor', 'ColorCorrectionEffect'), ('HeroCitySky', 'Sky')]:
    assert child(lighting, effect).attrib['class'] == kind
assert sum(i.attrib['class'] in ('Part', 'SpawnLocation') for i in items) <= 900, 'Empty city geometry budget exceeded'
camera = child(workspace, 'Camera')
assert props(workspace)['CurrentCamera'].text == camera.attrib['referent']
assert (ROOT / 'build/QuarterHeroes.rbxl').read_bytes()[:14] == b'<roblox!\x89\xff\r\n\x1a\n'
obby = child(workspace, 'RooftopObby')
assert len(child(obby, 'Platforms').findall('Item')) == 16
assert child(child(obby, 'StartStand'), 'StartObbyPrompt').attrib['class'] == 'ProximityPrompt'
assert any(i.attrib['class'] == 'SurfaceGui' for i in items), 'Costume artwork missing'
for hero in child(campus, 'Gallery').findall('Item'):
    assert props(child(hero, 'Pedestal'))['CanTouch'].text == 'true'
    assert child(child(hero, 'Head'), 'CostumeFace').attrib['class'] == 'SurfaceGui'
    assert child(child(hero, 'Torso'), 'CostumeChest').attrib['class'] == 'SurfaceGui'
print(f'Place validation passed: textured city, sixteen obby stages, six spacious plots, costume surfaces, {expected_scripts} exact sources, {expected_remotes} remotes, HUD and camera.')
