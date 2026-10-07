-- Physical tycoon plots. This module only draws the world; the server owns money
-- and all purchase decisions. Rebuilding Structure never deletes a prompt.
local World = {}
local Style = require(script.Parent:WaitForChild("VisualStyle"))

local DEFAULT_POSITIONS = {
	Vector3.new(-148, 0, -156), Vector3.new(148, 0, -156),
	Vector3.new(-148, 0, 0), Vector3.new(148, 0, 0),
	Vector3.new(-148, 0, 156), Vector3.new(148, 0, 156),
}

local HOUSE_COLORS = {
	Color3.fromRGB(174, 216, 213),
	Color3.fromRGB(190, 205, 233),
	Color3.fromRGB(229, 193, 178),
	Color3.fromRGB(212, 206, 233),
}

local CREAM = Color3.fromRGB(247, 238, 216)
local WOOD = Color3.fromRGB(151, 115, 83)
local DARK = Color3.fromRGB(56, 77, 94)
local GOLD = Color3.fromRGB(255, 199, 66)
local CYAN = Color3.fromRGB(77, 221, 218)

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA(className), name .. " has the wrong object type")
		return existing
	end
	local object = Instance.new(className)
	object.Name = name
	object.Parent = parent
	return object
end

local function geometry(parent, size, position)
	local plot = parent
	while plot and plot:GetAttribute("GeometryScale") == nil do plot = plot.Parent end
	if not plot then return size, position end
	local scale = plot:GetAttribute("GeometryScale")
	local origin = Vector3.new(plot:GetAttribute("OriginX"), 0, plot:GetAttribute("OriginZ"))
	local offset = position - origin
	return Vector3.new(size.X * scale, size.Y, size.Z * scale), origin + Vector3.new(offset.X * scale, offset.Y, offset.Z * scale)
end

local function part(parent, name, size, position, color, material, canCollide)
	size, position = geometry(parent, size, position)
	local object = child(parent, "Part", name)
	object.Anchored = true
	object.Size = size
	object.CFrame = CFrame.new(position)
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	Style.Material(object)
	object.Shape = Enum.PartType.Block
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.CanCollide = canCollide ~= false
	object.CanTouch = false
	object.CanQuery = true
	return object
end

local function prompt(parent, name, actionText, objectText, enabled)
	local object = child(parent, "ProximityPrompt", name)
	object.ActionText = actionText
	object.ObjectText = objectText
	object.MaxActivationDistance = 10
	object.RequiresLineOfSight = false
	object.HoldDuration = 0.25
	object.KeyboardKeyCode = Enum.KeyCode.E
	object.Enabled = enabled
	return object
end

local function label(parent, name, text, offset, width, height)
	local gui = child(parent, "BillboardGui", name)
	gui.Size = UDim2.new(0, width or 210, 0, height or 50)
	gui.StudsOffset = offset or Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	local textLabel = child(gui, "TextLabel", "TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundColor3 = DARK
	textLabel.BackgroundTransparency = 0.1
	textLabel.BorderSizePixel = 0
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextColor3 = CREAM
	textLabel.TextScaled = true
	textLabel.TextWrapped = true
	textLabel.Text = text
	return textLabel
end

local function pad(plot, origin, name, x, color, promptName, actionText, objectText, enabled)
	local object = part(plot, name, Vector3.new(6, 0.35, 4), origin + Vector3.new(x, 0.55, -17), color, Enum.Material.Neon)
	prompt(object, promptName, actionText, objectText, enabled)
	label(object, "PadLabel", objectText, Vector3.new(0, 2.3, 0), 140, 38)
	return object
end

-- A door is an opening in the wall, so the entrance is always walkable.
local function frontWall(structure, origin, floor, y, wallColor)
	local z = -10
	part(structure, "FrontLeft" .. floor, Vector3.new(10, 10.5, 0.7), origin + Vector3.new(-9, y + 5.25, z), wallColor)
	part(structure, "FrontRight" .. floor, Vector3.new(10, 10.5, 0.7), origin + Vector3.new(9, y + 5.25, z), wallColor)
	part(structure, "FrontLintel" .. floor, Vector3.new(8, 3, 0.7), origin + Vector3.new(0, y + 9, z), CREAM)
	if floor > 1 then
		-- A closed upper window; only the ground floor is the main entrance.
		local pane = part(structure, "FrontWindow" .. floor, Vector3.new(7.5, 6.8, 0.25), origin + Vector3.new(0, y + 3.9, z), CYAN, Enum.Material.Glass)
		pane.Transparency = 0.5
	end
end

local function rearWall(structure, origin, floor, y, wallColor)
	part(structure, "RearLeft" .. floor, Vector3.new(7, 10.5, 0.7), origin + Vector3.new(-10.5, y + 5.25, 14), wallColor)
	part(structure, "RearMiddle" .. floor, Vector3.new(8, 10.5, 0.7), origin + Vector3.new(0, y + 5.25, 14), wallColor)
	if floor == 2 then
		part(structure, "RearDoorLintel2", Vector3.new(7, 3, 0.7), origin + Vector3.new(10.5, y + 9, 14), CREAM)
	else
		part(structure, "RearRight" .. floor, Vector3.new(7, 10.5, 0.7), origin + Vector3.new(10.5, y + 5.25, 14), wallColor)
	end
	for _, x in ipairs({ -5.5, 5.5 }) do
		local suffix = if x < 0 then "Left" else "Right"
		part(structure, "RearWindowSill" .. suffix .. floor, Vector3.new(3, 2.5, 0.7), origin + Vector3.new(x, y + 1.25, 14), CREAM)
		part(structure, "RearWindowTop" .. suffix .. floor, Vector3.new(3, 2, 0.7), origin + Vector3.new(x, y + 9.5, 14), CREAM)
		local pane = part(structure, "RearWindow" .. suffix .. floor, Vector3.new(3, 6, 0.25), origin + Vector3.new(x, y + 5.5, 14), CYAN, Enum.Material.Glass)
		pane.Transparency = 0.5
	end
end

local function rightWall(structure, origin, floor, y, wallColor)
	-- Floor 2 enters through the rear wall; floor 3 uses this side doorway.
	local doorCenter = -7
	if floor < 3 then
		part(structure, "RightWall" .. floor, Vector3.new(0.7, 10.5, 24), origin + Vector3.new(14, y + 5.25, 2), wallColor)
		return
	end
	local beforeLength = doorCenter - 3 - (-10)
	local afterLength = 14 - (doorCenter + 3)
	if beforeLength > 0 then
		part(structure, "RightFront" .. floor, Vector3.new(0.7, 10.5, beforeLength), origin + Vector3.new(14, y + 5.25, -10 + beforeLength / 2), wallColor)
	end
	if afterLength > 0 then
		part(structure, "RightRear" .. floor, Vector3.new(0.7, 10.5, afterLength), origin + Vector3.new(14, y + 5.25, doorCenter + 3 + afterLength / 2), wallColor)
	end
	part(structure, "SideDoorLintel" .. floor, Vector3.new(0.7, 3, 6), origin + Vector3.new(14, y + 9, doorCenter), CREAM)
end

local function buildDropper(structure, origin, floor, floorTop)
	local model = child(structure, "Model", "Dropper" .. floor)
	local position = origin + Vector3.new(-7, floorTop, 7)
	local color = if floor == 3 then GOLD elseif floor == 2 then CYAN else Color3.fromRGB(122, 179, 239)
	part(model, "MachineBase", Vector3.new(8, 0.6, 8), position + Vector3.new(0, 0.3, 0), DARK, Enum.Material.Metal)
	part(model, "MachineBack", Vector3.new(7, 5, 1), position + Vector3.new(0, 3, 3), color, Enum.Material.Metal)
	part(model, "MachineTop", Vector3.new(7, 1, 5), position + Vector3.new(0, 5.8, 1), color, Enum.Material.Metal)
	part(model, "Nozzle", Vector3.new(1.5, 0.7, 1.5), position + Vector3.new(0, 4.95, -0.7), GOLD, Enum.Material.Neon, false)
	part(model, "Conveyor", Vector3.new(5, 0.4, 6), position + Vector3.new(0, 0.8, -0.5), WOOD, Enum.Material.WoodPlanks)
	for index = 1, 5 do
		part(model, "BeltStripe" .. index, Vector3.new(5, 0.04, 0.18), position + Vector3.new(0, 1.03, -3.3 + index), CREAM, Enum.Material.SmoothPlastic, false)
	end
	local start = part(model, "DropletStart", Vector3.new(0.2, 0.2, 0.2), position + Vector3.new(0, 4.55, -0.7), color, Enum.Material.SmoothPlastic, false)
	local finish = part(model, "DropletEnd", Vector3.new(0.2, 0.2, 0.2), position + Vector3.new(0, 1.25, -0.7), color, Enum.Material.SmoothPlastic, false)
	start.Transparency = 1
	finish.Transparency = 1
	start.CanQuery = false
	finish.CanQuery = false
	label(model:FindFirstChild("MachineBack"), "MachineLabel", if floor == 3 then "ЗОЛОТОЙ ГЕНЕРАТОР" else "ГЕНЕРАТОР " .. floor, Vector3.new(0, 2.4, 0), 150, 40)
end

local function buildStairs(structure, origin, targetFloor)
	local startingTop = 0.8 + (targetFloor - 2) * 12
	local laneX = if targetFloor == 2 then 16.25 else 20
	-- Separate lanes keep the second flight above neither the player's head
	-- nor the first flight. Thin treads leave the space below them open.
	if targetFloor == 2 then
		part(structure, "StairStart", Vector3.new(3.5, 0.4, 3), origin + Vector3.new(laneX, 0.6, -10.5), WOOD, Enum.Material.WoodPlanks)
	end
	-- 24 half-stud risers are climbable by the standard Roblox character.
	for step = 1, 24 do
		local height = step * 0.5
		local z = if targetFloor == 2 then -9.5 + step else 15.5 - step
		part(structure, "Stair" .. targetFloor .. "Step" .. step, Vector3.new(3.5, 0.4, 1), origin + Vector3.new(laneX, startingTop + height - 0.2, z), WOOD, Enum.Material.WoodPlanks)
	end
	-- A landing starts beyond the final step instead of over the approaching
	-- character. The rear porch connects the second floor's broad rear door.
	local landingZ = if targetFloor == 2 then 16 else -9.5
	local landingDepth = if targetFloor == 2 then 3 else 4
	part(structure, "StairLanding" .. targetFloor, Vector3.new(8.25, 0.4, landingDepth), origin + Vector3.new(17.625, startingTop + 11.8, landingZ), WOOD, Enum.Material.WoodPlanks)
	if targetFloor == 2 then
		part(structure, "RearPorch2", Vector3.new(7, 0.4, 3.5), origin + Vector3.new(10.5, startingTop + 11.8, 15.5), WOOD, Enum.Material.WoodPlanks)
	end
	-- The rail is outside the walking width, never across the doorway.
	part(structure, "LandingRail" .. targetFloor, Vector3.new(0.3, 2.5, landingDepth), origin + Vector3.new(21.85, startingTop + 13.25, landingZ), CREAM)
	part(structure, "LandingRailPost" .. targetFloor, Vector3.new(0.3, 3, 0.3), origin + Vector3.new(21.85, startingTop + 13.5, landingZ), DARK)
end

local function buildThirdFloorExtras(structure, origin, floorTop)
	-- The third floor opens onto a broad balcony above the front walkway.
	local oldWindow = structure:FindFirstChild("FrontWindow3")
	if oldWindow then
		oldWindow:Destroy()
	end
	part(structure, "Balcony", Vector3.new(28, 0.4, 5), origin + Vector3.new(0, floorTop - 0.2, -12.5), WOOD, Enum.Material.WoodPlanks)
	part(structure, "BalconyFrontRail", Vector3.new(28, 2.5, 0.4), origin + Vector3.new(0, floorTop + 1.25, -14.8), GOLD, Enum.Material.Metal)
	part(structure, "BalconyLeftRail", Vector3.new(0.4, 2.5, 5), origin + Vector3.new(-13.8, floorTop + 1.25, -12.5), CREAM)
	part(structure, "BalconyRightRail", Vector3.new(0.4, 2.5, 5), origin + Vector3.new(13.8, floorTop + 1.25, -12.5), CREAM)
	part(structure, "BonusChest", Vector3.new(4.5, 2.6, 3), origin + Vector3.new(6, floorTop + 1.3, 6), GOLD, Enum.Material.Metal)
	part(structure, "BonusChestLid", Vector3.new(4.8, 0.5, 3.3), origin + Vector3.new(6, floorTop + 2.85, 6), CREAM, Enum.Material.Metal)
	part(structure, "BonusChestLock", Vector3.new(0.8, 1, 0.3), origin + Vector3.new(6, floorTop + 1.9, 4.35), GOLD, Enum.Material.Neon, false)
	part(structure, "GoldCarpet", Vector3.new(8, 0.04, 5), origin + Vector3.new(6, floorTop + 0.03, 0), GOLD, Enum.Material.SmoothPlastic, false)
	label(structure:FindFirstChild("BonusChest"), "ChestLabel", "БОНУСЫ 3 ЭТАЖА", Vector3.new(0, 3, 0), 170, 40)
	local display = child(structure, "Model", "HeroDisplay")
	local position = origin + Vector3.new(6, floorTop, 10)
	part(display, "DisplayBase", Vector3.new(4, 0.3, 4), position + Vector3.new(0, 0.15, 0), DARK, Enum.Material.Metal)
	part(display, "LeftLeg", Vector3.new(0.65, 1.5, 0.8), position + Vector3.new(-0.55, 1.05, 0), GOLD, Enum.Material.Metal)
	part(display, "RightLeg", Vector3.new(0.65, 1.5, 0.8), position + Vector3.new(0.55, 1.05, 0), GOLD, Enum.Material.Metal)
	local torso = part(display, "ArmorTorso", Vector3.new(2.2, 2.4, 1.2), position + Vector3.new(0, 3, 0), GOLD, Enum.Material.Metal)
	part(display, "LeftArm", Vector3.new(0.6, 2.2, 0.9), position + Vector3.new(-1.55, 3, 0), GOLD, Enum.Material.Metal)
	part(display, "RightArm", Vector3.new(0.6, 2.2, 0.9), position + Vector3.new(1.55, 3, 0), GOLD, Enum.Material.Metal)
	part(display, "Helmet", Vector3.new(1.5, 1.5, 1.3), position + Vector3.new(0, 4.95, 0), DARK, Enum.Material.Metal)
	part(display, "Visor", Vector3.new(1.1, 0.45, 0.15), position + Vector3.new(0, 5.1, -0.72), CYAN, Enum.Material.Neon, false)
	label(torso, "HeroDisplayLabel", "ЗАЛ ГЕРОЯ", Vector3.new(0, 3.8, 0), 150, 38)
end

function World.UpdatePlot(plot, floorNumber, ownerName)
	local base = plot:FindFirstChild("Base")
	assert(base and base:IsA("BasePart"), "Tycoon plot needs its Base")
	local origin = base.Position - Vector3.new(0, 0.15, 0)
	local floors = math.clamp(math.floor(floorNumber or 0), 0, 3)
	local previous = plot:FindFirstChild("Structure")
	if previous then
		assert(previous:IsA("Folder"), "Plot Structure must be a Folder")
		previous:Destroy()
	end
	local structure = child(plot, "Folder", "Structure")
	local plotId = plot:GetAttribute("PlotId") or 1
	local wallColor = HOUSE_COLORS[((plotId - 1) % #HOUSE_COLORS) + 1]
	part(structure, "Foundation", Vector3.new(29, 0.3, 25), origin + Vector3.new(0, 0.45, 2), CREAM, Enum.Material.Concrete)
	for floor = 1, floors do
		local top = 0.8 + (floor - 1) * 12
		part(structure, "Floor" .. floor, Vector3.new(28, 0.4, 24), origin + Vector3.new(0, top - 0.2, 2), WOOD, Enum.Material.WoodPlanks)
		frontWall(structure, origin, floor, top, wallColor)
		rearWall(structure, origin, floor, top, wallColor)
		rightWall(structure, origin, floor, top, wallColor)
		part(structure, "LeftWall" .. floor, Vector3.new(0.7, 10.5, 24), origin + Vector3.new(-14, top + 5.25, 2), wallColor)
		part(structure, "FrontCornice" .. floor, Vector3.new(29, 0.5, 0.9), origin + Vector3.new(0, top + 10.75, -10), CREAM)
		part(structure, "RearCornice" .. floor, Vector3.new(29, 0.5, 0.9), origin + Vector3.new(0, top + 10.75, 14), CREAM)
		buildDropper(structure, origin, floor, top)
		-- Stone frames, brickwork and timber floors use built-in Roblox textures.
		for _, side in ipairs({-1, 1}) do
			part(structure, "CornerTrim" .. floor .. "_" .. side, Vector3.new(0.6, 10.5, 0.8), origin + Vector3.new(side * 13.65, top + 5.25, -10.45), CREAM, Enum.Material.Concrete, false)
			part(structure, "WindowSill" .. floor .. "_" .. side, Vector3.new(4, 0.25, 1.3), origin + Vector3.new(side * 5.5, top + 2.4, 14.3), CREAM, Enum.Material.Concrete, false)
		end
		part(structure, "InteriorRug" .. floor, Vector3.new(9, 0.04, 8), origin + Vector3.new(5, top + 0.03, 0), wallColor, Enum.Material.Fabric, false)
		if floor >= 2 then
			buildStairs(structure, origin, floor)
		end
	end
	if floors > 0 then
		local roofTop = 0.8 + (floors - 1) * 12 + 11.5
		part(structure, "Roof", Vector3.new(30, 0.5, 26), origin + Vector3.new(0, roofTop, 2), DARK, Enum.Material.Slate)
		part(structure, "RoofAccent", Vector3.new(28, 0.15, 24), origin + Vector3.new(0, roofTop + 0.325, 2), if floors == 3 then GOLD else wallColor)
	end
	if floors == 3 then
		buildThirdFloorExtras(structure, origin, 24.8)
	end
	-- Keep this Part and its prompt stable: the server connects to it once.
	-- It becomes an invisible interaction point on the third-floor chest.
	local bonusPad = plot:FindFirstChild("BonusPad")
	if bonusPad then
		bonusPad.Size = Vector3.new(1, 1, 0.35)
		local _, bonusPosition = geometry(plot, Vector3.new(1, 1, 0.35), origin + Vector3.new(6, if floors == 3 then 26.7 else 0.55, if floors == 3 then 4 else -17))
		bonusPad.CFrame = CFrame.new(bonusPosition)
		bonusPad.Transparency = 1
		bonusPad.CanCollide = false
		bonusPad.CanQuery = false
		local bonusLabel = bonusPad:FindFirstChild("PadLabel")
		if bonusLabel then
			bonusLabel.Enabled = false
		end
	end
	local sign = plot:FindFirstChild("PlotSign")
	local gui = sign and sign:FindFirstChild("PlotLabel")
	local textLabel = gui and gui:FindFirstChild("TextLabel")
	if textLabel then
		local name = if type(ownerName) == "string" and ownerName ~= "" then ownerName else "Свободный участок"
		textLabel.Text = name .. "\nЭтажи: " .. floors .. " / 3"
	end
	return structure
end

function World.BuildPlots(workspace, config)
	local folder = child(workspace, "Folder", "TycoonPlots")
	local positions = DEFAULT_POSITIONS
	if config and config.PlotLayout then
		positions = {}
		for _, position in ipairs(config.PlotLayout) do
			table.insert(positions, Vector3.new(position.X, 0, position.Z))
		end
	end
	local plots = {}
	-- Обновление старого места с 12 участками тоже оставляет максимум шесть домов.
	for _, existing in ipairs(folder:GetChildren()) do
		local id = existing:GetAttribute("PlotId")
		if existing:IsA("Model") and type(id) == "number" and id > #positions and string.match(existing.Name, "^Plot%d+$") then existing:Destroy() end
	end
	for index, origin in ipairs(positions) do
		local plot = child(folder, "Model", "Plot" .. index)
		plot:SetAttribute("GeometryScale", config and config.HouseScale or 1.5)
		plot:SetAttribute("OriginX", origin.X)
		plot:SetAttribute("OriginZ", origin.Z)
		plot:SetAttribute("PlotId", index)
		plot:SetAttribute("OwnerUserId", 0)
		plot:SetAttribute("OwnerName", "")
		plot:SetAttribute("Floor", 0)
		plot:SetAttribute("Bank", 0)
		plot:SetAttribute("DropperTier", 0)
		plot:SetAttribute("OwnerReady", false)
		local base = part(plot, "Base", Vector3.new(44, 0.3, 44), origin + Vector3.new(0, 0.15, 0), Color3.fromRGB(166, 191, 144), Enum.Material.Grass)
		plot.PrimaryPart = base
		part(plot, "FrontWalk", Vector3.new(30, 0.1, 10), origin + Vector3.new(0, 0.35, -16), CREAM, Enum.Material.Concrete)
		for _, side in ipairs({-1, 1}) do
			part(plot, "GardenBed" .. side, Vector3.new(5, 0.6, 11), origin + Vector3.new(side * 18.5, 0.55, -8), DARK, Enum.Material.Slate)
			for shrub = 1, 3 do
				local bush = part(plot, "GardenShrub" .. side .. "_" .. shrub, Vector3.new(3.2, 2.1, 3.2), origin + Vector3.new(side * 18.5, 1.6, -14 + shrub * 3), Color3.fromRGB(65, 130, 84), Enum.Material.Grass, false)
				bush.Shape = Enum.PartType.Ball
			end
		end
		local claim = part(plot, "ClaimPad", Vector3.new(7, 0.3, 2.5), origin + Vector3.new(0, 0.6, -20), Color3.fromRGB(88, 231, 156), Enum.Material.Neon)
		prompt(claim, "ClaimPrompt", "Занять", "Свободный дом", true)
		pad(plot, origin, "Collector", -10.5, Color3.fromRGB(99, 222, 159), "CollectPrompt", "Забрать", "КОПИЛКА", false)
		pad(plot, origin, "UpgradePad", -3.5, Color3.fromRGB(108, 185, 248), "FloorPrompt", "Построить", "ЭТАЖ", false)
		pad(plot, origin, "DropperUpgradePad", 3.5, Color3.fromRGB(175, 137, 242), "DropperPrompt", "Улучшить", "ГЕНЕРАТОР", false)
		pad(plot, origin, "BonusPad", 10.5, GOLD, "BonusPrompt", "Получить", "БОНУС III", false)
		pad(plot, origin, "HeroPad", 10.5, Color3.fromRGB(246, 129, 88), "HeroPrompt", "Выбрать героя", "ГЕРОЙ", false)
		local sign = part(plot, "PlotSign", Vector3.new(1, 4.5, 1), origin + Vector3.new(-18, 2.55, -18), WOOD, Enum.Material.Wood)
		label(sign, "PlotLabel", "Свободный участок\nЭтажи: 0 / 3", Vector3.new(0, 3.2, 0), 225, 65)
		World.UpdatePlot(plot, 0, "")
		table.insert(plots, plot)
	end
	return plots
end

return World
