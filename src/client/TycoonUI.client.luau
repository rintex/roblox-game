-- HUD and shop guide. Purchases and rewards always belong to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TycoonConfig"))
local remotes = ReplicatedStorage:WaitForChild("TycoonRemotes")
local notice = remotes:WaitForChild("Notice")
local actionRequest = remotes:WaitForChild("ActionRequest")
local monetizationRequest = remotes:WaitForChild("MonetizationRequest")

local gui = playerGui:FindFirstChild("TycoonHUD")
if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "TycoonHUD"
	gui.Parent = playerGui
end
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- A rerun asks the previous HUD to remove its listeners before rebuilding.
local oldRuntime = gui:FindFirstChild("TycoonUIRuntime")
if oldRuntime then
	local oldStop = oldRuntime:FindFirstChild("Stop")
	if oldStop and oldStop:IsA("BindableEvent") then
		oldStop:Fire()
	end
	oldRuntime:Destroy()
end

local runtime = Instance.new("Frame")
runtime.Name = "TycoonUIRuntime"
runtime.Size = UDim2.fromScale(1, 1)
runtime.BackgroundTransparency = 1
runtime.BorderSizePixel = 0
runtime.Parent = gui
local stopEvent = Instance.new("BindableEvent")
stopEvent.Name = "Stop"
stopEvent.Parent = runtime

local connections = {}
local statsConnections = {}
local alive = true
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local palette = {
	panel = Color3.fromRGB(24, 31, 44),
	card = Color3.fromRGB(37, 46, 62),
	text = Color3.fromRGB(243, 248, 255),
	muted = Color3.fromRGB(172, 189, 209),
	gold = Color3.fromRGB(255, 212, 104),
	teal = Color3.fromRGB(97, 231, 191),
	blue = Color3.fromRGB(118, 194, 255),
	red = Color3.fromRGB(255, 148, 148),
}

local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function corner(object, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, object)
end

local function label(parent, name, text, size, position, fontSize, color)
	return make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		Text = text,
		TextColor3 = color or palette.text,
		TextSize = fontSize,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		ZIndex = 12,
	}, parent)
end

local hud = make("Frame", {
	Name = "Dashboard",
	BackgroundColor3 = palette.panel,
	BackgroundTransparency = 0.06,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(14, 12),
	Size = UDim2.fromOffset(340, 232),
}, runtime)
corner(hud, 18)
make("UIStroke", { Color = Color3.fromRGB(70, 89, 110), Transparency = 0.3 }, hud)
local hudScale = make("UIScale", { Scale = 1 }, hud)
label(hud, "Title", string.upper(Config.GameTitle), UDim2.fromOffset(206, 26), UDim2.fromOffset(16, 12), 17, palette.teal)
local shopButton = make("TextButton", {
	Name = "ShopButton",
	Size = UDim2.fromOffset(96, 40),
	Position = UDim2.fromOffset(228, 6),
	BackgroundColor3 = palette.teal,
	BorderSizePixel = 0,
	Text = "Магазин",
	TextColor3 = palette.panel,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = true,
	ZIndex = 13,
}, hud)
corner(shopButton, 10)
local coinsText = label(hud, "Coins", "Монеты: ...", UDim2.fromOffset(206, 30), UDim2.fromOffset(16, 48), 23, palette.gold)
coinsText.TextScaled = true
make("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 23 }, coinsText)
local levelText = label(hud, "Level", "Уровень: ...", UDim2.fromOffset(110, 30), UDim2.fromOffset(218, 48), 14)
levelText.TextScaled = true
make("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 14 }, levelText)
local xpText = label(hud, "XP", "XP: 0", UDim2.fromOffset(310, 20), UDim2.fromOffset(16, 80), 12, palette.muted)
make("Frame", {
	Name = "Divider",
	BorderSizePixel = 0,
	BackgroundColor3 = Color3.fromRGB(64, 77, 97),
	Size = UDim2.fromOffset(308, 1),
	Position = UDim2.fromOffset(16, 106),
}, hud)
local houseText = label(hud, "House", "Дом: нет участка", UDim2.fromOffset(306, 22), UDim2.fromOffset(16, 112), 14)
local bankText = label(hud, "Bank", "В кассе: 0  ·  Доход: 0/сек", UDim2.fromOffset(306, 24), UDim2.fromOffset(16, 138), 13, palette.blue)
local heroText = label(hud, "Hero", "Герой: не выбран", UDim2.fromOffset(306, 24), UDim2.fromOffset(16, 166), 12, palette.teal)
local saveText = label(hud, "SaveStatus", "Загрузка прогресса...", UDim2.fromOffset(306, 32), UDim2.fromOffset(16, 196), 11, palette.muted)

local guide = make("Frame", {
	Name = "Guide",
	BackgroundColor3 = palette.panel,
	BackgroundTransparency = 0.18,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(14, 256),
	Size = UDim2.fromOffset(340, 70),
}, runtime)
corner(guide, 12)
local guideScale = make("UIScale", { Scale = 1 }, guide)
local guideText = label(guide, "Instructions", "Займи участок: подойди к зелёной площадке и нажми E или кнопку на экране.", UDim2.new(1, -28, 1, -16), UDim2.fromOffset(14, 8), 12, palette.text)

local overlay = make("TextButton", {
	Name = "ShopBackdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(5, 11, 22),
	BackgroundTransparency = 0.25,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 10,
}, runtime)

local shop = make("Frame", {
	Name = "ShopPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(500, 610),
	BackgroundColor3 = palette.panel,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 11,
}, runtime)
corner(shop, 20)
local shopScale = make("UIScale", { Scale = 1 }, shop)
label(shop, "Title", "Твоя база. Твой герой.", UDim2.new(1, -84, 0, 30), UDim2.fromOffset(20, 16), 22, palette.teal)
local shopIntro = label(shop, "Intro", "Строй, открывай героев и побеждай противников на арене.", UDim2.new(1, -40, 0, 32), UDim2.fromOffset(20, 50), 13, palette.muted)
local closeButton = make("TextButton", {
	Name = "Close",
	Size = UDim2.fromOffset(44, 44),
	Position = UDim2.new(1, -56, 0, 8),
	BackgroundColor3 = palette.card,
	Text = "×",
	TextSize = 26,
	Font = Enum.Font.GothamBold,
	TextColor3 = palette.text,
	BorderSizePixel = 0,
	ZIndex = 13,
}, shop)
corner(closeButton, 10)

local tabs = {}
local currentTab = "House"
local tabDefinitions = { { "House", "Дом" }, { "Heroes", "Герои" }, { "Progress", "Прогресс" }, { "Style", "Стиль" } }
for index, definition in ipairs(tabDefinitions) do
	local name, text = definition[1], definition[2]
	local button = make("TextButton", {
		Name = name .. "Tab", Size = UDim2.new(0.25, -16, 0, 42),
		Position = UDim2.new((index - 1) * 0.25, 20 - (index - 1) * 8, 0, 90),
		BackgroundColor3 = palette.card, BorderSizePixel = 0, Text = text,
		TextColor3 = palette.text, TextSize = 13, Font = Enum.Font.GothamBold, ZIndex = 13,
	}, shop)
	corner(button, 10)
	local list = make("ScrollingFrame", {
		Name = name .. "List", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, 148), Size = UDim2.new(1, -40, 1, -208),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = palette.teal, Visible = name == currentTab, ZIndex = 12,
	}, shop)
	make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	tabs[name] = { button = button, list = list }
end
local shopList = tabs.House.list

local function shopCard(name, order, height, parent)
	local card = make("Frame", {
		Name = name,
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = palette.card,
		BorderSizePixel = 0,
		LayoutOrder = order,
		ZIndex = 12,
	}, parent or shopList)
	corner(card, 12)
	local title = label(card, "Title", "", UDim2.new(1, -28, 0, 26), UDim2.fromOffset(14, 10), 16, palette.gold)
	local detail = label(card, "Detail", "", UDim2.new(1, -28, 1, -44), UDim2.fromOffset(14, 38), 13, palette.text)
	return title, detail, card
end

local floorTitle, floorDetail = shopCard("FloorUpgrade", 1, 114)
local dropperTitle, dropperDetail = shopCard("GeneratorUpgrade", 2, 114)
local bonusTitle, bonusDetail = shopCard("ThirdFloorBonus", 3, 132)
local shopFooter = label(shop, "Footer", "Подойди к площадке: E на ПК, кнопка на телефоне.", UDim2.new(1, -40, 0, 38), UDim2.new(0, 20, 1, -48), 12, palette.muted)

local lastRequestAt = 0
local function request(command, id)
	if not player:GetAttribute("DataReady") or os.clock() - lastRequestAt < 0.4 then return end
	lastRequestAt = os.clock()
	actionRequest:FireServer(command, id)
end

local function actionButton(card, name, callback)
	local button = make("TextButton", {
		Name = name, Position = UDim2.new(0, 14, 1, -54), Size = UDim2.new(1, -28, 0, 42),
		BackgroundColor3 = palette.teal, BorderSizePixel = 0, Text = "...",
		TextColor3 = palette.panel, TextSize = 13, Font = Enum.Font.GothamBold, ZIndex = 13,
	}, card)
	corner(button, 9)
	connect(button.Activated, function()
		if button:GetAttribute("Enabled") then callback() end
	end)
	return button
end

local function setButton(button, text, enabled)
	button.Text = text
	button:SetAttribute("Enabled", enabled == true)
	button.Active = enabled == true
	button.AutoButtonColor = enabled == true
	button.BackgroundColor3 = if enabled then palette.teal else Color3.fromRGB(57, 69, 85)
	button.TextColor3 = if enabled then palette.panel else palette.muted
end

local heroCards = {}
for index, hero in ipairs(Config.Heroes or {}) do
	local title, detail, card = shopCard("Hero_" .. hero.Id, index, 192, tabs.Heroes.list)
	title.Text = hero.Name
	title.TextScaled = true
	make("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 16 }, title)
	local color = hero.Color
	if type(color) == "table" then title.TextColor3 = Color3.fromRGB(color[1], color[2], color[3]) end
	detail.Size = UDim2.new(1, -28, 0, 90)
	detail.TextYAlignment = Enum.TextYAlignment.Top
	local button = actionButton(card, "Equip", function() request("EquipHero", hero.Id) end)
	table.insert(heroCards, { hero = hero, detail = detail, button = button })
end

local questCards = {}
local questDefinitions = Config.Quests or {}
local questState = {
	collector = { progress = "CollectedTotal", done = "QuestCollectorDone" },
	builder = { progress = "Floor", done = "QuestBuilderDone" },
	fighter = { progress = "EnemiesDefeated", done = "QuestFighterDone" },
}
local questOrder = 0
for key, quest in pairs(questDefinitions) do
	if type(quest) == "table" then
		local id = quest.Id or key
		local state = questState[id]
		if state then
			questOrder += 1
			local title, detail, card = shopCard("Quest_" .. id, questOrder, 162, tabs.Progress.list)
			title.Text = quest.Title
			detail.Size = UDim2.new(1, -28, 0, 62)
			local button = actionButton(card, "Claim", function() request("ClaimQuest", id) end)
			table.insert(questCards, { quest = quest, state = state, detail = detail, button = button })
		end
	end
end

local dailyTitle, dailyDetail, dailyCard = shopCard("DailyReward", 10, 164, tabs.Progress.list)
dailyTitle.Text = "Ежедневная награда"
dailyDetail.Size = UDim2.new(1, -28, 0, 64)
local dailyButton = actionButton(dailyCard, "ClaimDaily", function() request("ClaimDaily") end)
local rebirthTitle, rebirthDetail, rebirthCard = shopCard("Rebirth", 11, 208, tabs.Progress.list)
rebirthTitle.Text = "Перерождение"
rebirthDetail.Size = UDim2.new(1, -28, 0, 108)
local rebirthConfirmedUntil = 0
local rebirthButton
rebirthButton = actionButton(rebirthCard, "Rebirth", function()
	if os.clock() > rebirthConfirmedUntil then
		rebirthConfirmedUntil = os.clock() + 6
		rebirthButton.Text = "Подтверди сброс: нажми ещё раз"
	else
		rebirthConfirmedUntil = 0
		request("Rebirth")
	end
end)

local passCards = {}
for _, key in ipairs({ "VIP", "Neon" }) do
	local definition = Config.GamePasses and Config.GamePasses[key]
	-- Unconfigured purchases have no button or product entry in the game.
	if definition and type(definition.Id) == "number" and definition.Id > 0 then
		local title, detail, card = shopCard("Pass_" .. key, #passCards + 1, 180, tabs.Style.list)
		title.Text = definition.Name
		detail.Text = definition.Description
		detail.Size = UDim2.new(1, -28, 0, 76)
		local button = actionButton(card, "Purchase", function()
			if not player:GetAttribute("DataReady") or os.clock() - lastRequestAt < 0.4 then return end
			lastRequestAt = os.clock()
			monetizationRequest:FireServer(key)
		end)
		table.insert(passCards, { key = key, button = button })
	end
end
if #passCards == 0 then
	local title, detail = shopCard("StyleInfo", 1, 116, tabs.Style.list)
	title.Text = "Твой стиль — твой герой"
	detail.Text = "Меняй героев во вкладке «Герои». Их оружие и способности открываются через строительство и перерождения."
end

local toast = make("Frame", {
	Name = "Notification",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 16),
	Size = UDim2.fromOffset(380, 68),
	BackgroundColor3 = palette.panel,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 20,
}, runtime)
corner(toast, 14)
local toastScale = make("UIScale", { Scale = 1 }, toast)
local toastStroke = make("UIStroke", { Color = palette.teal, Thickness = 2 }, toast)
local toastText = label(toast, "Message", "", UDim2.new(1, -28, 1, -16), UDim2.fromOffset(14, 8), 14)
toastText.ZIndex = 21

local function number(value)
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.max(0, math.floor(value))
end

local function format(value)
	local digits = tostring(number(value))
	local reversed = string.reverse(digits)
	local spaced = string.gsub(reversed, "(%d%d%d)", "%1 ")
	return string.reverse(spaced):gsub("^ ", "")
end

local function attribute(name)
	return number(player:GetAttribute(name))
end

local stats = nil
local function stat(name)
	local value = stats and stats:FindFirstChild(name)
	if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
		return number(value.Value)
	end
	return nil
end

local function update()
	if not alive then
		return
	end
	local floor = math.min(attribute("Floor"), #Config.Floors)
	local tier = math.min(attribute("DropperTier"), #Config.DropperCosts)
	local plotId = attribute("PlotId")
	local rebirths = attribute("Rebirths")
	local equippedId = player:GetAttribute("EquippedHero")
	local equippedWeapon = player:GetAttribute("EquippedWeapon")
	local equippedName = "не выбран"
	for _, hero in ipairs(Config.Heroes or {}) do
		if hero.Id == equippedId then equippedName = hero.Name; break end
	end
	local coins, level = stat("Coins"), stat("Level")
	coinsText.Text = coins and ("Монеты: " .. format(coins)) or "Монеты: ..."
	levelText.Text = level and ("Уровень: " .. format(level)) or "Уровень: ..."
	xpText.Text = "Опыт: " .. format(attribute("XP")) .. " XP · получай монеты, чтобы расти"
	houseText.Text = if plotId > 0 then ("Участок №" .. plotId .. "  ·  Этажи: " .. floor .. "/3") else "Дом: выбери свободный участок"
	bankText.Text = "В кассе: " .. format(attribute("Bank")) .. "  ·  Доход: " .. format(attribute("Income")) .. "/сек"
	heroText.Text = "Герой: " .. equippedName .. " · Перерождений: " .. format(rebirths)

	local mode = player:GetAttribute("PersistenceMode")
	local status = player:GetAttribute("PersistenceStatus")
	if status == "error" then
		saveText.Text = "Ошибка сохранения — дождись восстановления."
		saveText.TextColor3 = palette.red
	elseif mode == "session" or status == "session" then
		saveText.Text = "Сохранение недоступно: прогресс только в этой сессии."
		saveText.TextColor3 = palette.gold
	elseif not player:GetAttribute("DataReady") or status == "loading" then
		saveText.Text = "Загрузка прогресса..."
		saveText.TextColor3 = palette.muted
	elseif status == "saving" then
		saveText.Text = "Сохранение прогресса..."
		saveText.TextColor3 = palette.muted
	elseif status == "saved" then
		saveText.Text = "Автосохранение включено"
		saveText.TextColor3 = palette.teal
	else
		saveText.Text = "Состояние сохранения уточняется..."
		saveText.TextColor3 = palette.muted
	end

	if not player:GetAttribute("DataReady") then
		guideText.Text = "Подожди загрузки прогресса. Если появилась ошибка — смотри уведомление."
	elseif plotId == 0 then
		guideText.Text = "Займи участок: зелёная площадка → E на ПК или кнопка на телефоне."
	elseif floor == 0 then
		guideText.Text = "Построй первый этаж: подойди к синей площадке. Цена: " .. format(Config.Floors[1].Cost) .. " монет."
	elseif floor < 3 then
		guideText.Text = "Собирай зелёную кассу, строй этажи. В меню → «Герои» выбери героя и сражайся на арене."
	else
		guideText.Text = "Сундук на третьем этаже даёт бонусы. Меню → «Прогресс»: задания, награды и перерождения."
	end

	local nextFloor = Config.Floors[floor + 1]
	if nextFloor then
		floorTitle.Text = "Этаж " .. (floor + 1) .. " · " .. format(nextFloor.Cost) .. " монет"
		floorDetail.Text = "Новый этаж и генератор. Синяя площадка на твоём участке."
		if floor + 1 == 3 then
			floorDetail.Text ..= " Откроет золотую раздачу и ускорение."
		end
	else
		floorTitle.Text = "Все 3 этажа построены!"
		floorDetail.Text = "Золотой генератор работает. Улучшай его и забирай дополнительные награды."
	end

	local nextCost = Config.DropperCosts[tier + 1]
	if nextCost then
		dropperTitle.Text = "Генератор " .. (tier + 1) .. " · " .. format(nextCost) .. " монет"
		dropperDetail.Text = "Увеличивает доход всех этажей. Фиолетовая площадка на твоём участке."
		if floor == 0 then
			dropperDetail.Text = "Сначала построй первый этаж, затем улучшай генератор на фиолетовой площадке."
		end
	else
		dropperTitle.Text = "Генератор улучшен до максимума"
		dropperDetail.Text = "Твой дом получает максимальный доход. Не забывай собирать деньги из зелёной кассы."
	end

	bonusTitle.Text = "Плюшки третьего этажа"
	local bonusReadyAt = player:GetAttribute("BonusReadyAt")
	local seconds = if type(bonusReadyAt) == "number" then math.max(0, math.ceil(bonusReadyAt - Workspace:GetServerTimeNow())) else 0
	local bonusState = if floor < 3 then "Откроется после постройки третьего этажа." elseif seconds > 0 then ("Следующая раздача через " .. seconds .. " сек.") else "Раздача готова: открой сундук на третьем этаже!"
	bonusDetail.Text = "Золотой генератор, скорость " .. Config.ThirdFloorWalkSpeed .. " и +" .. format(Config.BonusCoins) .. " монет раз в " .. Config.BonusCooldown .. " сек.\n" .. bonusState

	local ready = player:GetAttribute("DataReady") == true
	local heroProfile = { Floor = floor, Rebirths = rebirths }
	for _, entry in ipairs(heroCards) do
		local hero = entry.hero
		local unlocked = Config.CanUseHero(heroProfile, hero)
		local required = "Этаж " .. hero.MinFloor
		if hero.MinRebirths > 0 then required ..= " · перерождений: " .. hero.MinRebirths end
		entry.detail.Text = hero.Description .. "\n" .. required .. " · урон: " .. hero.Damage .. "\nОружие: клик или Q; на телефоне — «Навык»."
		if equippedId == hero.Id and (equippedWeapon == nil or equippedWeapon == "") then
			setButton(entry.button, "Выбран", false)
		elseif not ready then
			setButton(entry.button, "Загрузка прогресса...", false)
		elseif not unlocked then
			setButton(entry.button, "Откроется: " .. required, false)
		else
			setButton(entry.button, "Выбрать героя", true)
		end
	end

	for _, entry in ipairs(questCards) do
		local progress = math.min(entry.quest.Target, attribute(entry.state.progress))
		if entry.quest.Id == "builder" and rebirths > 0 then progress = entry.quest.Target end
		local done = player:GetAttribute(entry.state.done) == true
		entry.detail.Text = "Прогресс: " .. format(progress) .. "/" .. format(entry.quest.Target) .. "\nНаграда: " .. format(entry.quest.RewardCoins) .. " монет"
		setButton(entry.button, if done then "Награда получена" elseif progress >= entry.quest.Target then "Забрать награду" else "Выполни задание", ready and not done and progress >= entry.quest.Target)
	end
	local dailySeconds = math.max(0, math.ceil(attribute("DailyReadyAt") - Workspace:GetServerTimeNow()))
	local remainingMinutes = math.ceil(dailySeconds / 60)
	local dailyHours = math.floor(remainingMinutes / 60)
	local dailyMinutes = remainingMinutes % 60
	dailyDetail.Text = "+" .. format(Config.DailyReward) .. " монет за возвращение в игру.\n" .. (if dailySeconds > 0 then ("Следующая награда через " .. dailyHours .. " ч " .. dailyMinutes .. " мин.") else "Награда готова!")
	setButton(dailyButton, if dailySeconds > 0 then "Возвращайся позже" else "Забрать ежедневную награду", ready and dailySeconds == 0)

	local rebirthCost = Config.RebirthCost(rebirths)
	rebirthDetail.Text = "Нужно: " .. Config.RebirthMinFloor .. " этажа, генератор " .. Config.RebirthMinTier .. " и " .. format(rebirthCost) .. " монет. Сбросятся монеты, этажи, генераторы и касса. Опыт, задания и открытые герои сохранятся. Бонус дохода: +" .. math.floor(Config.RebirthBonusStep * 100) .. "% за перерождение."
	local canRebirth = ready and floor >= Config.RebirthMinFloor and tier >= Config.RebirthMinTier and rebirths < Config.MaxRebirths and coins ~= nil and coins >= rebirthCost
	local rebirthText = if rebirths >= Config.MaxRebirths then "Достигнут максимум перерождений" elseif os.clock() <= rebirthConfirmedUntil then "Подтверди сброс: нажми ещё раз" else "Переродиться · " .. format(rebirthCost) .. " монет"
	setButton(rebirthButton, rebirthText, canRebirth)
	for _, entry in ipairs(passCards) do
		local owned = player:GetAttribute(if entry.key == "VIP" then "HasVIP" else "HasNeon") == true
		setButton(entry.button, if owned then "Уже принадлежит тебе" else "Открыть покупку за Robux", ready and not owned)
	end
end

local function bindStats(folder)
	for _, connection in ipairs(statsConnections) do
		connection:Disconnect()
	end
	table.clear(statsConnections)
	stats = folder
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if (child.Name == "Coins" or child.Name == "Level") and (child:IsA("IntValue") or child:IsA("NumberValue")) then
				table.insert(statsConnections, child:GetPropertyChangedSignal("Value"):Connect(update))
			end
		end
		table.insert(statsConnections, folder.ChildAdded:Connect(function()
			bindStats(folder)
		end))
		table.insert(statsConnections, folder.ChildRemoved:Connect(function()
			bindStats(folder)
		end))
	end
	update()
end

local function setShopOpen(open)
	overlay.Visible = open
	shop.Visible = open
	update()
end
local function setTab(name)
	currentTab = name
	for tabName, tab in pairs(tabs) do
		tab.list.Visible = tabName == name
		tab.button.BackgroundColor3 = if tabName == name then palette.teal else palette.card
		tab.button.TextColor3 = if tabName == name then palette.panel else palette.text
	end
	if name == "House" then
		shopIntro.Text = "Покупай этажи и генераторы на площадках твоего участка."
		shopFooter.Text = "Подойди к площадке: E на ПК, кнопка на телефоне."
	elseif name == "Heroes" then
		shopIntro.Text = "Человек-паук, Железный человек, Халк и Тор. Развивай базу, чтобы открыть их."
		shopFooter.Text = "Возьми оружие. Клик или Q на ПК; «Навык» на телефоне."
	elseif name == "Progress" then
		shopIntro.Text = "Выполняй задания, возвращайся за наградой и становись сильнее."
		shopFooter.Text = "Перед перерождением прочитай, какие улучшения сбросятся."
	else
		shopIntro.Text = "Дополнения для твоей базы и героя."
		shopFooter.Text = if #passCards > 0 then "Покупка подтверждается в стандартном окне Roblox." else "Все герои открываются через прогресс игры."
	end
	update()
end
for name, tab in pairs(tabs) do
	connect(tab.button.Activated, function() setTab(name) end)
end
setTab("House")
connect(shopButton.Activated, function()
	setShopOpen(not shop.Visible)
end)
connect(closeButton.Activated, function()
	setShopOpen(false)
end)
connect(overlay.Activated, function()
	setShopOpen(false)
end)

local watchedAttributes = {
	"Floor", "DropperTier", "Bank", "Income", "PlotId", "XP", "DataReady",
	"PersistenceMode", "PersistenceStatus", "BonusReadyAt", "Rebirths", "EquippedHero",
	"CollectedTotal", "EnemiesDefeated", "QuestCollectorDone", "QuestBuilderDone",
	"QuestFighterDone", "DailyReadyAt", "HasVIP", "HasNeon", "EquippedWeapon",
}
for _, name in ipairs(watchedAttributes) do
	connect(player:GetAttributeChangedSignal(name), update)
end
connect(player.ChildAdded, function(child)
	if child.Name == "leaderstats" then
		bindStats(child)
	end
end)
connect(player.ChildRemoved, function(child)
	if child == stats then
		bindStats(nil)
	end
end)
bindStats(player:FindFirstChild("leaderstats"))

local toastVersion = 0
local toastTween = nil
connect(notice.OnClientEvent, function(payload)
	if type(payload) ~= "table" or type(payload.text) ~= "string" then
		return
	end
	if payload.kind == "heroes" then
		setTab("Heroes")
		setShopOpen(true)
	end
	toastVersion += 1
	local version = toastVersion
	if toastTween then
		toastTween:Cancel()
	end
	toastText.Text = string.sub(payload.text, 1, 480)
	toastStroke.Color = if payload.kind == "error" then palette.red elseif payload.kind == "reward" then palette.gold else palette.teal
	toast.Visible = true
	toast.BackgroundTransparency = 0.03
	toastText.TextTransparency = 0
	task.delay(4.5, function()
		if not alive or version ~= toastVersion then
			return
		end
		toastTween = TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		toastTween:Play()
		task.wait(0.25)
		if alive and version == toastVersion then
			toast.Visible = false
		end
	end)
end)

local cameraConnection = nil
local function resize()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local dashboardScale = math.min(1, math.max(0.1, (viewport.X - 28) / 340), math.max(0.1, (viewport.Y - 160) / 326))
	hudScale.Scale = dashboardScale
	guideScale.Scale = dashboardScale
	guide.Position = UDim2.fromOffset(14, 12 + 244 * dashboardScale)
	local modalScale = math.min(1, math.max(0.1, (viewport.X - 28) / 320))
	shopScale.Scale = modalScale
	-- On a phone in landscape, shorten the scrolling area instead of
	-- shrinking every label and touch target to an unreadable size.
	shop.Size = UDim2.fromOffset(math.min(500, (viewport.X - 28) / modalScale), math.min(610, math.max(250, (viewport.Y - 90) / modalScale)))
	toastScale.Scale = math.min(1, math.max(0.1, (viewport.X - 28) / 380))
	toast.Position = if viewport.X > 780 then UDim2.new(0.5, 0, 0, 16) else UDim2.new(0.5, 0, 0, 12 + 330 * dashboardScale)
end

local function bindCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	end
	resize()
end
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)
bindCamera()

local function cleanup()
	if not alive then
		return
	end
	alive = false
	if toastTween then
		toastTween:Cancel()
	end
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	for _, connection in ipairs(statsConnections) do
		connection:Disconnect()
	end
	runtime:Destroy()
end
connect(stopEvent.Event, cleanup)
connect(script.Destroying, cleanup)

-- The only timer updates the third-floor countdown; it never awards anything.
task.spawn(function()
	while alive do
		task.wait(1)
		if alive and shop.Visible then
			update()
		end
	end
end)
