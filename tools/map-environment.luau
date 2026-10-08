-- Build-only object model: geometry/serialization, not Roblox physics or gameplay.
local registry = {}
local methods = {}
function methods:IsA(class)
 return self.ClassName == class
  or (class == 'BasePart' and (self.ClassName == 'Part' or self.ClassName == 'SpawnLocation'))
  or (class == 'Part' and self.ClassName == 'SpawnLocation')
end
function methods:GetChildren()
 local result = {}
 for _, object in ipairs(registry) do
  if not object._destroyed and object.Parent == self then table.insert(result, object) end
 end
 return result
end
function methods:FindFirstChild(name)
 for _, object in ipairs(self:GetChildren()) do if object.Name == name then return object end end
 return nil
end
function methods:GetDescendants()
 local result = {}
 for _, child in ipairs(self:GetChildren()) do
  table.insert(result, child)
  for _, descendant in ipairs(child:GetDescendants()) do table.insert(result, descendant) end
 end
 return result
end
function methods:Destroy()
 for _, child in ipairs(self:GetChildren()) do child:Destroy() end
 self.Parent = nil
 self._destroyed = true
end
function methods:SetAttribute(name, value) self._attributes[name] = value end
function methods:GetAttribute(name) return self._attributes[name] end
local instanceMeta = { __index = function(object, name)
 if name == 'Position' and object.CFrame then return object.CFrame.Position end
 return methods[name]
end }
local Instance = {}
local allowed = { Workspace=true, Lighting=true, Folder=true, Model=true, Part=true, SpawnLocation=true,
 ProximityPrompt=true, BillboardGui=true, TextLabel=true, Atmosphere=true, BloomEffect=true, ColorCorrectionEffect=true,
 SurfaceGui=true, Frame=true, UICorner=true, Sky=true }
function Instance.new(class)
 assert(allowed[class], 'Unsupported build class: ' .. class)
 local object = setmetatable({ClassName=class, _attributes={}}, instanceMeta)
 table.insert(registry, object)
 return object
end
local Vector3 = {}
local vectorMeta = {
 __add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end,
 __sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end,
 __index=function(a,key) if key=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end,
}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
local CFrame = {}
function CFrame.new(x,y,z) return {Position=if type(x)=='table' then x else Vector3.new(x,y,z)} end
local Color3 = {}
function Color3.fromRGB(r,g,b) return {R=r/255,G=g/255,B=b/255} end
local UDim2 = {new=function(xs,xo,ys,yo) return {xs,xo,ys,yo} end}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local UDim={new=function(scale,offset) return {Scale=scale,Offset=offset} end}
local Enum = {
 PartType={Block='Block',Ball='Ball'}, SurfaceType={Smooth='Smooth'},
 Material={Grass='Grass',SmoothPlastic='SmoothPlastic',Slate='Slate',Wood='Wood',WoodPlanks='WoodPlanks',Concrete='Concrete',Glass='Glass',Metal='Metal',Neon='Neon',Brick='Brick',Asphalt='Asphalt',Cobblestone='Cobblestone',DiamondPlate='DiamondPlate',Fabric='Fabric'},
 KeyCode={E='E'}, Font={GothamBold='GothamBold'},
 NormalId={Front='Front',Back='Back'},SurfaceGuiSizingMode={FixedSize='FixedSize'},
 ZIndexBehavior={Sibling='Sibling'},
}
local Workspace = Instance.new('Workspace')
local Lighting = Instance.new('Lighting')
local game = {GetService=function(_,name)
 assert(name=='Workspace' or name=='Lighting', 'Unsupported build service: ' .. name)
 return if name=='Workspace' then Workspace else Lighting
end}
local function print() end
local vectorProperties = { Size=true, StudsOffset=true }
local colorProperties = { Color=true, BackgroundColor3=true, TextColor3=true, Ambient=true, OutdoorAmbient=true, Decay=true, TintColor=true }
local commonProperties = {
 'Anchored', 'CanCollide', 'CanTouch', 'CanQuery', 'Transparency', 'Material', 'Shape', 'TopSurface', 'BottomSurface',
 'Neutral', 'Enabled', 'AllowTeamChangeOnTouch', 'Duration', 'ActionText', 'ObjectText', 'MaxActivationDistance',
 'RequiresLineOfSight', 'HoldDuration', 'KeyboardKeyCode', 'AlwaysOnTop', 'MaxDistance', 'BackgroundTransparency',
 'BorderSizePixel', 'Font', 'TextScaled', 'TextWrapped', 'Text', 'Size', 'StudsOffset', 'Color', 'CFrame',
 'BackgroundColor3', 'TextColor3',
 'Brightness', 'GlobalShadows', 'Ambient', 'OutdoorAmbient', 'Density', 'Offset', 'Decay', 'Glare', 'Haze',
 'Intensity', 'Threshold', 'Contrast', 'Saturation', 'TintColor',
 'Face', 'SizingMode', 'CanvasSize', 'LightInfluence', 'Position', 'AnchorPoint', 'Rotation', 'ClipsDescendants', 'CornerRadius',
 'ZIndex', 'ZIndexBehavior',
 'SkyboxBk', 'SkyboxDn', 'SkyboxFt', 'SkyboxLf', 'SkyboxRt', 'SkyboxUp',
 'CelestialBodiesShown', 'StarCount', 'SunAngularSize', 'MoonAngularSize',
}
local function encode(object)
 local tree = { ['$className']=object.ClassName }
 local properties = {}
 for _, key in ipairs(commonProperties) do
  local value = object[key]
  if value ~= nil then
   if key=='CFrame' then
    local p=value.Position
    value={p.X,p.Y,p.Z,1,0,0,0,1,0,0,0,1}
   elseif key=='CanvasSize' or key=='AnchorPoint' then value={value.X,value.Y}
   elseif key=='CornerRadius' then value={UDim={value.Scale,value.Offset}}
   elseif key=='Position' then
    value=if value.X==nil then {UDim2={{value[1],value[2]},{value[3],value[4]}}} else nil
   elseif colorProperties[key] then value={value.R,value.G,value.B}
   elseif vectorProperties[key] and type(value)=='table' and value.X ~= nil then value={value.X,value.Y,value.Z}
   elseif key=='Size' and type(value)=='table' then value={UDim2={{value[1],value[2]},{value[3],value[4]}}} end
   properties[key]=value
  end
 end
 if next(properties) then tree['$properties']=properties end
 if next(object._attributes) then tree['$attributes']=object._attributes end
 for _, child in ipairs(object:GetChildren()) do
  assert(tree[child.Name]==nil, 'Duplicate generated name: ' .. child.Name)
  tree[child.Name]=encode(child)
 end
 return tree
end
local function exportMap()
 local map=Workspace:FindFirstChild('SimulatorMap')
 assert(map and map:GetAttribute('MapReady'), 'Map not ready')
 local spawnCount=0
 for _, object in ipairs(Workspace:GetDescendants()) do
  if object:IsA('BasePart') then
   assert(object.Anchored, 'Unanchored generated part')
   assert(object.Size.X>0 and object.Size.Y>0 and object.Size.Z>0, 'Invalid geometry')
  end
  if object:IsA('SpawnLocation') then spawnCount+=1 end
 end
 assert(spawnCount==1, 'Expected one start spawn')
 local lightingTree=encode(Lighting)
 lightingTree['$properties'].TimeOfDay='14:00:00'
 return {
  Workspace=encode(Workspace),
  Lighting=lightingTree,
 }
end
