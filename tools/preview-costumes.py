"""Export the shipped SurfaceGui drawings as SVG; this is not a Studio screenshot."""
from pathlib import Path
import html
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parent.parent
place=ET.parse(ROOT/'build/QuarterHeroes.rbxlx').getroot()
def props(item): return {p.attrib['name']:p for p in item.find('Properties')}
def name(item): return props(item)['Name'].text
def child(item,value): return next(c for c in item.findall('Item') if name(c)==value)
def color(p):
 return '#'+''.join(f'{round(float(p.find(v).text)*255):02x}' for v in ('R','G','B'))
def shapes(root):
 p=props(root)
 result=[f'<rect width="256" height="256" fill="{color(p["BackgroundColor3"])}"/>']
 for item in sorted(root.findall('Item'),key=lambda i:float(props(i).get('ZIndex',ET.fromstring('<v>1</v>')).text)):
  if item.attrib['class']!='Frame': continue
  p=props(item);pos=p['Position'];size=p['Size'];x=float(pos.find('XO').text);y=float(pos.find('YO').text)
  width=float(size.find('XO').text);height=float(size.find('YO').text);rotation=float(p.get('Rotation',ET.fromstring('<v>0</v>')).text)
  radius='128' if any(c.attrib['class']=='UICorner' for c in item.findall('Item')) else '0'
  result.append(f'<rect x="{x-width/2}" y="{y-height/2}" width="{width}" height="{height}" rx="{radius}" fill="{color(p["BackgroundColor3"])}" transform="rotate({rotation} {x} {y})"/>')
 return '\n'.join(result)
workspace=child(place,'Workspace');gallery=child(child(workspace,'HeroCampus'),'Gallery')
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1140" height="740" viewBox="0 0 1140 740">',
 '<rect width="1140" height="740" fill="#141d2d"/>',
 '<text x="32" y="43" fill="#f4d37b" font-family="sans-serif" font-size="28">Герои квартала · рисунки костюмов</text>',
 '<text x="32" y="71" fill="#b4c4d5" font-family="sans-serif" font-size="15">Поверхности из готового файла. Это предпросмотр рисунков, не снимок Roblox Studio.</text>',
 '<defs><clipPath id="tile"><rect width="256" height="256"/></clipPath></defs>']
for index in range(1,7):
 hero=child(gallery,'Hero'+str(index));x=24+(index-1)%3*372;y=94+(index-1)//3*320
 title=child(child(child(hero,'Pedestal'),'HeroLabel'),'TextLabel')
 text=props(title)['Text'].text.split('\n')[0]
 svg.append(f'<rect x="{x}" y="{y}" width="348" height="299" rx="18" fill="#263449"/>')
 svg.append(f'<text x="{x+16}" y="{y+33}" fill="#f0f5fc" font-family="sans-serif" font-size="16">{html.escape(text)}</text>')
 for offset,partname,surface in [(18,'Head','CostumeFace'),(184,'Torso','CostumeChest')]:
  root=child(child(child(hero,partname),surface),'Canvas')
  svg.append(f'<g transform="translate({x+offset} {y+77}) scale(0.58)"><g clip-path="url(#tile)">{shapes(root)}</g></g>')
 svg.append(f'<text x="{x+58}" y="{y+263}" fill="#a6bbd2" font-family="sans-serif" font-size="14">Маска</text>')
 svg.append(f'<text x="{x+212}" y="{y+263}" fill="#a6bbd2" font-family="sans-serif" font-size="14">Костюм</text>')
svg.append('</svg>')
(ROOT/'build/CostumeSurfaces.svg').write_text('\n'.join(svg))
print('Generated build/CostumeSurfaces.svg from the shipped costume artwork.')
