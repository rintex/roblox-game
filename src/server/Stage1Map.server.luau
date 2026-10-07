-- A spacious campus shared by the twelve house plots, gallery and arena.
-- All geometry is anchored and uses simple Parts; no asset downloads needed.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

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
	object.Size = size
	object.CFrame = CFrame.new(position)
	object.Color = color
	object.Material = material
	object.Shape = Enum.PartType.Block
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	return object
end

local grass = Color3.fromRGB(88, 144, 112)
local paving = Color3.fromRGB(219, 230, 237)
local cyan = Color3.fromRGB(85, 218, 224)
local navy = Color3.fromRGB(46, 65, 89)
local wood = Color3.fromRGB(123, 88, 62)

makePart("Ground", Vector3.new(480, 2, 480), Vector3.new(0, -1, 0), grass, Enum.Material.Grass)
makePart("Plaza", Vector3.new(72, 0.3, 72), Vector3.new(0, 0.15, 0), paving, Enum.Material.Concrete)

-- Roads stop at the plaza and continue through the public campus activities.
makePart("NorthPath", Vector3.new(12, 0.2, 178), Vector3.new(0, 0.1, -125), paving, Enum.Material.Concrete)
makePart("SouthPath", Vector3.new(12, 0.2, 178), Vector3.new(0, 0.1, 125), paving, Enum.Material.Concrete)
makePart("WestPath", Vector3.new(178, 0.2, 12), Vector3.new(-125, 0.1, 0), paving, Enum.Material.Concrete)
makePart("EastPath", Vector3.new(178, 0.2, 12), Vector3.new(125, 0.1, 0), paving, Enum.Material.Concrete)

for _, side in ipairs({ -1, 1 }) do
	local suffix = if side < 0 then "West" else "East"
	makePart("PlazaTrim" .. suffix, Vector3.new(0.45, 0.05, 72), Vector3.new(side * 35.5, 0.325, 0), cyan, Enum.Material.Neon, false)
	makePart("PlazaTrim" .. (if side < 0 then "North" else "South"), Vector3.new(72, 0.05, 0.45), Vector3.new(0, 0.325, side * 35.5), cyan, Enum.Material.Neon, false)
end

local rows = { -170, -102, -34, 34, 102, 170 }
for rowIndex, rowZ in ipairs(rows) do
	for _, side in ipairs({ -1, 1 }) do
		local suffix = (if side < 0 then "West" else "East") .. rowIndex
		makePart("HouseRoad" .. suffix, Vector3.new(148, 0.2, 6), Vector3.new(side * 74, 0.1, rowZ - 25), paving, Enum.Material.Concrete)
		makePart("HouseEntry" .. suffix, Vector3.new(8, 0.2, 6), Vector3.new(side * 148, 0.1, rowZ - 22), paving, Enum.Material.Concrete)
		makePart("RoadLamp" .. suffix, Vector3.new(0.65, 8, 0.65), Vector3.new(side * 110, 4, rowZ - 31), navy, Enum.Material.Metal)
		local glow = makePart("RoadLampGlow" .. suffix, Vector3.new(1.6, 1.6, 1.6), Vector3.new(side * 110, 8.2, rowZ - 31), cyan, Enum.Material.Neon, false)
		glow.Shape = Enum.PartType.Ball
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
spawn.Color = Color3.fromRGB(104, 223, 194)
spawn.Material = Enum.Material.Neon
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.BottomSurface = Enum.SurfaceType.Smooth
spawn.Parent = map

Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.GlobalShadows = true
Lighting.Ambient = Color3.fromRGB(110, 120, 139)
Lighting.OutdoorAmbient = Color3.fromRGB(151, 164, 177)

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
local atmosphere = lightingEffect("HeroCityAtmosphere", "Atmosphere")
atmosphere.Density = 0.2
atmosphere.Offset = 0.05
atmosphere.Color = Color3.fromRGB(188, 214, 238)
atmosphere.Decay = Color3.fromRGB(107, 123, 151)
atmosphere.Glare = 0.1
atmosphere.Haze = 0.6
local bloom = lightingEffect("HeroCityBloom", "BloomEffect")
bloom.Intensity = 0.25
bloom.Size = 24
bloom.Threshold = 2
local color = lightingEffect("HeroCityColor", "ColorCorrectionEffect")
color.Brightness = 0.01
color.Contrast = 0.03
color.Saturation = 0.1
color.TintColor = Color3.fromRGB(255, 250, 242)

map:SetAttribute("MapReady", true)
print("Кампус готов: большая карта, площадь, дороги к 12 домам и StartSpawn.")
