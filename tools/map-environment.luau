-- Build-only support for the small Roblox API subset used by Stage1Map.
-- This is not a Roblox physics, networking, rendering, or Studio simulator.
-- The builder runs the real map script here to avoid maintaining two maps.
local registry = {}
local methods = {}

function methods:IsA(className)
	return self.ClassName == className
		or (className == "Part" and self.ClassName == "SpawnLocation")
		or (className == "BasePart" and (self.ClassName == "Part" or self.ClassName == "SpawnLocation"))
end

function methods:FindFirstChild(name)
	for _, object in ipairs(registry) do
		if object.Parent == self and object.Name == name then
			return object
		end
	end
	return nil
end

function methods:GetDescendants()
	local result = {}
	for _, object in ipairs(registry) do
		local parent = object.Parent
		while parent do
			if parent == self then
				table.insert(result, object)
				break
			end
			parent = parent.Parent
		end
	end
	return result
end

local Instance = {}
function Instance.new(className)
	assert(
		className == "Workspace" or className == "Folder"
			or className == "Part" or className == "SpawnLocation",
		"Unsupported class in build environment: " .. className
	)
	local object = setmetatable({ ClassName = className }, { __index = methods })
	table.insert(registry, object)
	return object
end

local Vector3 = {}
local vectorMeta = {
	__add = function(a, b)
		return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end,
}
function Vector3.new(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
end

local CFrame = {}
function CFrame.new(x, y, z)
	return { Position = if type(x) == "table" then x else Vector3.new(x, y, z) }
end

local Color3 = {}
function Color3.fromRGB(red, green, blue)
	return { R = red / 255, G = green / 255, B = blue / 255 }
end

local Enum = {
	PartType = { Block = "Block", Ball = "Ball" },
	SurfaceType = { Smooth = "Smooth" },
	Material = {
		Grass = "Grass", SmoothPlastic = "SmoothPlastic", Slate = "Slate",
		Wood = "Wood", Neon = "Neon",
	},
}
local Workspace = Instance.new("Workspace")
local Lighting = {}
local game = {}
function game:GetService(name)
	assert(name == "Workspace" or name == "Lighting", "Unsupported service: " .. name)
	return if name == "Workspace" then Workspace else Lighting
end

-- Keep build output concise; the real Script keeps its print in Studio.
local function print() end

local function vectorArray(vector)
	return { vector.X, vector.Y, vector.Z }
end

local function encodePart(part)
	local position = part.CFrame.Position
	local properties = {
		Anchored = part.Anchored,
		CanCollide = part.CanCollide,
		Size = vectorArray(part.Size),
		CFrame = { position.X, position.Y, position.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		Color = { part.Color.R, part.Color.G, part.Color.B },
		Material = part.Material,
		Shape = part.Shape,
		TopSurface = part.TopSurface,
		BottomSurface = part.BottomSurface,
	}
	if part.ClassName == "SpawnLocation" then
		properties.Neutral = part.Neutral
		properties.Enabled = part.Enabled
		properties.AllowTeamChangeOnTouch = part.AllowTeamChangeOnTouch
		properties.Duration = part.Duration
	end
	return { ["$className"] = part.ClassName, ["$properties"] = properties }
end

local function exportMap()
	local map = Workspace:FindFirstChild("SimulatorMap")
	assert(map and map:IsA("Folder"), "Expected Workspace.SimulatorMap")
	local mapTree = { ["$className"] = "Folder" }
	local partCount = 0
	local spawnCount = 0
	for _, part in ipairs(map:GetDescendants()) do
		assert(part.Parent == map, "Stage 1 geometry must be direct children of SimulatorMap")
		assert(part:IsA("BasePart"), "Unexpected map object: " .. part.Name)
		assert(part.Anchored, "Map part must be anchored: " .. part.Name)
		assert(part.Size.X > 0 and part.Size.Y > 0 and part.Size.Z > 0, "Invalid part size")
		assert(mapTree[part.Name] == nil, "Duplicate map object name: " .. part.Name)
		if part.ClassName == "SpawnLocation" then
			spawnCount += 1
			assert(part.Name == "StartSpawn" and part.Enabled and part.Neutral, "Invalid spawn")
		else
			partCount += 1
		end
		mapTree[part.Name] = encodePart(part)
	end
	assert(partCount == 30 and spawnCount == 1, "Expected 30 map Parts and one SpawnLocation")
	local spawn = map:FindFirstChild("StartSpawn")
	local plaza = map:FindFirstChild("Plaza")
	local spawnBottom = spawn.CFrame.Position.Y - spawn.Size.Y / 2
	local plazaTop = plaza.CFrame.Position.Y + plaza.Size.Y / 2
	assert(math.abs(spawnBottom - plazaTop) < 0.0001, "Spawn must rest on the plaza")
	local time = Lighting.ClockTime
	assert(time == 14, "Expected the Stage 1 daylight setting")
	return {
		Workspace = { ["$className"] = "Workspace", SimulatorMap = mapTree },
		Lighting = {
			["$className"] = "Lighting",
			["$properties"] = {
				-- ClockTime does not serialize. TimeOfDay is its saved equivalent.
				TimeOfDay = "14:00:00",
				Brightness = Lighting.Brightness,
				GlobalShadows = Lighting.GlobalShadows,
				Ambient = { Lighting.Ambient.R, Lighting.Ambient.G, Lighting.Ambient.B },
				OutdoorAmbient = { Lighting.OutdoorAmbient.R, Lighting.OutdoorAmbient.G, Lighting.OutdoorAmbient.B },
			},
		},
	}
end
