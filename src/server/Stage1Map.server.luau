-- A spacious campus shared by the six spacious house plots, gallery and arena.
-- All geometry is anchored and uses simple Parts; no asset downloads needed.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Style = require(script.Parent:WaitForChild("Modules"):WaitForChild("VisualStyle"))

local map = Workspace:FindFirstChild("SimulatorMap")
if map then
	assert(map:IsA("Folder"), "SimulatorMap должен быть Folder")
else
	map = Instance.new("Folder")
	map.Name = "SimulatorMap"
	map.Parent = Workspace
end

local function makePart(name, size, position, color, material, canCollide)
	local object = map:FindFirstChild(name)
	if object then
		assert(object.ClassName == "Part", name .. " должен быть Part")
	else
		object = Instance.new("Part")
		object.Name = name
		object.Parent = map
	end
	object.Anchored = true
	object.CanCollide = canCollide ~= false
	object.CanTouch = false
	object.CanQuery = object.CanCollide
	object.Size = size
	object.CFrame = CFrame.new(position)
	object.Color = color
	object.Material = material
	Style.Material(object)
	object.Shape = Enum.PartType.Block
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	return object
end

local grass = Style.Palette.Grass
local paving = Style.Palette.Stone
local cyan = Style.Palette.Mint
local navy = Style.Palette.Ink
local wood = Style.Palette.Wood
local asphalt = Style.Palette.Road

makePart("Ground", Vector3.new(480, 2, 480), Vector3.new(0, -1, 0), grass, Enum.Material.Grass)
makePart("Plaza", Vector3.new(72, 0.3, 72), Vector3.new(0, 0.15, 0), paving, Enum.Material.Concrete)

-- Roads stop at the plaza and continue through the public campus activities.
for _, side in ipairs({ -1, 1 }) do
	local suffix = if side < 0 then "North" else "South"
	makePart(suffix .. "Sidewalk", Vector3.new(20, 0.18, 178), Vector3.new(0, 0.09, side * 125), paving, Enum.Material.Concrete)
	makePart(suffix .. "Path", Vector3.new(12, 0.2, 178), Vector3.new(0, 0.1, side * 125), asphalt, Enum.Material.Asphalt)
	for lane = 1, 8 do
		makePart(suffix .. "Lane" .. lane, Vector3.new(0.22, 0.025, 6), Vector3.new(0, 0.215, side * (46 + lane * 20)), Style.Palette.Paper, Enum.Material.SmoothPlastic, false)
	end
end
makePart("WestPath", Vector3.new(66, 0.2, 12), Vector3.new(-69, 0.1, 0), paving, Enum.Material.Concrete)
makePart("EastPath", Vector3.new(66, 0.2, 12), Vector3.new(69, 0.1, 0), paving, Enum.Material.Concrete)

-- The crosswalks frame the safe plaza without creating a physical obstacle.
for _, side in ipairs({ -1, 1 }) do
	for stripe = 1, 6 do
		makePart("PlazaCrosswalk" .. side .. "_" .. stripe, Vector3.new(9.5, 0.025, 0.9), Vector3.new(0, 0.22, side * (37 + stripe * 1.6)), paving, Enum.Material.SmoothPlastic, false)
	end
end

for _, side in ipairs({ -1, 1 }) do
	local suffix = if side < 0 then "West" else "East"
	makePart("PlazaTrim" .. suffix, Vector3.new(0.45, 0.05, 72), Vector3.new(side * 35.5, 0.325, 0), cyan, Enum.Material.Neon, false)
	makePart("PlazaTrim" .. (if side < 0 then "North" else "South"), Vector3.new(72, 0.05, 0.45), Vector3.new(0, 0.325, side * 35.5), cyan, Enum.Material.Neon, false)
end

local rows = { -156, 0, 156 }
for rowIndex, rowZ in ipairs(rows) do
	for _, side in ipairs({ -1, 1 }) do
		local suffix = (if side < 0 then "West" else "East") .. rowIndex
		makePart("HouseSidewalk" .. suffix, Vector3.new(148, 0.18, 16), Vector3.new(side * 74, 0.09, rowZ - 39), paving, Enum.Material.Concrete)
		makePart("HouseRoad" .. suffix, Vector3.new(148, 0.2, 8), Vector3.new(side * 74, 0.1, rowZ - 39), asphalt, Enum.Material.Asphalt)
		makePart("HouseEntry" .. suffix, Vector3.new(12, 0.2, 9), Vector3.new(side * 148, 0.1, rowZ - 33), paving, Enum.Material.Concrete)
		for stripe = 1, 6 do
			makePart("RoadMark" .. suffix .. stripe, Vector3.new(8, 0.025, 0.2), Vector3.new(side * (14 + stripe * 19), 0.215, rowZ - 39), Style.Palette.Paper, Enum.Material.SmoothPlastic, false)
		end
		for _, edge in ipairs({ -1, 1 }) do
			makePart("RoadCurb" .. suffix .. edge, Vector3.new(142, 0.24, 0.35), Vector3.new(side * 77, 0.17, rowZ - 39 + edge * 4.35), paving, Enum.Material.Concrete, false)
		end
		makePart("RoadLamp" .. suffix, Vector3.new(0.65, 8, 0.65), Vector3.new(side * 110, 4, rowZ - 45), navy, Enum.Material.Metal)
		local glow = makePart("RoadLampGlow" .. suffix, Vector3.new(1.6, 1.6, 1.6), Vector3.new(side * 110, 8.2, rowZ - 45), cyan, Enum.Material.Neon, false)
		glow.Shape = Enum.PartType.Ball
		local sign = makePart("BlockSign" .. suffix, Vector3.new(7, 2, 0.3), Vector3.new(side * 110, 6.1, rowZ - 45.6), navy, Enum.Material.Metal, false)
		Style.Sign(sign, "КВАРТАЛ " .. rowIndex, "ДОМА " .. (rowIndex * 2 - 1) .. "–" .. rowIndex * 2, cyan)
	end
end

-- Low walls mark the edge without obstructing any plot or public walkway.
local border = Color3.fromRGB(109, 132, 139)
makePart("NorthBorder", Vector3.new(480, 5, 2), Vector3.new(0, 2.5, -239), border, Enum.Material.Slate)
makePart("SouthBorder", Vector3.new(480, 5, 2), Vector3.new(0, 2.5, 239), border, Enum.Material.Slate)
makePart("WestBorder", Vector3.new(2, 5, 476), Vector3.new(-239, 2.5, 0), border, Enum.Material.Slate)
makePart("EastBorder", Vector3.new(2, 5, 476), Vector3.new(239, 2.5, 0), border, Enum.Material.Slate)

local treePositions = {}
for _, side in ipairs({ -1, 1 }) do
	for _, z in ipairs({ -210, -140, -70, 0, 70, 140, 210 }) do
		table.insert(treePositions, Vector3.new(side * 215, 0, z))
	end
	for _, x in ipairs({ -150, -80, 80, 150 }) do
		table.insert(treePositions, Vector3.new(x, 0, side * 218))
	end
end
for index, position in ipairs(treePositions) do
	makePart("TreeTrunk" .. index, Vector3.new(2.5, 10, 2.5), position + Vector3.new(0, 5, 0), wood, Enum.Material.Wood)
	local leaves = makePart("TreeLeaves" .. index, Vector3.new(15, 15, 15), position + Vector3.new(0, 13, 0), Color3.fromRGB(56, 119 + index % 5 * 8, 91), Enum.Material.SmoothPlastic, false)
	leaves.Shape = Enum.PartType.Ball
	local crown = makePart("TreeCrown" .. index, Vector3.new(9, 8, 9), position + Vector3.new(0, 19, 0), Color3.fromRGB(75, 143 + index % 3 * 6, 106), Enum.Material.SmoothPlastic, false)
	crown.Shape = Enum.PartType.Ball
end

-- A compact plaza medallion makes the spawn recognizable from any approach.
makePart("SpawnFoundation", Vector3.new(12, 0.2, 12), Vector3.new(0, 0.4, 6), navy, Enum.Material.Slate)
for _, side in ipairs({ -1, 1 }) do
	makePart("SpawnTrimX" .. side, Vector3.new(0.2, 0.06, 11), Vector3.new(side * 5.2, 0.55, 6), cyan, Enum.Material.Neon, false)
	makePart("SpawnTrimZ" .. side, Vector3.new(11, 0.06, 0.2), Vector3.new(0, 0.55, 6 + side * 5.2), cyan, Enum.Material.Neon, false)
end
for index, position in ipairs({ Vector3.new(-9, 0, 12), Vector3.new(9, 0, 12) }) do
	makePart("SpawnPlanter" .. index, Vector3.new(3, 0.9, 3), position + Vector3.new(0, 0.6, 0), paving, Enum.Material.Concrete)
	local shrub = makePart("SpawnShrub" .. index, Vector3.new(2.8, 2, 2.8), position + Vector3.new(0, 1.5, 0), grass, Enum.Material.Grass, false)
	shrub.Shape = Enum.PartType.Ball
end

for index, position in ipairs({
	Vector3.new(-214, 2, -105), Vector3.new(214, 2, -105),
	Vector3.new(-214, 2, 105), Vector3.new(214, 2, 105),
	Vector3.new(-110, 2, -220), Vector3.new(110, 2, -220),
	Vector3.new(-110, 2, 220), Vector3.new(110, 2, 220),
}) do
	local rock = makePart("Rock" .. index, Vector3.new(9, 4, 7), position, Color3.fromRGB(127, 145, 158), Enum.Material.Slate)
	rock.Shape = Enum.PartType.Ball
end

for index, position in ipairs({
	Vector3.new(-32, 0, -32), Vector3.new(32, 0, -32),
	Vector3.new(-32, 0, 32), Vector3.new(32, 0, 32),
}) do
	makePart("PlazaLamp" .. index, Vector3.new(0.8, 10, 0.8), position + Vector3.new(0, 5.3, 0), navy, Enum.Material.Metal)
	makePart("PlazaLampCap" .. index, Vector3.new(2.5, 0.5, 2.5), position + Vector3.new(0, 10.5, 0), cyan, Enum.Material.Neon, false)
end

-- A small park landmark stays outside roads, plot entrances and arena bounds.
-- Water is static, translucent geometry; no server loop or particle workload.
local fountainOrigin = Vector3.new(-75, 0, -72)
makePart("ParkFountainBase", Vector3.new(12, 0.45, 10), fountainOrigin + Vector3.new(0, 0.25, 0), paving, Enum.Material.Cobblestone)
for _, side in ipairs({ -1, 1 }) do
	makePart("ParkFountainRimX" .. side, Vector3.new(0.65, 0.9, 9), fountainOrigin + Vector3.new(side * 5.1, 0.9, 0), paving, Enum.Material.Concrete)
	makePart("ParkFountainRimZ" .. side, Vector3.new(10.8, 0.9, 0.65), fountainOrigin + Vector3.new(0, 0.9, side * 4.2), paving, Enum.Material.Concrete)
end
local parkWater = makePart("ParkFountainWater", Vector3.new(9.5, 0.12, 7.6), fountainOrigin + Vector3.new(0, 0.95, 0), Style.Palette.Window, Enum.Material.Glass, false)
parkWater.Transparency = 0.35
makePart("ParkFountainSpout", Vector3.new(1, 2.3, 1), fountainOrigin + Vector3.new(0, 1.65, 0), paving, Enum.Material.Slate, false)
local parkJet = makePart("ParkFountainJet", Vector3.new(0.35, 1.8, 0.35), fountainOrigin + Vector3.new(0, 3.2, 0), cyan, Enum.Material.Glass, false)
parkJet.Transparency = 0.52
local parkSplash = makePart("ParkFountainSplash", Vector3.new(2.4, 0.28, 2.4), fountainOrigin + Vector3.new(0, 2.65, 0), Style.Palette.Window, Enum.Material.Glass, false)
parkSplash.Shape = Enum.PartType.Ball
parkSplash.Transparency = 0.6

-- Reuse an existing singleton spawn. Duplicate spawns require a deliberate
-- Studio decision, rather than silently moving or deleting someone else's.
local spawns = {}
for _, object in ipairs(Workspace:GetDescendants()) do
	if object:IsA("SpawnLocation") then
		table.insert(spawns, object)
	end
end
assert(#spawns <= 1, "Найдено несколько SpawnLocation. Оставьте одну стартовую точку.")
local spawn = spawns[1] or Instance.new("SpawnLocation")
spawn.Name = "StartSpawn"
spawn.Size = Vector3.new(7, 0.8, 7)
spawn.CFrame = CFrame.new(0, 0.7, 6)
spawn.Anchored = true
spawn.CanCollide = true
spawn.Neutral = true
spawn.Enabled = true
spawn.AllowTeamChangeOnTouch = false
spawn.Duration = 0
spawn.Color = cyan
spawn.Material = Enum.Material.SmoothPlastic
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.BottomSurface = Enum.SurfaceType.Smooth
spawn.Parent = map

Lighting.ClockTime = 14
Lighting.Brightness = 2.35
Lighting.GlobalShadows = true
Lighting.Ambient = Color3.fromRGB(118, 123, 135)
Lighting.OutdoorAmbient = Color3.fromRGB(163, 171, 177)

-- Soft daylight and restrained neon bloom keep the city bright and readable.
local function lightingEffect(name, className)
	local effect = Lighting:FindFirstChild(name)
	if effect then
		assert(effect:IsA(className), name .. " имеет неверный тип")
	else
		effect = Instance.new(className)
		effect.Name = name
		effect.Parent = Lighting
	end
	return effect
end
local sky = lightingEffect("HeroCitySky", "Sky")
-- These six textures ship with the Roblox client; no uploaded asset IDs.
sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
sky.CelestialBodiesShown = true
sky.StarCount = 750
sky.SunAngularSize = 14
sky.MoonAngularSize = 9
local atmosphere = lightingEffect("HeroCityAtmosphere", "Atmosphere")
atmosphere.Density = 0.18
atmosphere.Offset = 0.05
atmosphere.Color = Color3.fromRGB(188, 214, 238)
atmosphere.Decay = Color3.fromRGB(107, 123, 151)
atmosphere.Glare = 0.1
atmosphere.Haze = 0.6
local bloom = lightingEffect("HeroCityBloom", "BloomEffect")
bloom.Intensity = 0.18
bloom.Size = 24
bloom.Threshold = 2
local color = lightingEffect("HeroCityColor", "ColorCorrectionEffect")
color.Brightness = 0.01
color.Contrast = 0.03
color.Saturation = 0.1
color.TintColor = Color3.fromRGB(255, 250, 242)

map:SetAttribute("MapReady", true)
print("Кампус готов: большая карта, площадь, дороги к шести домам и StartSpawn.")
