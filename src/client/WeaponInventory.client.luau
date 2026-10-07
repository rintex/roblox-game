-- Инвентарь показывает серверный профиль. Клиент лишь просит экипировать известное оружие.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:FindFirstChild("WeaponInventoryHUD")
if gui and not gui:IsA("ScreenGui") then
	warn("WeaponInventoryHUD должен быть ScreenGui.")
	return
end
if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "WeaponInventoryHUD"
	gui.Parent = playerGui
end
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 22
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Повторный запуск останавливает старые анимации и обработчики.
local oldRuntime = gui:FindFirstChild("WeaponInventoryRuntime")
if oldRuntime then
	local oldStop = oldRuntime:FindFirstChild("Stop")
	if oldStop and oldStop:IsA("BindableEvent") then oldStop:Fire() end
	oldRuntime:Destroy()
end
local runtime = Instance.new("Frame")
runtime.Name = "WeaponInventoryRuntime"
runtime.Size = UDim2.fromScale(1, 1)
runtime.BackgroundTransparency = 1
runtime.Parent = gui
local stopEvent = Instance.new("BindableEvent")
stopEvent.Name = "Stop"
stopEvent.Parent = runtime

local alive = true
local connections = {}
local animationSerial = 0
local activeTween = nil
local pendingResult = nil
local actionRemote = nil
local inventory = {}
local cards = {}
local lastEquipRequest = -math.huge

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function cancelAnimation()
	animationSerial += 1
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

local function cleanup()
	if not alive then return end
	alive = false
	cancelAnimation()
	pendingResult = nil
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
	runtime:Destroy()
end
connect(stopEvent.Event, cleanup)
connect(script.Destroying, cleanup)
connect(runtime.Destroying, cleanup)

local shared = ReplicatedStorage:WaitForChild("Shared", 30)
if not alive then return end
local configModule = shared and shared:WaitForChild("TycoonConfig", 30)
if not alive then return end
if not configModule or not configModule:IsA("ModuleScript") then
	warn("Для инвентаря не найден Shared/TycoonConfig.")
	cleanup()
	return
end
local Config = require(configModule)
if not alive then return end

local palette = {
	panel = Color3.fromRGB(24, 31, 44),
	card = Color3.fromRGB(37, 46, 62),
	text = Color3.fromRGB(243, 248, 255),
	muted = Color3.fromRGB(172, 189, 209),
	teal = Color3.fromRGB(97, 231, 191),
}
local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do object[key] = value end
	object.Parent = parent
	return object
end
local function corner(object, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, object)
end
local function label(parent, name, text, size, position, textSize, color)
	return make("TextLabel", {
		Name = name, Size = size, Position = position, BackgroundTransparency = 1,
		Text = text, TextColor3 = color or palette.text, TextSize = textSize,
		Font = Enum.Font.GothamMedium, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = parent.ZIndex + 1,
	}, parent)
end
local function button(parent, name, text, size, position)
	local object = make("TextButton", {
		Name = name, Size = size, Position = position, BackgroundColor3 = palette.card,
		BorderSizePixel = 0, Text = text, TextColor3 = palette.text, TextSize = 15,
		Font = Enum.Font.GothamBold, AutoButtonColor = true, ZIndex = parent.ZIndex + 2,
	}, parent)
	corner(object, 10)
	return object
end
local function weaponColor(weapon)
	return Color3.fromRGB(weapon.Color[1], weapon.Color[2], weapon.Color[3])
end

local openButton = button(runtime, "InventoryButton", "Арсенал", UDim2.fromOffset(132, 44), UDim2.new(0.5, 72, 1, -88))
openButton.AnchorPoint = Vector2.new(0.5, 1)
openButton.BackgroundColor3 = palette.panel
make("UIStroke", { Color = palette.teal, Transparency = 0.25 }, openButton)

local backdrop = button(runtime, "Backdrop", "", UDim2.fromScale(1, 1), UDim2.new())
backdrop.BackgroundColor3 = Color3.fromRGB(5, 11, 22)
backdrop.BackgroundTransparency = 0.25
backdrop.AutoButtonColor = false
backdrop.ZIndex = 10
backdrop.Visible = false

local panel = make("Frame", {
	Name = "InventoryPanel", Size = UDim2.fromOffset(360, 400),
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = palette.panel, BorderSizePixel = 0, Visible = false, ZIndex = 11,
}, runtime)
corner(panel, 18)
label(panel, "Title", "АРСЕНАЛ", UDim2.new(1, -80, 0, 30), UDim2.fromOffset(16, 12), 20, palette.teal)
local closeButton = button(panel, "Close", "×", UDim2.fromOffset(44, 44), UDim2.new(1, -54, 0, 8))
closeButton.TextSize = 26
label(panel, "Explanation", "Найди оружие в ящике и улучши его за монеты.", UDim2.new(1, -32, 0, 38), UDim2.fromOffset(16, 48), 13, palette.muted)
local inventoryStatus = label(panel, "Status", "Загрузка коллекции…", UDim2.new(1, -32, 0, 26), UDim2.fromOffset(16, 87), 13, palette.teal)
local list = make("ScrollingFrame", {
	Name = "WeaponList", Position = UDim2.fromOffset(16, 122), Size = UDim2.new(1, -32, 1, -138),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
	ScrollBarImageColor3 = palette.teal, ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 12,
}, panel)
make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local function sendAction(command, id)
	if not alive or player:GetAttribute("DataReady") ~= true or not actionRemote or not actionRemote.Parent then return end
	local now = os.clock()
	if now - lastEquipRequest < 0.4 then return end
	lastEquipRequest = now
	actionRemote:FireServer(command, id)
end
local function weaponCard(name, order, title, rarity, color)
	local card = make("Frame", {Name = name, Size = UDim2.new(1, -8, 0, 172), LayoutOrder = order, BackgroundColor3 = palette.card, BorderSizePixel = 0, ZIndex = 13}, list)
	corner(card, 12)
	make("Frame", {Name = "RarityStripe", Size = UDim2.new(0, 4, 1, -22), Position = UDim2.fromOffset(8, 11), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 14}, card)
	local heading = label(card, "Name", title, UDim2.new(1, -36, 0, 36), UDim2.fromOffset(20, 6), 15)
	label(card, "Rarity", rarity, UDim2.new(1, -36, 0, 20), UDim2.fromOffset(20, 43), 12, color)
	local count = label(card, "Count", "Ещё не найдено", UDim2.new(1, -36, 0, 44), UDim2.fromOffset(20, 65), 12, palette.muted)
	local equip = button(card, "Equip", "Надеть", UDim2.new(0.38, -14, 0, 44), UDim2.new(0, 20, 1, -56))
	local upgrade = button(card, "Upgrade", "Улучшить", UDim2.new(0.62, -22, 0, 44), UDim2.new(0.38, 12, 1, -56))
	return {frame = card, title = heading, count = count, equip = equip, upgrade = upgrade, color = color}
end
local heroCard = weaponCard("HeroWeapon", 0, "Оружие героя", "СПОСОБНОСТЬ КОСТЮМА", palette.teal)
local currentHeroKey = nil
heroCard.frame.Visible = false
connect(heroCard.upgrade.Activated, function() if currentHeroKey then sendAction("UpgradeWeapon", currentHeroKey) end end)
connect(heroCard.equip.Activated, function() sendAction("EquipWeapon", "") end)
for index, weapon in ipairs(Config.Weapons) do
	local card = weaponCard(weapon.Id, index, weapon.Name, weapon.Rarity, weaponColor(weapon))
	cards[weapon.Id] = card
	connect(card.equip.Activated, function()
		if (inventory[weapon.Id] or 0) > 0 and player:GetAttribute("EquippedWeapon") ~= weapon.Id then sendAction("EquipWeapon", weapon.Id) end
	end)
	connect(card.upgrade.Activated, function()
		if (inventory[weapon.Id] or 0) > 0 then sendAction("UpgradeWeapon", "loot:" .. weapon.Id) end
	end)
end

local loot = make("Frame", {
	Name = "LootReveal", Size = UDim2.fromOffset(360, 300),
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = palette.panel, BorderSizePixel = 0, Visible = false, ZIndex = 20,
}, runtime)
corner(loot, 18)
make("UIStroke", { Color = palette.teal, Transparency = 0.35, Thickness = 2 }, loot)
label(loot, "Title", "БЕСПЛАТНАЯ НАХОДКА", UDim2.new(1, -32, 0, 30), UDim2.fromOffset(16, 12), 18, palette.teal)
local revealStatus = label(loot, "Status", "Открываем ящик…", UDim2.new(1, -32, 0, 28), UDim2.fromOffset(16, 46), 13, palette.muted)
local viewport = make("Frame", {
	Name = "CarouselWindow", Size = UDim2.new(1, -32, 0, 106), Position = UDim2.fromOffset(16, 82),
	BackgroundTransparency = 1, ClipsDescendants = true, BorderSizePixel = 0, ZIndex = 21,
}, loot)
local revealCard = make("Frame", {
	Name = "WeaponCard", Size = UDim2.fromScale(1, 1), BackgroundColor3 = palette.card,
	BorderSizePixel = 0, ZIndex = 22,
}, viewport)
corner(revealCard, 12)
local revealStroke = make("UIStroke", { Color = palette.teal, Thickness = 2, Transparency = 0.2 }, revealCard)
local revealName = label(revealCard, "Name", "", UDim2.new(1, -32, 0, 50), UDim2.fromOffset(16, 10), 20)
revealName.TextXAlignment = Enum.TextXAlignment.Center
local revealRarity = label(revealCard, "Rarity", "", UDim2.new(1, -32, 0, 28), UDim2.fromOffset(16, 65), 14)
revealRarity.TextXAlignment = Enum.TextXAlignment.Center
local resultDetail = label(loot, "ResultDetail", "Без оплаты и списания монет", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 1, -98), 13, palette.muted)
local resultButton = button(loot, "Continue", "Показать результат", UDim2.new(1, -32, 0, 44), UDim2.new(0, 16, 1, -56))
resultButton.BackgroundColor3 = palette.teal
resultButton.TextColor3 = palette.panel

local function showWeapon(weapon)
	revealName.Text = weapon.Name
	revealRarity.Text = weapon.Rarity
	revealRarity.TextColor3 = weaponColor(weapon)
	revealStroke.Color = weaponColor(weapon)
end
local function displayWinner()
	if not alive or not pendingResult then return end
	cancelAnimation()
	revealCard.Position = UDim2.new()
	showWeapon(pendingResult.weapon)
	revealStatus.Text = if revealRarity.Visible then "Твоя находка!" else "Твоя находка! · " .. pendingResult.weapon.Rarity
	resultDetail.Text = (pendingResult.duplicate and "Повторная находка" or "Добавлено в коллекцию")
		.. " · в коллекции ×" .. tostring(pendingResult.count)
	if pendingResult.compensationCoins > 0 then
		resultDetail.Text ..= "\nКомпенсация: +" .. tostring(pendingResult.compensationCoins) .. " монет"
	end
	resultButton.Text = "Готово"
end
local function closePanels()
	cancelAnimation()
	pendingResult = nil
	panel.Visible = false
	loot.Visible = false
	backdrop.Visible = false
end
connect(closeButton.Activated, closePanels)
connect(backdrop.Activated, closePanels)
connect(openButton.Activated, function()
	if loot.Visible then return end
	panel.Visible = not panel.Visible
	backdrop.Visible = panel.Visible
end)
-- Меню базы и арсенал не перекрывают друг друга на небольшом экране.
task.spawn(function()
	local main = playerGui:WaitForChild("TycoonHUD", 30)
	local mainRuntime = main and main:WaitForChild("TycoonUIRuntime", 30)
	local shopPanel = mainRuntime and mainRuntime:WaitForChild("ShopPanel", 30)
	if not alive or not shopPanel then return end
	local function syncMenu()
		if shopPanel.Visible then closePanels() end
		openButton.Visible = not shopPanel.Visible and player:GetAttribute("ObbyActive") ~= true
	end
	connect(shopPanel:GetPropertyChangedSignal("Visible"), syncMenu)
	syncMenu()
end)
connect(resultButton.Activated, function()
	if resultButton.Text == "Готово" then closePanels() else displayWinner() end
end)

local function refreshInventory()
	if not alive then return end
	local encoded = player:GetAttribute("WeaponInventory")
	local decoded = nil
	if type(encoded) == "string" and #encoded <= 4096 then
		local ok, value = pcall(HttpService.JSONDecode, HttpService, encoded)
		if ok and type(value) == "table" then decoded = value end
	end
	local nextInventory = {}
	local owned = 0
	-- Только известные предметы и конечные целые количества из серверного атрибута.
	for _, weapon in ipairs(Config.Weapons) do
		local count = decoded and decoded[weapon.Id]
		if type(count) == "number" and count == count and count ~= math.huge
			and count >= 1 and count == math.floor(count) then
			nextInventory[weapon.Id] = math.min(count, Config.MaxWeaponCopies or 99)
			owned += 1
		end
	end
	inventory = nextInventory
	local ready = player:GetAttribute("DataReady") == true
	local equipped = player:GetAttribute("EquippedWeapon")
	local upgrades = {}
	local rawUpgrades = player:GetAttribute("WeaponUpgrades")
	if type(rawUpgrades) == "string" and #rawUpgrades <= 4096 then
		local ok, decodedUpgrades = pcall(HttpService.JSONDecode, HttpService, rawUpgrades)
		if ok and type(decodedUpgrades) == "table" then upgrades = decodedUpgrades end
	end
	local profileView = {WeaponUpgrades = upgrades, Floor = player:GetAttribute("Floor") or 0, Rebirths = player:GetAttribute("Rebirths") or 0}
	local function refreshCard(card, definition, key, count, selected)
		local level = Config.GetUpgradeLevel(profileView, key)
		local stats = Config.WeaponStats(definition, level)
		local cost = Config.WeaponUpgradeCosts[level + 1]
		local owned = count > 0
		local canEquip = ready and actionRemote ~= nil and owned and not selected
		card.count.Text = if owned then "Урон " .. stats.Damage .. " · +" .. level .. "/5 · " .. string.format("%.2f", stats.Cooldown) .. " сек.\nКопий: " .. count else "Ищи бесплатные ящики на карте"
		card.equip.Visible = owned
		card.equip.Active = canEquip
		card.equip.Selectable = canEquip
		card.equip.AutoButtonColor = canEquip
		card.equip.Text = if selected then "Надето" else "Надеть"
		card.equip.BackgroundColor3 = if canEquip then card.color else palette.panel
		card.equip.TextColor3 = if canEquip then palette.panel else palette.muted
		card.upgrade.Visible = owned
		card.upgrade.Active = ready and actionRemote ~= nil and cost ~= nil
		card.upgrade.Selectable = card.upgrade.Active
		card.upgrade.AutoButtonColor = card.upgrade.Active
		card.upgrade.Text = if cost then "Улучшить · " .. cost else "Максимум +5"
		card.upgrade.BackgroundColor3 = if cost then palette.teal else palette.panel
		card.upgrade.TextColor3 = if cost then palette.panel else palette.muted
	end
	for _, weapon in ipairs(Config.Weapons) do
		local count = inventory[weapon.Id] or 0
		refreshCard(cards[weapon.Id], weapon, "loot:" .. weapon.Id, count, count > 0 and equipped == weapon.Id)
	end
	local hero = Config.GetHero(player:GetAttribute("EquippedHero"))
	currentHeroKey = hero and "hero:" .. hero.Id or nil
	heroCard.frame.Visible = hero ~= nil and Config.CanUseHero(profileView, hero)
	if heroCard.frame.Visible then
		heroCard.title.Text = hero.Weapon
		refreshCard(heroCard, hero, currentHeroKey, 1, (equipped or "") == "")
	end
	inventoryStatus.Text = if not ready then "Загрузка прогресса…" elseif owned == 0 then "Коллекция пуста — найди первую поставку!" else "Найдено видов: " .. tostring(owned) .. " / " .. tostring(#Config.Weapons)
	openButton.Text = "Арсенал · " .. tostring(owned)
end
for _, name in ipairs({ "WeaponInventory", "EquippedWeapon", "EquippedHero", "WeaponUpgrades", "Floor", "Rebirths", "DataReady" }) do
	connect(player:GetAttributeChangedSignal(name), refreshInventory)
end
refreshInventory()

local function refreshLayout()
	if not alive then return end
	local size = runtime.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end
	-- Меняем размеры панели, а не размер шрифта: мобильный текст остаётся читаемым.
	local width = math.min(360, math.max(180, size.X - 24))
	panel.Size = UDim2.fromOffset(width, math.min(400, math.max(190, size.Y - 24)))
	local lootHeight = math.min(300, math.max(230, size.Y - 24))
	loot.Size = UDim2.fromOffset(width, lootHeight)
	local carouselHeight = math.max(40, lootHeight - 194)
	viewport.Size = UDim2.new(1, -32, 0, carouselHeight)
	revealRarity.Visible = carouselHeight >= 90
	revealName.Size = UDim2.new(1, -32, 0, if revealRarity.Visible then 50 else carouselHeight - 4)
	revealName.Position = UDim2.fromOffset(16, if revealRarity.Visible then 10 else 2)
	revealName.TextSize = if revealRarity.Visible then 20 else 16
	openButton.Position = UDim2.new(0.5, 72, 1, -88)

end
connect(runtime:GetPropertyChangedSignal("AbsoluteSize"), function() task.defer(refreshLayout) end)
refreshLayout()
task.defer(refreshLayout)

local function receiveLoot(payload)
	if not alive or type(payload) ~= "table" or type(payload.weaponId) ~= "string" then return end
	local weapon = Config.GetWeapon(payload.weaponId)
	local count = payload.count
	if not weapon or type(count) ~= "number" or count ~= count or count == math.huge
		or count < 1 or count ~= math.floor(count) or count > (Config.MaxWeaponCopies or 99) then return end
	-- Сервер уже выдал награду. Здесь нет запроса выпадения, оплаты или повторного броска.
	cancelAnimation()
	local compensation = payload.compensationCoins
	if type(compensation) ~= "number" or compensation ~= compensation or compensation == math.huge
		or compensation < 0 or compensation ~= math.floor(compensation) or compensation > Config.MaxCoins then
		compensation = 0
	end
	pendingResult = { weapon = weapon, count = count, duplicate = payload.duplicate == true, compensationCoins = compensation }
	local serial = animationSerial
	panel.Visible = false
	loot.Visible = true
	backdrop.Visible = true
	revealCard.Position = UDim2.new()
	revealStatus.Text = "Открываем ящик…"
	resultDetail.Text = "Без оплаты и списания монет"
	resultButton.Text = "Показать результат"
	showWeapon(Config.Weapons[1])
	task.spawn(function()
		-- Последовательность — лишь оформление. Победитель всегда приходит из LootResult.
		for step = 1, 9 do
			if not alive or animationSerial ~= serial then return end
			local duration = 0.06 + step * 0.011
			activeTween = TweenService:Create(revealCard, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(-1.05, 0) })
			activeTween:Play()
			task.wait(duration)
			if not alive or animationSerial ~= serial then return end
			revealCard.Position = UDim2.fromScale(1.05, 0)
			showWeapon(Config.Weapons[(step % #Config.Weapons) + 1])
			activeTween = TweenService:Create(revealCard, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new() })
			activeTween:Play()
			task.wait(duration + 0.02)
		end
		if alive and animationSerial == serial then displayWinner() end
	end)
end

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 30)
	if not alive or not remotes then return end
	local request = remotes:WaitForChild("ActionRequest", 30)
	if not alive then return end
	if request and request:IsA("RemoteEvent") then
		actionRemote = request
		refreshInventory()
	end
	local lootResult = remotes:WaitForChild("LootResult", 30)
	if not alive then return end
	if lootResult and lootResult:IsA("RemoteEvent") then
		connect(lootResult.OnClientEvent, receiveLoot)
	else
		warn("Для находок не найден TycoonRemotes/LootResult.")
	end
end)
