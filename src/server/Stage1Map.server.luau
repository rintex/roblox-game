-- Этап 1: карта и точка появления. Поместите Script в ServerScriptService.
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

-- Повторный запуск использует детали с теми же именами.
local function makePart(name, size, position, color, material)
	local part = map:FindFirstChild(name)
	if part then
		assert(part.ClassName == "Part", name .. " должен быть Part")
	else
		part = Instance.new("Part")
		part.Name = name
		part.Parent = map
	end
	part.Anchored = true
	part.CanCollide = true
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = material
	part.Shape = Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local grass = Color3.fromRGB(105, 167, 100)
local stone = Color3.fromRGB(224, 215, 192)
local wood = Color3.fromRGB(116, 82, 57)

makePart("Ground", Vector3.new(180, 2, 180), Vector3.new(0, -1, 0), grass, Enum.Material.Grass)
makePart("Plaza", Vector3.new(28, 0.3, 28), Vector3.new(0, 0.15, 0), stone, Enum.Material.SmoothPlastic)

-- Дорожки заканчиваются у центральной площади.
makePart("NorthPath", Vector3.new(8, 0.2, 68), Vector3.new(0, 0.1, -48), stone, Enum.Material.SmoothPlastic)
makePart("SouthPath", Vector3.new(8, 0.2, 68), Vector3.new(0, 0.1, 48), stone, Enum.Material.SmoothPlastic)
makePart("WestPath", Vector3.new(68, 0.2, 8), Vector3.new(-48, 0.1, 0), stone, Enum.Material.SmoothPlastic)
makePart("EastPath", Vector3.new(68, 0.2, 8), Vector3.new(48, 0.1, 0), stone, Enum.Material.SmoothPlastic)

-- Низкое ограждение помогает не упасть с края карты.
local borderColor = Color3.fromRGB(151, 169, 133)
makePart("NorthBorder", Vector3.new(180, 4, 2), Vector3.new(0, 2, -89), borderColor, Enum.Material.Slate)
makePart("SouthBorder", Vector3.new(180, 4, 2), Vector3.new(0, 2, 89), borderColor, Enum.Material.Slate)
makePart("WestBorder", Vector3.new(2, 4, 176), Vector3.new(-89, 2, 0), borderColor, Enum.Material.Slate)
makePart("EastBorder", Vector3.new(2, 4, 176), Vector3.new(89, 2, 0), borderColor, Enum.Material.Slate)

local treePositions = {
	Vector3.new(-77, 0, -77), Vector3.new(77, 0, -77),
	Vector3.new(-77, 0, 77), Vector3.new(77, 0, 77),
	Vector3.new(-77, 0, -30), Vector3.new(77, 0, -30),
	Vector3.new(-77, 0, 30), Vector3.new(77, 0, 30),
}

for index, position in ipairs(treePositions) do
	makePart("TreeTrunk" .. index, Vector3.new(2, 8, 2), position + Vector3.new(0, 4, 0), wood, Enum.Material.Wood)
	local leaves = makePart("TreeLeaves" .. index, Vector3.new(12, 12, 12), position + Vector3.new(0, 10, 0), Color3.fromRGB(65, 130 + index * 3, 77), Enum.Material.SmoothPlastic)
	leaves.Shape = Enum.PartType.Ball
	leaves.CanCollide = false
end

local rockPositions = {
	Vector3.new(-77, 1.5, -10), Vector3.new(77, 1.5, -10),
	Vector3.new(-77, 1.5, 10), Vector3.new(77, 1.5, 10),
}

for index, position in ipairs(rockPositions) do
	local rock = makePart("Rock" .. index, Vector3.new(6, 3, 5), position, Color3.fromRGB(144, 153, 152), Enum.Material.Slate)
	rock.Shape = Enum.PartType.Ball
end

-- В шаблоне Baseplate уже есть SpawnLocation: используем его.
local spawns = {}
for _, object in ipairs(Workspace:GetDescendants()) do
	if object:IsA("SpawnLocation") then
		table.insert(spawns, object)
	end
end
assert(#spawns <= 1, "Найдено несколько SpawnLocation. Для этапа 1 оставьте только нужную стартовую точку.")

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
spawn.Color = Color3.fromRGB(111, 210, 181)
spawn.Material = Enum.Material.Neon
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.BottomSurface = Enum.SurfaceType.Smooth
spawn.Parent = map

Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.GlobalShadows = true
Lighting.Ambient = Color3.fromRGB(110, 120, 135)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 155, 160)

map:SetAttribute("MapReady", true)
print("Карта готова: SimulatorMap и точка появления StartSpawn.")
