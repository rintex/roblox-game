-- Только оформление мира: награды, герои и бой проверяются другими серверными модулями.
local HeroWorld = {}

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
	stand(campus, "ArenaPortal", Vector3.new(0, 0.55, -43), Color3.fromRGB(240, 105, 104), "EnterArenaPrompt", "Войти в PvP", "PvP / БОЙ С ИГРОКАМИ И РОБОТАМИ")
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
	part(model, "PedestalGlow", Vector3.new(7.5, 0.08, 7.5), origin + Vector3.new(0, 0.64, 0), color, Enum.Material.Neon, false)
	for _, side in ipairs({ -1, 1 }) do
		local suffix = if side < 0 then "Left" else "Right"
		part(model, suffix .. "Leg", Vector3.new(0.8, 2.2, 1), origin + Vector3.new(side * 0.55, 1.8, 0), DARK, Enum.Material.SmoothPlastic, false)
		part(model, suffix .. "Arm", Vector3.new(0.7, 2.7, 1), origin + Vector3.new(side * 1.4, 4.25, 0), color, Enum.Material.SmoothPlastic, false)
	end
	part(model, "Torso", Vector3.new(if index == 4 then 2.5 else 2, 2.7, 1.2), origin + Vector3.new(0, 4.25, 0), color, Enum.Material.SmoothPlastic, false)
	local head = part(model, "Head", Vector3.new(1.6, 1.6, 1.6), origin + Vector3.new(0, 6.45, 0), color, Enum.Material.SmoothPlastic, false)
	head.Shape = Enum.PartType.Ball
	part(model, "Visor", Vector3.new(1.2, 0.28, 0.15), origin + Vector3.new(0, 6.55, -0.8), CREAM, Enum.Material.Neon, false)
	part(model, "Emblem", Vector3.new(0.6, 0.7, 0.15), origin + Vector3.new(0, 4.65, -0.67), CREAM, Enum.Material.Neon, false)
	if index == 2 then
		part(model, "Cape", Vector3.new(3.3, 3.9, 0.2), origin + Vector3.new(0, 3.6, 0.85), Color3.fromRGB(62, 40, 89), Enum.Material.SmoothPlastic, false)
	elseif index == 4 then
		for _, side in ipairs({ -1, 1 }) do
			part(model, "Armor" .. (if side < 0 then "Left" else "Right"), Vector3.new(1.1, 0.8, 1.4), origin + Vector3.new(side * 1.4, 5.35, 0), GOLD, Enum.Material.Metal, false)
		end
	elseif index == 5 then
		for spike = 1, 3 do
			part(model, "IceCrown" .. spike, Vector3.new(0.2, 0.6, 0.25), origin + Vector3.new((spike - 2) * 0.45, 7.35, 0), CYAN, Enum.Material.Neon, false)
		end
	elseif index == 6 then
		part(model, "SunCrest", Vector3.new(0.5, 0.7, 0.4), origin + Vector3.new(0, 7.45, 0), GOLD, Enum.Material.Neon, false)
	end
	label(base, "HeroLabel", definition.Name .. "\nВыбор: кнопка «Герои»", Vector3.new(0, 9, 0), 155, 52)
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
	label(arena:FindFirstChild("Floor"), "ArenaLabel", "АРЕНА PvP\nБой с игроками и роботами", Vector3.new(0, 13, 0), 290, 60)
end

local function buildTraining(campus)
	local park = child(campus, "Folder", "TrainingPark")
	part(park, "Floor", Vector3.new(64, 0.2, 68), Vector3.new(0, 0.1, 120), Color3.fromRGB(110, 157, 135), Enum.Material.Grass)
	for lane, x in ipairs({ -22, 0, 22 }) do
		part(park, "Lane" .. lane, Vector3.new(9, 0.04, 62), Vector3.new(x, 0.22, 120), CREAM, Enum.Material.SmoothPlastic, false)
	end
	for index = 1, 5 do
		local height = index * 0.5
		part(park, "JumpBlock" .. index, Vector3.new(7, height, 6), Vector3.new(-22, 0.25 + height / 2, 92 + index * 10), CYAN)
		part(park, "Hurdle" .. index, Vector3.new(7, 1.5, 0.7), Vector3.new(0, 1, 92 + index * 10), GOLD)
		part(park, "Slalom" .. index, Vector3.new(1.2, 4, 1.2), Vector3.new(22 + (if index % 2 == 0 then -3 else 3), 2.2, 92 + index * 10), VIOLET)
	end
	local start = part(park, "Start", Vector3.new(54, 0.1, 3), Vector3.new(0, 0.3, 88), DARK)
	label(start, "TrainingLabel", "ТРЕНИРОВОЧНЫЙ ПАРК\nПрыжки • препятствия • слалом", Vector3.new(0, 6, 0), 270, 55)
	part(park, "Finish", Vector3.new(54, 0.1, 3), Vector3.new(0, 0.3, 151), GOLD, Enum.Material.Neon)
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
	buildTraining(campus)
	campus:SetAttribute("WorldReady", true)
	return campus
end

return HeroWorld
