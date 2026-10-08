-- HUD and shop guide. Purchases and rewards always belong to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("TycoonConfig"))
local Theme = require(Shared:WaitForChild("UITheme"))
local scope = Theme.Scope()
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
gui.DisplayOrder = 30

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

local palette = Theme.Colors
local function make(className, properties, parent)
 local object = Theme.Make(className, properties, parent)
 if className == "TextButton" then Theme.DecorateButton(scope, object) end
 return object
end
local function corner(object, radius) Theme.Round(object, radius) end
local function label(parent, name, text, size, position, fontSize, color)
 return Theme.Label(parent, name, text, size, position, fontSize, color)
end

-- Compact top wallet and bottom dock leave the city and touch controls visible.
local hud = make("Frame", {Name = "Dashboard", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0}, runtime)
local wallet = make("Frame", {Name = "Wallet", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(350, 80), BackgroundColor3 = palette.panel, BackgroundTransparency = 0.05, BorderSizePixel = 0}, hud)
Theme.Surface(wallet, 18)
local hudScale = make("UIScale", {Scale = 1}, wallet)
Theme.Icon(wallet, "coin", palette.gold, UDim2.fromOffset(25, 25), UDim2.fromOffset(14, 12))
local coinsText = label(wallet, "Coins", "Загрузка…", UDim2.fromOffset(198, 34), UDim2.fromOffset(48, 6), 22, palette.gold)
coinsText.TextScaled = true
make("UITextSizeConstraint", {MinTextSize = 14, MaxTextSize = 22}, coinsText)
local levelText = label(wallet, "Level", "УР. …", UDim2.fromOffset(86, 32), UDim2.fromOffset(252, 7), 15)
local xpText = label(wallet, "XP", "0 / 100 XP", UDim2.fromOffset(208, 18), UDim2.fromOffset(16, 43), 11, palette.muted)
local savingBadge = label(wallet, "Saving", "Загрузка", UDim2.fromOffset(109, 18), UDim2.fromOffset(225, 43), 10, palette.muted)
savingBadge.TextXAlignment = Enum.TextXAlignment.Right
local xpTrack = make("Frame", {Name = "XPTrack", Position = UDim2.fromOffset(16, 67), Size = UDim2.fromOffset(318, 5), BackgroundColor3 = palette.card, BorderSizePixel = 0}, wallet)
corner(xpTrack, 3)
local xpFill = make("Frame", {Name = "XPFill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = palette.teal, BorderSizePixel = 0}, xpTrack)
corner(xpFill, 3)
local vitality = make("Frame", {Name = "Vitality", AnchorPoint = Vector2.new(.5, 1), Position = UDim2.new(.5, 0, 1, -146), Size = UDim2.fromOffset(274, 44), BackgroundColor3 = palette.panel, BackgroundTransparency = .14, BorderSizePixel = 0}, hud)
Theme.Surface(vitality, 13)
Theme.Icon(vitality, "health", palette.red, UDim2.fromOffset(15, 15), UDim2.fromOffset(12, 9))
local healthText = label(vitality, "Health", "100 HP", UDim2.fromOffset(93, 20), UDim2.fromOffset(33, 6), 11, palette.teal)
local skillText = label(vitality, "Ability", "Выбери костюм", UDim2.fromOffset(142, 20), UDim2.fromOffset(123, 6), 11, palette.muted)
skillText.TextXAlignment = Enum.TextXAlignment.Right
local healthTrack = make("Frame", {Name = "HealthTrack", Position = UDim2.fromOffset(12, 31), Size = UDim2.new(1, -24, 0, 4), BackgroundColor3 = palette.card, BorderSizePixel = 0}, vitality)
corner(healthTrack, 3)
local healthFill = make("Frame", {Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = palette.teal, BorderSizePixel = 0}, healthTrack)
corner(healthFill, 3)
local shopButton = Theme.Button(scope, hud, "ShopButton", "База", UDim2.fromOffset(88, 44), UDim2.new(.5, -96, 1, -88))
shopButton.AnchorPoint = Vector2.new(.5, 1)
shopButton.TextXAlignment = Enum.TextXAlignment.Right
make("UIPadding", {PaddingRight = UDim.new(0, 12)}, shopButton)
Theme.Icon(shopButton, "house", palette.teal, UDim2.fromOffset(20, 20), UDim2.fromOffset(8, 12))
local settingsButton = Theme.Button(scope, hud, "SettingsButton", "Меню", UDim2.fromOffset(88, 44), UDim2.new(.5, 96, 1, -88))
settingsButton.AnchorPoint = Vector2.new(.5, 1)
settingsButton.TextXAlignment = Enum.TextXAlignment.Right
make("UIPadding", {PaddingRight = UDim.new(0, 10)}, settingsButton)
Theme.Icon(settingsButton, "settings", palette.blue, UDim2.fromOffset(18, 18), UDim2.fromOffset(7, 13))
local damageVeil = make("Frame", {Name = "DamageFeedback", Size = UDim2.fromScale(1, 1), BackgroundColor3 = palette.red, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4}, runtime)

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
Theme.Surface(shop, 20, palette.teal)
local shopScale = {Scale = 1}
label(shop, "Title", "Квартал", UDim2.new(1, -84, 0, 30), UDim2.fromOffset(20, 16), 22, palette.teal)
local shopIntro = label(shop, "Intro", "Дом, костюмы и награды — всё здесь.", UDim2.new(1, -40, 0, 32), UDim2.fromOffset(20, 50), 13, palette.muted)
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
local tabDefinitions = { { "House", "База" }, { "Heroes", "Герои" }, { "Progress", "Цели" }, { "Style", "Стиль" } }
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

local _, _, statusCard = shopCard("BaseStatus", 0, 185)
statusCard.Title.Text = "ТВОЙ КВАРТАЛ"
statusCard.Detail:Destroy()
local houseText = label(statusCard, "House", "", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 37), 14)
local bankText = label(statusCard, "Bank", "", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 61), 13, palette.blue)
local heroText = label(statusCard, "Hero", "", UDim2.new(1, -28, 0, 32), UDim2.fromOffset(14, 85), 12, palette.teal)
local saveText = label(statusCard, "SaveStatus", "", UDim2.new(1, -28, 0, 26), UDim2.fromOffset(14, 119), 11, palette.muted)
local guideText = label(statusCard, "Instructions", "", UDim2.new(1, -28, 0, 32), UDim2.fromOffset(14, 146), 11, palette.muted)
local floorTitle, floorDetail, floorCard = shopCard("FloorUpgrade", 1, 176)
local dropperTitle, dropperDetail, dropperCard = shopCard("GeneratorUpgrade", 2, 176)
local bonusTitle, bonusDetail, bonusCard = shopCard("ThirdFloorBonus", 3, 200)
floorDetail.Size = UDim2.new(1, -28, 0, 68)
dropperDetail.Size = UDim2.new(1, -28, 0, 68)
bonusDetail.Size = UDim2.new(1, -28, 0, 94)
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

local function setButton(button, text, enabled, accent)
	Theme.SetButton(button, text, enabled, accent)
end

local navigation = {}
local navigationSerial = 0
local function clearNavigation()
	for _, object in ipairs(navigation) do object:Destroy() end
	table.clear(navigation)
end
local function ownedPlot()
	local plots = Workspace:FindFirstChild("TycoonPlots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			if plot:GetAttribute("OwnerUserId") == player.UserId then return plot end
		end
	end
	return nil
end
local function showPad(name, text, color)
	local plot = ownedPlot()
	local pad = plot and plot:FindFirstChild(name)
	if not pad or not pad:IsA("BasePart") then return end
	Theme.CloseAll()
	clearNavigation()
	navigationSerial += 1
	local serial = navigationSerial
	table.insert(navigation, make("Highlight", {Name = "QuarterNavigation", Adornee = pad, FillColor = color, OutlineColor = palette.text, FillTransparency = .55, OutlineTransparency = .1, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, Workspace))
	local arrow = make("BillboardGui", {Name = "QuarterWaypoint", Adornee = pad, Size = UDim2.fromOffset(180, 42), StudsOffset = Vector3.new(0, 4, 0), AlwaysOnTop = true, MaxDistance = 600}, playerGui)
	table.insert(navigation, arrow)
	local message = label(arrow, "Destination", text, UDim2.fromScale(1, 1), UDim2.new(), 15, color)
	message.TextXAlignment = Enum.TextXAlignment.Center
	task.delay(9, function() if alive and navigationSerial == serial then clearNavigation() end end)
end
local floorWaypoint = actionButton(floorCard, "FindFloor", function() showPad("UpgradePad", "СТРОИТЕЛЬСТВО · E", palette.blue) end)
local generatorWaypoint = actionButton(dropperCard, "FindGenerator", function() showPad("DropperUpgradePad", "ГЕНЕРАТОР · E", palette.teal) end)
local bonusWaypoint = actionButton(bonusCard, "FindBonus", function() showPad("BonusPad", "БОНУСЫ · E", palette.gold) end)

local heroCards = {}
for index, hero in ipairs(Config.Heroes or {}) do
	local title, detail, card = shopCard("Hero_" .. hero.Id, index, 192, tabs.Heroes.list)
	title.Text = hero.Name
 Theme.HeroArt(card, hero, UDim2.fromOffset(14, 42), UDim2.fromOffset(64, 64))
	title.TextScaled = true
	make("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 16 }, title)
	local color = hero.Color
	if type(color) == "table" then title.TextColor3 = Color3.fromRGB(color[1], color[2], color[3]) end
	detail.Size = UDim2.new(1, -106, 0, 98)
 detail.Position = UDim2.fromOffset(92, 40)
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
		local state = questState[id] or {progress = quest.Field, done = "Quest_" .. id}
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

local achievementCards = {}
for index, achievement in ipairs(Config.Achievements or {}) do
	local title, detail, card = shopCard("Achievement_" .. achievement.Id, 20 + index, 174, tabs.Progress.list)
	title.Text = achievement.Title
	title.TextColor3 = palette.blue
	detail.Size = UDim2.new(1, -28, 0, 74)
	local button = actionButton(card, "Claim", function() request("ClaimAchievement", achievement.Id) end)
	table.insert(achievementCards, {definition = achievement, detail = detail, button = button})
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
local titleCards = {}
local hideTitleButton
for index, achievement in ipairs(Config.Achievements or {}) do
	if type(achievement.TitleReward) == "string" then
		local title, detail, card = shopCard("Title_" .. achievement.Id, index, 166, tabs.Style.list)
		title.Text = achievement.TitleReward
		title.TextColor3 = palette.blue
		detail.Size = UDim2.new(1, -28, 0, 66)
		detail.Text = "Косметический титул над персонажем.\nДостижение: «" .. achievement.Title .. "»."
		local button = actionButton(card, "EquipTitle", function() request("EquipTitle", achievement.Id) end)
		table.insert(titleCards, {definition = achievement, button = button})
	end
end
if #titleCards > 0 then
	local title, detail, card = shopCard("HideTitle", 20, 126, tabs.Style.list)
	title.Text = "Без титула"
	detail.Size = UDim2.new(1, -28, 0, 28)
	detail.Text = "Оставить только имя персонажа."
	hideTitleButton = actionButton(card, "Hide", function() request("EquipTitle", "") end)
end
for _, key in ipairs({ "VIP", "Neon" }) do
	local definition = Config.GamePasses and Config.GamePasses[key]
	-- Unconfigured purchases have no button or product entry in the game.
	if definition and type(definition.Id) == "number" and definition.Id > 0 then
		local title, detail, card = shopCard("Pass_" .. key, 30 + #passCards, 180, tabs.Style.list)
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
	local title, detail = shopCard("StyleInfo", 40, 116, tabs.Style.list)
	title.Text = "Твой стиль — твой герой"
	detail.Text = "Меняй героев во вкладке «Герои». Их оружие и способности открываются через строительство и перерождения."
end

-- Local display preferences never change damage, rewards or multiplayer time.
if player:GetAttribute("EffectsQuality") == nil then
	player:SetAttribute("EffectsQuality", if game:GetService("UserInputService").TouchEnabled then "Low" else "High")
end
if player:GetAttribute("SoundEnabled") == nil then player:SetAttribute("SoundEnabled", true) end
local settingsBackdrop = make("TextButton", {Name = "SettingsBackdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = palette.shade, BackgroundTransparency = 1, Text = "", Visible = false, ZIndex = 14}, runtime)
local settingsPanel = make("Frame", {Name = "SettingsPanel", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(420, 480), BackgroundColor3 = palette.panel, BorderSizePixel = 0, Visible = false, ZIndex = 15}, runtime)
Theme.Surface(settingsPanel, 20, palette.blue)
label(settingsPanel, "Title", "МЕНЮ ИГРЫ", UDim2.new(1, -80, 0, 34), UDim2.fromOffset(20, 14), 21, palette.blue)
local settingsClose = Theme.Button(scope, settingsPanel, "Close", "×", UDim2.fromOffset(44, 44), UDim2.new(1, -56, 0, 10))
settingsClose.TextSize = 26
local settingsList = make("ScrollingFrame", {Name = "Preferences", Position = UDim2.fromOffset(20, 65), Size = UDim2.new(1, -40, 1, -140), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = palette.blue, ZIndex = 16}, settingsPanel)
make("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, settingsList)
local pauseCard = make("Frame", {Name = "MultiplayerStatus", Size = UDim2.new(1, -6, 0, 74), LayoutOrder = 1, BackgroundColor3 = palette.card, BorderSizePixel = 0, ZIndex = 17}, settingsList)
corner(pauseCard, 12)
label(pauseCard, "Notice", "Сервер продолжает работать. В меню бой не останавливается — перед настройками выйди из арены.", UDim2.new(1, -24, 1, -16), UDim2.fromOffset(12, 8), 13, palette.gold)
local graphicsButton = Theme.Button(scope, settingsList, "Quality", "", UDim2.new(1, -6, 0, 52), nil, palette.blue)
graphicsButton.LayoutOrder = 2
local qualityDescription = label(settingsList, "QualityHelp", "", UDim2.new(1, -8, 0, 52), UDim2.new(), 12, palette.muted)
qualityDescription.LayoutOrder = 3
local soundButton = Theme.Button(scope, settingsList, "Sound", "", UDim2.new(1, -6, 0, 52), nil, palette.teal)
soundButton.LayoutOrder = 4
local ownerButton = Theme.Button(scope, settingsList, "OwnerPanel", "Панель владельца", UDim2.new(1, -6, 0, 48), nil, palette.gold)
ownerButton.LayoutOrder = 5
ownerButton.Visible = player:GetAttribute("IsGameAdmin") == true
connect(ownerButton.Activated, function()
	if player:GetAttribute("IsGameAdmin") == true then Theme.OpenModal("Admin") end
end)
connect(player:GetAttributeChangedSignal("IsGameAdmin"), function() ownerButton.Visible = player:GetAttribute("IsGameAdmin") == true end)
local controlsHelp = label(settingsList, "Controls", "ПК: M — база, I — арсенал, P — меню, Q — навык.\nГеймпад: Y — база, ↑ — арсенал, ← — меню, X — навык, B — закрыть.\nТелефон: кнопки на экране. Настройки действуют в этой сессии.", UDim2.new(1, -8, 0, 110), UDim2.new(), 12, palette.muted)
controlsHelp.LayoutOrder = 6
local resumeButton = Theme.Button(scope, settingsPanel, "Resume", "Вернуться в игру", UDim2.new(1, -40, 0, 46), UDim2.new(0, 20, 1, -60), palette.teal)
local function updateSettings()
	local quality = player:GetAttribute("EffectsQuality")
	local qualityNames = {High = "Высокое", Low = "Низкое", Off = "Выключены"}
	graphicsButton.Text = "Эффекты: " .. (qualityNames[quality] or qualityNames.High)
	qualityDescription.Text = if quality == "Off" then "Декоративные эффекты выключены. Предупреждения об атаках остаются видны." elseif quality == "Low" then "Меньше частиц и декоративных объектов — удобно для телефона." else "Полные эффекты способностей, генераторов и наград."
	soundButton.Text = "Звуки действий: " .. (if player:GetAttribute("SoundEnabled") == true then "включены" else "выключены")
end
connect(graphicsButton.Activated, function()
	local nextQuality = {High = "Low", Low = "Off", Off = "High"}
	player:SetAttribute("EffectsQuality", nextQuality[player:GetAttribute("EffectsQuality")] or "High")
end)
connect(soundButton.Activated, function() player:SetAttribute("SoundEnabled", player:GetAttribute("SoundEnabled") ~= true) end)
connect(player:GetAttributeChangedSignal("EffectsQuality"), updateSettings)
connect(player:GetAttributeChangedSignal("SoundEnabled"), updateSettings)
updateSettings()
local settingsModal = Theme.RegisterModal("Settings", settingsPanel, settingsBackdrop, nil, graphicsButton)
connect(settingsButton.Activated, function() if player:GetAttribute("ObbyActive") ~= true then settingsModal:Toggle() end end)
connect(settingsClose.Activated, function() settingsModal:Close() end)
connect(resumeButton.Activated, function() settingsModal:Close() end)
connect(settingsBackdrop.Activated, function() settingsModal:Close() end)
Theme.Shortcut(scope, Enum.KeyCode.P, Enum.KeyCode.DPadLeft, function() if player:GetAttribute("ObbyActive") ~= true then settingsModal:Toggle() end end)

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
	coinsText.Text = coins and format(coins) or "Загрузка…"
	levelText.Text = level and ("УР. " .. format(level)) or "УР. …"
	xpText.Text = format(attribute("XP") % 100) .. " / 100 XP"
	scope:Tween(xpFill, .2, {Size = UDim2.fromScale((attribute("XP") % 100) / 100, 1)})
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local health = humanoid and math.ceil(humanoid.Health) or 0
	healthText.Text = health .. " HP"
	healthText.TextColor3 = if health <= 30 then palette.red else palette.teal
 healthFill.BackgroundColor3 = healthText.TextColor3
 scope:Tween(healthFill, .15, {Size = UDim2.fromScale(if humanoid and humanoid.MaxHealth > 0 then math.clamp(health / humanoid.MaxHealth, 0, 1) else 0, 1)})
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

 savingBadge.Text = if status == "error" then "Ошибка записи" elseif mode == "session" or status == "session" then "Без сохранения" elseif not player:GetAttribute("DataReady") then "Загрузка…" elseif status == "saving" then "Сохраняем…" else "Автосохранение"
 savingBadge.TextColor3 = saveText.TextColor3

	if not player:GetAttribute("DataReady") then
		guideText.Text = "Подожди загрузки прогресса. Если появилась ошибка — смотри уведомление."
	elseif plotId == 0 then
		guideText.Text = "Займи участок: зелёная площадка → E на ПК или кнопка на телефоне."
	elseif floor == 0 then
		guideText.Text = "Построй первый этаж: подойди к синей площадке. Цена: " .. format(Config.Floors[1].Cost) .. " монет."
	elseif floor < 3 then
		guideText.Text = "Собирай зелёную кассу, строй этажи. Наступи на стенд костюма и сражайся на арене."
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
	setButton(floorWaypoint, if plotId == 0 then "Сначала займи участок" else "Показать площадку", player:GetAttribute("DataReady") == true and plotId > 0, palette.blue)

	local nextCost = Config.DropperCosts[tier + 1]
	if nextCost then
		local upgrade = Config.GeneratorUpgrades and Config.GeneratorUpgrades[tier + 1]
		dropperTitle.Text = (upgrade and upgrade.Name or "Генератор " .. (tier + 1)) .. " · " .. format(nextCost)
		dropperDetail.Text = (upgrade and upgrade.Description or "Увеличивает доход всех этажей.") .. "\nФиолетовая площадка на твоём участке."
		if floor == 0 then
			dropperDetail.Text = "Сначала построй первый этаж, затем улучшай генератор на фиолетовой площадке."
		end
	else
		dropperTitle.Text = "Генератор улучшен до максимума"
		dropperDetail.Text = "Твой дом получает максимальный доход. Не забывай собирать деньги из зелёной кассы."
	end
	setButton(generatorWaypoint, if floor == 0 then "Сначала построй первый этаж" else "Показать генератор", player:GetAttribute("DataReady") == true and plotId > 0 and floor > 0, palette.teal)

	bonusTitle.Text = "Плюшки третьего этажа"
	local bonusReadyAt = player:GetAttribute("BonusReadyAt")
	local seconds = if type(bonusReadyAt) == "number" then math.max(0, math.ceil(bonusReadyAt - Workspace:GetServerTimeNow())) else 0
	local bonusState = if floor < 3 then "Откроется после постройки третьего этажа." elseif seconds > 0 then ("Следующая раздача через " .. seconds .. " сек.") else "Раздача готова: открой сундук на третьем этаже!"
	bonusDetail.Text = "Золотой генератор, скорость " .. Config.ThirdFloorWalkSpeed .. " и +" .. format(Config.BonusCoins) .. " монет раз в " .. Config.BonusCooldown .. " сек.\n" .. bonusState
	setButton(bonusWaypoint, if floor < 3 then "Нужен третий этаж" else "Показать бонусы", player:GetAttribute("DataReady") == true and plotId > 0 and floor >= 3, palette.gold)

	local ready = player:GetAttribute("DataReady") == true
	local heroProfile = { Floor = floor, Rebirths = rebirths }
	for _, entry in ipairs(heroCards) do
		local hero = entry.hero
		local unlocked = Config.CanUseHero(heroProfile, hero)
		local required = "Этаж " .. hero.MinFloor
		if hero.MinRebirths > 0 then required ..= " · перерождений: " .. hero.MinRebirths end
		entry.detail.Text = required .. "\nУрон " .. hero.Damage .. " · " .. hero.Cooldown .. " сек.\nДальность " .. hero.Range .. "\n" .. hero.Weapon
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
		local syncedProgress = player:GetAttribute("QuestProgress_" .. entry.quest.Id)
		local progress = math.min(entry.quest.Target, if type(syncedProgress) == "number" then number(syncedProgress) else attribute(entry.state.progress or ""))
		if entry.quest.Id == "builder" and rebirths > 0 then progress = entry.quest.Target end
		local done = player:GetAttribute("Quest_" .. entry.quest.Id) == true or player:GetAttribute(entry.state.done) == true
		entry.detail.Text = "Прогресс: " .. format(progress) .. "/" .. format(entry.quest.Target) .. "\nНаграда: " .. format(entry.quest.RewardCoins) .. " монет · " .. format(entry.quest.RewardXP) .. " XP"
		setButton(entry.button, if done then "Награда получена" elseif progress >= entry.quest.Target then "Забрать награду" else "Выполни задание", ready and not done and progress >= entry.quest.Target)
	end
	for _, entry in ipairs(achievementCards) do
		local definition = entry.definition
		local syncedProgress = player:GetAttribute("AchievementProgress_" .. definition.Id)
		local progress = math.min(definition.Target, if type(syncedProgress) == "number" then number(syncedProgress) else attribute(definition.Field))
		if definition.Field == "Floor" and rebirths > 0 then progress = definition.Target end
		local claimed = player:GetAttribute("Achievement_" .. definition.Id) == true
		entry.detail.Text = definition.Description .. "\n" .. format(progress) .. "/" .. format(definition.Target) .. " · +" .. format(definition.RewardCoins) .. " монет · " .. format(definition.RewardXP) .. " XP" .. (if definition.TitleReward then "\nТитул: " .. definition.TitleReward else "")
		setButton(entry.button, if claimed then "Достижение получено" elseif progress >= definition.Target then "Забрать награду" else "Продолжай играть", ready and not claimed and progress >= definition.Target)
	end
	local dailySeconds = math.max(0, math.ceil(attribute("DailyReadyAt") - Workspace:GetServerTimeNow()))
	local remainingMinutes = math.ceil(dailySeconds / 60)
	local dailyHours = math.floor(remainingMinutes / 60)
	local dailyMinutes = remainingMinutes % 60
	local dailyReward = player:GetAttribute("DailyNextReward") or Config.DailyReward
	dailyDetail.Text = "+" .. format(dailyReward) .. " монет · серия " .. attribute("DailyStreak") .. " / 7 дней.\n" .. (if dailySeconds > 0 then ("Следующая награда через " .. dailyHours .. " ч " .. dailyMinutes .. " мин.") else "Награда готова! Возвращайся каждый день.")
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
	for _, entry in ipairs(titleCards) do
		local selected = player:GetAttribute("EquippedTitle") == entry.definition.Id
		local unlocked = player:GetAttribute("Achievement_" .. entry.definition.Id) == true
		setButton(entry.button, if selected then "Титул выбран" elseif not unlocked then "Получи достижение" else "Надеть титул", ready and unlocked and not selected, palette.blue)
	end
	if hideTitleButton then
		local equipped = player:GetAttribute("EquippedTitle")
		setButton(hideTitleButton, "Скрыть титул", ready and type(equipped) == "string" and equipped ~= "")
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

local shopModal = Theme.RegisterModal("Base", shop, overlay, nil, closeButton)
local function setShopOpen(open)
	if open and player:GetAttribute("ObbyActive") ~= true then shopModal:Open() else shopModal:Close() end
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
		shopIntro.Text = "Строй базу, открывай костюмы и выбирай свой стиль боя."
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
	setShopOpen(not shopModal.open)
end)
Theme.Shortcut(scope, Enum.KeyCode.M, Enum.KeyCode.ButtonY, function() setShopOpen(not shopModal.open) end)
local function updateHudVisibility()
	local modal = playerGui:GetAttribute("QuarterModalOpen")
	hud.Visible = player:GetAttribute("ObbyActive") ~= true and (modal == nil or modal == "")
	if player:GetAttribute("ObbyActive") == true then Theme.CloseAll() end
end
connect(player:GetAttributeChangedSignal("ObbyActive"), updateHudVisibility)
connect(playerGui:GetAttributeChangedSignal("QuarterModalOpen"), updateHudVisibility)
updateHudVisibility()
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
	"QuestFighterDone", "DailyReadyAt", "HasVIP", "HasNeon", "EquippedWeapon", "DailyStreak", "DailyNextReward", "BossDefeated", "ObbyWins", "AttackReadyAt", "EquippedTitle",
}
for _, entry in ipairs(achievementCards) do
	table.insert(watchedAttributes, "Achievement_" .. entry.definition.Id)
	table.insert(watchedAttributes, "AchievementProgress_" .. entry.definition.Id)
end
for _, entry in ipairs(questCards) do
	table.insert(watchedAttributes, "Quest_" .. entry.quest.Id)
	table.insert(watchedAttributes, "QuestProgress_" .. entry.quest.Id)
end
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
local toastTargetY = 98
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
	playerGui:SetAttribute("QuarterToastOpen", true)
	toast.BackgroundTransparency = .45
	toastText.TextTransparency = 0
	toast.Position = UDim2.new(.5, 0, 0, toastTargetY - 10)
	scope:Tween(toast, .16, {Position = UDim2.new(.5, 0, 0, toastTargetY), BackgroundTransparency = .03})
	task.delay(4.5, function()
		if not alive or version ~= toastVersion then
			return
		end
		toastTween = TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		toastTween:Play()
		task.wait(0.25)
		if alive and version == toastVersion then
			toast.Visible = false
			playerGui:SetAttribute("QuarterToastOpen", false)
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
	hudScale.Scale = math.min(1, math.max(0.1, (viewport.X - 28) / 350))
	shopScale.Scale = 1
	-- On a phone in landscape, shorten the scrolling area instead of
	-- shrinking every label and touch target to an unreadable size.
	shop.Size = UDim2.fromOffset(math.min(500, math.max(260, viewport.X - 28)), math.min(610, math.max(230, viewport.Y - 80)))
	settingsPanel.Size = UDim2.fromOffset(math.min(420, math.max(260, viewport.X - 28)), math.min(480, math.max(230, viewport.Y - 80)))
	local compact = shop.Size.Y.Offset < 420
	shopIntro.Visible = not compact
	for index, definition in ipairs(tabDefinitions) do
		local tab = tabs[definition[1]]
		tab.button.Position = UDim2.new((index - 1) * 0.25, 20 - (index - 1) * 8, 0, if compact then 58 else 90)
		tab.list.Position = UDim2.fromOffset(20, if compact then 108 else 148)
		tab.list.Size = UDim2.new(1, -40, 1, if compact then -154 else -208)
	end
	shopFooter.Position = UDim2.new(0, 20, 1, if compact then -40 else -48)
	shopFooter.Size = UDim2.new(1, -40, 0, if compact then 28 else 38)
	toastScale.Scale = math.min(1, math.max(0.1, (viewport.X - 28) / 380))
	local tutorialActive = attribute("TutorialStep") > 0 and attribute("TutorialStep") < 7
	local toastHeight = if viewport.Y < 440 then 44 else 64
	local modal = playerGui:GetAttribute("QuarterModalOpen")
	toastTargetY = if type(modal) == "string" and modal ~= "" then viewport.Y - toastHeight - 10 elseif player:GetAttribute("ObbyActive") then 194 elseif tutorialActive and viewport.Y >= 440 then 172 else 98
	toast.Position = UDim2.new(.5, 0, 0, toastTargetY)
	toast.Size = UDim2.fromOffset(380, toastHeight)
	vitality.Visible = viewport.Y >= 420
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

local healthConnection = nil
local previousHealth = nil
local function bindHealth(character)
	if healthConnection then healthConnection:Disconnect(); healthConnection = nil end
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if alive and humanoid and player.Character == character then
			previousHealth = humanoid.Health
			healthConnection = humanoid.HealthChanged:Connect(function(health)
				if previousHealth and health < previousHealth then
					damageVeil.BackgroundTransparency = .9
					scope:Tween(damageVeil, .35, {BackgroundTransparency = 1})
				end
				previousHealth = health
				update()
			end)
			update()
		end
	end)
end
connect(player.CharacterAdded, bindHealth)
if player.Character then bindHealth(player.Character) end

local function cleanup()
	if not alive then
		return
	end
	alive = false
 playerGui:SetAttribute("QuarterToastOpen", false)
 clearNavigation()
 shopModal:Destroy()
 settingsModal:Destroy()
 scope:Destroy()
	if healthConnection then healthConnection:Disconnect() end
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
connect(runtime.Destroying, cleanup)

-- The only timer updates the third-floor countdown; it never awards anything.
local function updateCooldown()
	local readyAt = player:GetAttribute("AttackReadyAt")
	local seconds = if type(readyAt) == "number" then math.max(0, readyAt - Workspace:GetServerTimeNow()) else 0
	local hero = player:GetAttribute("EquippedHero")
	local weapon = player:GetAttribute("EquippedWeapon")
	local hasWeapon = (type(hero) == "string" and hero ~= "") or (type(weapon) == "string" and weapon ~= "")
	local inArena = player:GetAttribute("ArenaCombatOptIn") == true
	skillText.Text = if not hasWeapon then "Выбери оружие" elseif not inArena then "Войди на арену" elseif seconds > 0 then string.format("Навык · %.1f с", seconds) else "Готов · Q / X"
	skillText.TextColor3 = if seconds > 0 or not inArena then palette.muted else palette.teal
	if not vitality.Visible then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local health = humanoid and math.ceil(humanoid.Health) or 0
		xpText.Text = (attribute("XP") % 100) .. "/100 XP · " .. health .. " HP"
		if hasWeapon and inArena then xpText.Text ..= " · " .. (if seconds > 0 then string.format("%.1fс", seconds) else "готов") end
		xpText.TextColor3 = if health <= 30 then palette.red else palette.muted
	else
		xpText.TextColor3 = palette.muted
	end
end
connect(player:GetAttributeChangedSignal("AttackReadyAt"), updateCooldown)
connect(player:GetAttributeChangedSignal("TutorialStep"), resize)
connect(player:GetAttributeChangedSignal("ObbyActive"), resize)
connect(playerGui:GetAttributeChangedSignal("QuarterModalOpen"), resize)
task.spawn(function()
	local nextStatsAt = 0
	while alive do
		task.wait(.1)
		if not alive then break end
		updateCooldown()
		-- Countdown text changes once per second, independent of rendering.
		if os.clock() < nextStatsAt then continue end
		nextStatsAt = os.clock() + 1
		if alive and shop.Visible then
			update()
		end
	end
end)
