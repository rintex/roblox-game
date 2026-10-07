-- Только оформление мира: награды, герои и бой проверяются другими серверными модулями.
local HeroWorld = {}
local Style = require(script.Parent:WaitForChild("VisualStyle"))

local DARK = Color3.fromRGB(34, 48, 70)
local CREAM = Color3.fromRGB(243, 239, 220)
local GOLD = Color3.fromRGB(255, 201, 76)
local CYAN = Color3.fromRGB(83, 224, 234)
local VIOLET = Color3.fromRGB(176, 125, 242)

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

local function part(parent, name, size, position, color, material, collide)
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
	object.CanCollide = collide ~= false
	object.CanTouch = false
	object.CanQuery = true
	return object
end

local function label(parent, name, text, offset, width, height)
	local gui = child(parent, "BillboardGui", name)
	gui.Size = UDim2.new(0, width or 190, 0, height or 48)
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 95
	local textLabel = child(gui, "TextLabel", "TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundColor3 = DARK
	textLabel.BackgroundTransparency = 0.08
	textLabel.BorderSizePixel = 0
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextColor3 = CREAM
	textLabel.TextScaled = true
	textLabel.TextWrapped = true
	textLabel.Text = text
	return textLabel
end

local function stand(campus, name, position, color, promptName, action, title)
	local base = part(campus, name, Vector3.new(7, 0.5, 5), position, color, Enum.Material.Neon)
	local prompt = child(base, "ProximityPrompt", promptName)
	prompt.ActionText = action
	prompt.ObjectText = title
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.25
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	-- The runtime service decides availability after construction.
	prompt.Enabled = true
	label(base, "StandLabel", title, Vector3.new(0, 5.5, 0), 190, 52)
	return base
end

local function gate(parent, name, x, z, color)
	local model = child(parent, "Model", name)
	for _, side in ipairs({ -1, 1 }) do
		local suffix = if side < 0 then "Left" else "Right"
		part(model, suffix .. "Pillar", Vector3.new(1, 9, 1.5), Vector3.new(x + side * 5, 4.5, z), DARK, Enum.Material.Metal)
		part(model, suffix .. "Glow", Vector3.new(0.2, 7, 1.6), Vector3.new(x + side * 4.45, 4.5, z), color, Enum.Material.Neon, false)
	end
	part(model, "Top", Vector3.new(11, 1, 1.5), Vector3.new(x, 9.5, z), color, Enum.Material.Neon)
	return model
end

local function buildStands(campus, decor)
	stand(campus, "DailyStand", Vector3.new(-20, 0.55, 18), GOLD, "ClaimDailyPrompt", "Получить подарок", "ЕЖЕДНЕВНЫЙ ПОДАРОК")
	stand(campus, "QuestStand", Vector3.new(20, 0.55, 18), CYAN, "QuestPrompt", "Посмотреть задания", "ЗАДАНИЯ ГЕРОЯ")
	stand(campus, "ArenaPortal", Vector3.new(0, 0.55, -43), Color3.fromRGB(240, 105, 104), "EnterArenaPrompt", "Войти на арену", "ОПАСНАЯ ЗОНА / БАНДИТЫ И PvP")
	stand(campus, "ReturnStand", Vector3.new(35, 0.55, -88), CYAN, "ReturnPrompt", "Вернуться домой", "ВЕРНУТЬСЯ В БЕЗОПАСНУЮ ЗОНУ")
	stand(campus, "RebirthStand", Vector3.new(-26, 0.55, 0), VIOLET, "RebirthPrompt", "Перерождение", "ПЕРЕРОЖДЕНИЕ")
	gate(decor, "ArenaGate", 0, -47, Color3.fromRGB(240, 105, 104))
	gate(decor, "ReturnGate", 35, -91, CYAN)
	gate(decor, "RebirthGate", -26, -3, VIOLET)
	part(decor, "DailyGift", Vector3.new(3.5, 2.8, 3), Vector3.new(-20, 2.2, 21.1), GOLD)
	part(decor, "GiftRibbon", Vector3.new(0.6, 2.85, 3.1), Vector3.new(-20, 2.2, 21.1), CREAM, Enum.Material.SmoothPlastic, false)
	part(decor, "GiftLid", Vector3.new(3.8, 0.35, 3.3), Vector3.new(-20, 3.8, 21.1), CREAM)
	part(decor, "QuestBoard", Vector3.new(5, 4, 0.5), Vector3.new(20, 3.2, 21.1), DARK)
	for index = 1, 3 do
		part(decor, "QuestLine" .. index, Vector3.new(3.6, 0.18, 0.12), Vector3.new(20, 4.3 - index * 0.8, 20.79), CYAN, Enum.Material.Neon, false)
	end
end

local function buildHero(gallery, definition, index)
	local column = (index - 1) % 3
	local z = if index <= 3 then -12 else 24
	local origin = Vector3.new(42 + column * 13, 0, z)
	local model = child(gallery, "Model", "Hero" .. index)
	model:SetAttribute("HeroId", definition.Id)
	local rgb = definition.Color
	local color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	local base = part(model, "Pedestal", Vector3.new(8, 0.6, 8), origin + Vector3.new(0, 0.3, 0), DARK, Enum.Material.Concrete)
	base.CanTouch = true
	part(model, "PedestalGlow", Vector3.new(7.5, 0.08, 7.5), origin + Vector3.new(0, 0.64, 0), color, Enum.Material.Neon, false)
	for _, side in ipairs({ -1, 1 }) do
		local suffix = if side < 0 then "Left" else "Right"
		part(model, suffix .. "Leg", Vector3.new(0.8, 2.2, 1), origin + Vector3.new(side * 0.55, 1.8, 0), DARK, Enum.Material.SmoothPlastic, false)
		part(model, suffix .. "Arm", Vector3.new(0.7, 2.7, 1), origin + Vector3.new(side * 1.4, 4.25, 0), color, Enum.Material.SmoothPlastic, false)
	end
	part(model, "Torso", Vector3.new(if index == 4 then 2.5 else 2, 2.7, 1.2), origin + Vector3.new(0, 4.25, 0), color, Enum.Material.SmoothPlastic, false)
	local head = part(model, "Head", Vector3.new(1.6, 1.6, 1.6), origin + Vector3.new(0, 6.45, 0), color, Enum.Material.SmoothPlastic, false)
	if definition.Style == "thor" then head.Color = Color3.fromRGB(218, 174, 137) end
	Style.Face(head, definition.Style)
	Style.Chest(model:FindFirstChild("Torso"), definition.Style)
	-- Both rows face the walkway between the displays.
	if index <= 3 then
		head:FindFirstChild("CostumeFace").Face = Enum.NormalId.Back
		model:FindFirstChild("Torso"):FindFirstChild("CostumeChest").Face = Enum.NormalId.Back
	end
	if definition.Style == "spider" then
		for _, name in ipairs({ "LeftLeg", "RightLeg" }) do model:FindFirstChild(name).Color = Color3.fromRGB(29, 64, 132) end
	elseif definition.Style == "hulk" then
		for _, name in ipairs({ "LeftLeg", "RightLeg" }) do
			model:FindFirstChild(name).Color = Color3.fromRGB(95, 55, 141)
			model:FindFirstChild(name).Material = Enum.Material.Fabric
		end
	end
	if index == 4 then
		for _, side in ipairs({ -1, 1 }) do
			part(model, "Muscle" .. (if side < 0 then "Left" else "Right"), Vector3.new(1.1, 0.8, 1.4), origin + Vector3.new(side * 1.4, 5.35, 0), color, Enum.Material.SmoothPlastic, false)
		end
	elseif index == 5 then
		part(model, "ThorCape", Vector3.new(3.3, 3.9, 0.2), origin + Vector3.new(0, 3.6, 0.85), Color3.fromRGB(170, 35, 38), Enum.Material.Fabric, false)
	end
	label(base, "HeroLabel", definition.Name .. "\nНаступи, чтобы надеть · " .. (if definition.MinRebirths > 0 then "Перерождений: " .. definition.MinRebirths else "Этаж: " .. definition.MinFloor), Vector3.new(0, 9, 0), 180, 60)
end

local function buildArena(campus)
	local arena = child(campus, "Folder", "Arena")
	part(arena, "Floor", Vector3.new(100, 0.24, 76), Vector3.new(0, 0.12, -120), Color3.fromRGB(93, 111, 131), Enum.Material.Concrete)
	-- Open center gates give characters a sixteen-stud entrance and exit.
	for _, z in ipairs({ -82, -158 }) do
		local endName = if z == -82 then "North" else "South"
		for _, side in ipairs({ -1, 1 }) do
			local suffix = if side < 0 then "Left" else "Right"
			part(arena, endName .. suffix .. "Wall", Vector3.new(42, 3.5, 1), Vector3.new(side * 29, 1.75, z), DARK, Enum.Material.Metal)
			part(arena, endName .. suffix .. "Trim", Vector3.new(42, 0.15, 1.1), Vector3.new(side * 29, 3.6, z), CYAN, Enum.Material.Neon, false)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local suffix = if side < 0 then "Left" else "Right"
		part(arena, suffix .. "Wall", Vector3.new(1, 3.5, 76), Vector3.new(side * 49.5, 1.75, -120), DARK, Enum.Material.Metal)
		part(arena, suffix .. "Trim", Vector3.new(1.1, 0.15, 76), Vector3.new(side * 49.5, 3.6, -120), CYAN, Enum.Material.Neon, false)
	end
	-- Lines decorate the floor without adding barriers inside the battle area.
	part(arena, "CenterLine", Vector3.new(88, 0.02, 0.15), Vector3.new(0, 0.25, -120), CREAM, Enum.Material.SmoothPlastic, false)
	for index, position in ipairs({ Vector3.new(-46, 4.5, -86), Vector3.new(46, 4.5, -86), Vector3.new(-46, 4.5, -154), Vector3.new(46, 4.5, -154) }) do
		part(arena, "LampPost" .. index, Vector3.new(0.6, 9, 0.6), position, DARK, Enum.Material.Metal)
		part(arena, "Lamp" .. index, Vector3.new(2, 0.6, 2), position + Vector3.new(0, 4.7, 0), CYAN, Enum.Material.Neon, false)
	end
	label(arena:FindFirstChild("Floor"), "ArenaLabel", "АРЕНА PvP\nБандиты атакуют · PvP включено", Vector3.new(0, 13, 0), 290, 60)
end

local function buildCityDecor(campus, config)
 local decor=child(campus,"Folder","Neighborhood")
 local sign=part(decor,"WelcomeSign",Vector3.new(18,4,0.5),Vector3.new(0,7,-23),DARK,Enum.Material.WoodPlanks,false)
 label(sign,"WelcomeLabel",config.GameTitle.."\nСТРОЙ · ПРЫГАЙ · СРАЖАЙСЯ",Vector3.new(0,1,0),340,85)
 for _,side in ipairs({-1,1}) do
  part(decor,"SignPost"..side,Vector3.new(0.5,8,0.5),Vector3.new(side*7,4,-23),DARK,Enum.Material.Metal)
 end
 part(decor,"FountainBase",Vector3.new(14,0.65,11),Vector3.new(-18,0.6,-18),CREAM,Enum.Material.Cobblestone)
 local water=part(decor,"FountainWater",Vector3.new(12,0.15,9),Vector3.new(-18,1,-18),Color3.fromRGB(75,177,218),Enum.Material.Glass,false)
 water.Transparency=0.3;water.CanQuery=false
 for _,side in ipairs({-1,1}) do
  part(decor,"FountainRimX"..side,Vector3.new(0.8,1,11),Vector3.new(-18+side*6.8,0.9,-18),CREAM,Enum.Material.Concrete)
  part(decor,"FountainRimZ"..side,Vector3.new(13,1,0.8),Vector3.new(-18,0.9,-18+side*5.2),CREAM,Enum.Material.Concrete)
 end
 part(decor,"FountainPillar",Vector3.new(1.2,3,1.2),Vector3.new(-18,2.4,-18),CREAM,Enum.Material.Slate)
 local jet=part(decor,"WaterJet",Vector3.new(0.6,3.8,0.6),Vector3.new(-18,4.7,-18),CYAN,Enum.Material.Glass,false)
 jet.Transparency=0.45;jet.CanQuery=false
 for index,position in ipairs({Vector3.new(-31,0,24),Vector3.new(31,0,24),Vector3.new(-31,0,-9),Vector3.new(29,0,-23)}) do
  part(decor,"FlowerBed"..index,Vector3.new(4.5,1.2,4.5),position+Vector3.new(0,0.6,0),Color3.fromRGB(147,102,71),Enum.Material.Brick)
  for flower=1,3 do
   local bloom=part(decor,"Flower"..index.."_"..flower,Vector3.new(1.3,1.3,1.3),position+Vector3.new((flower-2)*1.1,1.7,0),if flower==2 then GOLD else Color3.fromRGB(212,116,159),Enum.Material.SmoothPlastic,false)
   bloom.Shape=Enum.PartType.Ball;bloom.CanQuery=false
  end
 end
 for index,position in ipairs({Vector3.new(17,0,-17),Vector3.new(-31,0,9)}) do
  part(decor,"BenchSeat"..index,Vector3.new(7,0.4,2),position+Vector3.new(0,1.4,0),Color3.fromRGB(146,102,71),Enum.Material.WoodPlanks)
  part(decor,"BenchBack"..index,Vector3.new(7,1.4,0.3),position+Vector3.new(0,2.3,0.9),Color3.fromRGB(146,102,71),Enum.Material.WoodPlanks)
  for _,side in ipairs({-1,1}) do part(decor,"BenchLeg"..index..side,Vector3.new(0.4,1.3,1.5),position+Vector3.new(side*2.8,0.7,0),DARK,Enum.Material.Metal) end
 end
end

function HeroWorld.Build(workspace, config)
	assert(type(config.Heroes) == "table" and #config.Heroes == 6, "HeroWorld expects six configured heroes")
	local campus = child(workspace, "Folder", "HeroCampus")
	local decor = child(campus, "Folder", "Decor")
	buildStands(campus, decor)
	local gallery = child(campus, "Folder", "Gallery")
	for index, definition in ipairs(config.Heroes) do
		buildHero(gallery, definition, index)
	end
	buildArena(campus)
	buildCityDecor(campus, config)
	campus:SetAttribute("WorldReady", true)
	return campus
end

return HeroWorld
