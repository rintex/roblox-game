-- Инвентарь показывает серверный профиль. Клиент лишь просит экипировать известное оружие.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local scope = Theme.Scope()
local inventoryModal, lootModal

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
local currencyConnections = {}
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
 if inventoryModal then inventoryModal:Destroy() end
 if lootModal then lootModal:Destroy() end
 scope:Destroy()
	cancelAnimation()
	pendingResult = nil
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, connection in ipairs(currencyConnections) do connection:Disconnect() end
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

local palette = Theme.Colors
local function make(className, properties, parent) return Theme.Make(className, properties, parent) end
local function corner(object, radius) Theme.Round(object, radius) end
local function label(parent, name, text, size, position, textSize, color) return Theme.Label(parent, name, text, size, position, textSize, color) end
local function button(parent, name, text, size, position) return Theme.Button(scope, parent, name, text, size, position) end
local function weaponColor(weapon)
	return Color3.fromRGB(weapon.Color[1], weapon.Color[2], weapon.Color[3])
end

local openButton = button(runtime, "InventoryButton", "Арсенал", UDim2.fromOffset(96, 44), UDim2.new(0.5, 0, 1, -88))
openButton.AnchorPoint = Vector2.new(0.5, 1)
openButton.BackgroundColor3 = palette.panel
openButton.TextSize = 13

local backdrop = button(runtime, "Backdrop", "", UDim2.fromScale(1, 1), UDim2.new())
backdrop.BackgroundColor3 = Color3.fromRGB(5, 11, 22)
backdrop.BackgroundTransparency = 0.25
backdrop.AutoButtonColor = false
backdrop.ZIndex = 10
backdrop.Visible = false

local panel = make("Frame", {
	Name = "InventoryPanel", Size = UDim2.fromOffset(480, 580),
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = palette.panel, BorderSizePixel = 0, Visible = false, ZIndex = 11,
}, runtime)
Theme.Surface(panel, 18, palette.teal)
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
local function weaponCard(name, order, definition, title, rarity, color)
 local card = make("Frame", {Name = name, Size = UDim2.new(1, -8, 0, 210), LayoutOrder = order, BackgroundColor3 = palette.card, BorderSizePixel = 0, ZIndex = 13}, list)
 corner(card, 14)
 Theme.Stroke(card, color, .55)
 local art = Theme.WeaponArt(card, definition, UDim2.fromOffset(12, 12), UDim2.fromOffset(70, 70))
 local heading = label(card, "Name", title, UDim2.new(1, -108, 0, 45), UDim2.fromOffset(96, 10), 15)
 heading.TextYAlignment = Enum.TextYAlignment.Top
 label(card, "Rarity", rarity, UDim2.new(1, -108, 0, 22), UDim2.fromOffset(96, 57), 11, color)
 local count = label(card, "Count", "Ещё не найдено", UDim2.new(1, -28, 0, 56), UDim2.fromOffset(14, 86), 12, palette.muted)
 local levelTrack = make("Frame", {Name = "UpgradeTrack", Position = UDim2.fromOffset(14, 147), Size = UDim2.new(1, -28, 0, 4), BackgroundColor3 = palette.panel, BorderSizePixel = 0, ZIndex = 14}, card)
 corner(levelTrack, 2)
 local levelFill = make("Frame", {Name = "UpgradeFill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 15}, levelTrack)
 corner(levelFill, 2)
 local equip = button(card, "Equip", "Надеть", UDim2.new(.32, -17, 0, 44), UDim2.new(0, 14, 1, -54))
 local upgrade = button(card, "Upgrade", "Улучшить", UDim2.new(.68, -19, 0, 44), UDim2.new(.32, 7, 1, -54))
 equip.TextSize = 12; upgrade.TextSize = 12
 return {frame = card, title = heading, count = count, equip = equip, upgrade = upgrade, color = color, fill = levelFill, art = art}
end
local heroCard = weaponCard("HeroWeapon", 0, {Style = "hero", Kind = "ray", Color = {93, 227, 187}}, "Оружие героя", "СПОСОБНОСТЬ КОСТЮМА", palette.teal)
local currentHeroKey = nil
heroCard.frame.Visible = false
connect(heroCard.upgrade.Activated, function() if currentHeroKey then sendAction("UpgradeWeapon", currentHeroKey) end end)
connect(heroCard.equip.Activated, function() sendAction("EquipWeapon", "") end)
for index, weapon in ipairs(Config.Weapons) do
	local card = weaponCard(weapon.Id, index, weapon, weapon.Name, weapon.Rarity, weaponColor(weapon))
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
Theme.Surface(loot, 18, palette.gold)
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
local revealArt = nil

local function showWeapon(weapon)
	if revealArt then revealArt:Destroy() end
	revealArt = Theme.WeaponArt(revealCard, weapon, UDim2.fromOffset(10, 10), UDim2.fromOffset(80, 80))
	local hasRoom = viewport.Size.Y.Offset >= 94
	revealArt.Visible = hasRoom
	revealName.Position = UDim2.fromOffset(if hasRoom then 102 else 16, 10)
	revealName.Size = UDim2.new(1, if hasRoom then -112 else -32, 0, if hasRoom then 48 else 32)
	revealName.TextSize = if hasRoom then 17 else 15
	revealName.TextXAlignment = if hasRoom then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	revealRarity.Position = UDim2.fromOffset(if hasRoom then 102 else 16, 64)
	revealRarity.Size = UDim2.new(1, if hasRoom then -112 else -32, 0, 28)
	revealRarity.TextXAlignment = revealName.TextXAlignment
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
inventoryModal = Theme.RegisterModal("Inventory", panel, backdrop, nil, closeButton)
lootModal = Theme.RegisterModal("Loot", loot, backdrop, function() cancelAnimation(); pendingResult = nil end, resultButton)
local function closePanels()
 if inventoryModal.open then inventoryModal:Close() end
 if lootModal.open then lootModal:Close() end
end
connect(closeButton.Activated, closePanels)
connect(backdrop.Activated, closePanels)
local function toggleInventory()
 if player:GetAttribute("ObbyActive") == true or lootModal.open then return end
 inventoryModal:Toggle()
end
connect(openButton.Activated, toggleInventory)
Theme.Shortcut(scope, Enum.KeyCode.I, Enum.KeyCode.DPadUp, toggleInventory)
local function updateVisibility()
 local modal = playerGui:GetAttribute("QuarterModalOpen")
 openButton.Visible = player:GetAttribute("ObbyActive") ~= true and (modal == nil or modal == "")
 if player:GetAttribute("ObbyActive") == true then closePanels() end
end
connect(playerGui:GetAttributeChangedSignal("QuarterModalOpen"), updateVisibility)
connect(player:GetAttributeChangedSignal("ObbyActive"), updateVisibility)
updateVisibility()
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
		card.count.Text = if owned then "Урон " .. stats.Damage .. " · дальность " .. stats.Range .. "\nПерезарядка " .. string.format("%.2f", stats.Cooldown) .. " сек. · улучшение " .. level .. "/" .. #Config.WeaponUpgradeCosts .. " · копий " .. count else "Найди в бесплатном ящике с неба.\nУрон " .. stats.Damage .. " · дальность " .. stats.Range .. " · " .. stats.Cooldown .. " сек."
  card.fill.Size = UDim2.fromScale(level / #Config.WeaponUpgradeCosts, 1)
		card.equip.Visible = owned
		card.equip.Active = canEquip
		card.equip.Selectable = canEquip
		card.equip.AutoButtonColor = false
		card.equip.Text = if selected then "Надето" else "Надеть"
		card.equip.BackgroundColor3 = if canEquip then card.color else palette.panel
		card.equip.TextColor3 = if canEquip then palette.panel else palette.muted
		card.upgrade.Visible = owned
		local leaderstats = player:FindFirstChild("leaderstats")
  local coinsStat = leaderstats and leaderstats:FindFirstChild("Coins")
  local coins = coinsStat and coinsStat.Value or 0
  local affordable = cost ~= nil and coins >= cost
  card.upgrade.Active = ready and actionRemote ~= nil and affordable
		card.upgrade.Selectable = card.upgrade.Active
		card.upgrade.AutoButtonColor = false
		card.upgrade.Text = if cost then (if affordable then "Улучшить · " else "Нужно · ") .. Theme.Format(cost) else "Максимум +" .. #Config.WeaponUpgradeCosts
		card.upgrade.BackgroundColor3 = if card.upgrade.Active then palette.teal else palette.panel
		card.upgrade.TextColor3 = if card.upgrade.Active then palette.panel else palette.muted
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
	openButton.Text = "Арсенал"
end
for _, name in ipairs({ "WeaponInventory", "EquippedWeapon", "EquippedHero", "WeaponUpgrades", "Floor", "Rebirths", "DataReady" }) do
	connect(player:GetAttributeChangedSignal(name), refreshInventory)
end
refreshInventory()

local function bindCurrency(folder)
	for _, connection in ipairs(currencyConnections) do connection:Disconnect() end
	table.clear(currencyConnections)
	if folder then
		local coins = folder:FindFirstChild("Coins")
		if coins and coins:IsA("IntValue") then table.insert(currencyConnections, coins:GetPropertyChangedSignal("Value"):Connect(refreshInventory)) end
		table.insert(currencyConnections, folder.ChildAdded:Connect(function() bindCurrency(folder) end))
		table.insert(currencyConnections, folder.ChildRemoved:Connect(function() bindCurrency(folder) end))
	end
	refreshInventory()
end
connect(player.ChildAdded, function(child) if child.Name == "leaderstats" then bindCurrency(child) end end)
connect(player.ChildRemoved, function(child) if child.Name == "leaderstats" then bindCurrency(nil) end end)
bindCurrency(player:FindFirstChild("leaderstats"))

local function refreshLayout()
	if not alive then return end
	local size = runtime.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end
	-- Меняем размеры панели, а не размер шрифта: мобильный текст остаётся читаемым.
	local width = math.min(480, math.max(260, size.X - 28))
	panel.Size = UDim2.fromOffset(width, math.min(580, math.max(230, size.Y - 70)))
	local lootHeight = math.min(320, math.max(230, size.Y - 70))
	loot.Size = UDim2.fromOffset(math.min(420, width), lootHeight)
	local carouselHeight = math.max(40, lootHeight - 194)
	viewport.Size = UDim2.new(1, -32, 0, carouselHeight)
	revealRarity.Visible = carouselHeight >= 90
	revealName.Size = UDim2.new(1, -32, 0, if revealRarity.Visible then 50 else carouselHeight - 4)
	revealName.Position = UDim2.fromOffset(16, if revealRarity.Visible then 10 else 2)
	revealName.TextSize = if revealRarity.Visible then 20 else 16
	openButton.Position = UDim2.new(0.5, 0, 1, -88)
	if pendingResult then showWeapon(pendingResult.weapon) end

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
	lootModal:Open()
 local serial = animationSerial
	revealCard.Position = UDim2.new()
	revealStatus.Text = "Открываем ящик…"
	resultDetail.Text = "Без оплаты и списания монет"
	resultButton.Text = "Показать результат"
	showWeapon(Config.Weapons[1])
 if player:GetAttribute("EffectsQuality") == "Off" then displayWinner(); return end
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
