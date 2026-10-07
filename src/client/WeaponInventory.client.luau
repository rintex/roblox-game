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

local openButton = button(runtime, "InventoryButton", "Оружие", UDim2.fromOffset(122, 46), UDim2.new(1, -14, 0.58, 0))
openButton.AnchorPoint = Vector2.new(1, 0.5)
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
label(panel, "Explanation", "Ищи ящики на карте: оружие из них бесплатное.", UDim2.new(1, -32, 0, 38), UDim2.fromOffset(16, 48), 13, palette.muted)
local inventoryStatus = label(panel, "Status", "Загрузка коллекции…", UDim2.new(1, -32, 0, 26), UDim2.fromOffset(16, 87), 13, palette.teal)
local list = make("ScrollingFrame", {
	Name = "WeaponList", Position = UDim2.fromOffset(16, 122), Size = UDim2.new(1, -32, 1, -138),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
	ScrollBarImageColor3 = palette.teal, ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 12,
}, panel)
make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)

for index, weapon in ipairs(Config.Weapons) do
	local color = weaponColor(weapon)
	local card = make("Frame", {
		Name = weapon.Id, Size = UDim2.new(1, -8, 0, 116), LayoutOrder = index,
		BackgroundColor3 = palette.card, BorderSizePixel = 0, ZIndex = 13,
	}, list)
	corner(card, 12)
	make("Frame", {
		Name = "RarityStripe", Size = UDim2.new(0, 4, 1, -22), Position = UDim2.fromOffset(8, 11),
		BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 14,
	}, card)
	label(card, "Name", weapon.Name, UDim2.new(1, -36, 0, 36), UDim2.fromOffset(20, 6), 15)
	label(card, "Rarity", weapon.Rarity, UDim2.new(1, -36, 0, 20), UDim2.fromOffset(20, 43), 12, color)
	local countLabel = label(card, "Count", "Ещё не найдено", UDim2.new(1, -154, 0, 38), UDim2.fromOffset(20, 68), 12, palette.muted)
	local equip = button(card, "Equip", "Надеть", UDim2.fromOffset(116, 40), UDim2.new(1, -128, 0, 69))
	equip.Visible = false
	cards[weapon.Id] = { count = countLabel, equip = equip, color = color }
	connect(equip.Activated, function()
		if not alive or player:GetAttribute("DataReady") ~= true or not actionRemote or not actionRemote.Parent then return end
		if (inventory[weapon.Id] or 0) < 1 or player:GetAttribute("EquippedWeapon") == weapon.Id then return end
		local now = os.clock()
		if now - lastEquipRequest < 0.4 then return end
		lastEquipRequest = now
		-- Цена, владение и реальные боевые свойства проверяются только сервером.
		actionRemote:FireServer("EquipWeapon", weapon.Id)
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
	for _, weapon in ipairs(Config.Weapons) do
		local card = cards[weapon.Id]
		local count = inventory[weapon.Id] or 0
		local selected = count > 0 and equipped == weapon.Id
		local canEquip = ready and actionRemote ~= nil and count > 0 and not selected
		card.count.Text = if count > 0 then "Урон: " .. tostring(weapon.Damage) .. " · ×" .. tostring(count) else "Ещё не найдено"
		card.equip.Visible = count > 0
		card.equip.Active = canEquip
		card.equip.Selectable = canEquip
		card.equip.AutoButtonColor = canEquip
		card.equip.Text = if selected then "Надето" elseif ready and actionRemote then "Надеть" else "Подождите"
		card.equip.BackgroundColor3 = if canEquip or selected then card.color else palette.panel
		card.equip.TextColor3 = if canEquip or selected then palette.panel else palette.muted
	end
	inventoryStatus.Text = if not ready then "Загрузка прогресса…" elseif owned == 0 then "Коллекция пуста — найди первую поставку!" else "Найдено видов: " .. tostring(owned) .. " / " .. tostring(#Config.Weapons)
	openButton.Text = "Оружие · " .. tostring(owned)
end
for _, name in ipairs({ "WeaponInventory", "EquippedWeapon", "DataReady" }) do
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
	-- Use the rendered guide bounds as well as screen size: safe insets on
	-- a small portrait phone must not move the button over the base guide.
	if size.Y > size.X then
		local centerY = size.Y * 0.58
		local mainGui = playerGui:FindFirstChild("TycoonHUD")
		local mainRuntime = mainGui and mainGui:FindFirstChild("TycoonUIRuntime")
		local guide = mainRuntime and mainRuntime:FindFirstChild("Guide")
		if guide and guide:IsA("GuiObject") then
			local guideBottom = guide.AbsolutePosition.Y + guide.AbsoluteSize.Y - runtime.AbsolutePosition.Y
			centerY = math.max(centerY, guideBottom + 32)
		end
		openButton.Position = UDim2.new(1, -14, 0, math.min(centerY, size.Y - 36))
	else
		openButton.Position = UDim2.new(1, -14, 0.45, 0)
	end
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
