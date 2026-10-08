-- The panel only requests actions. Admin rights and rewards are checked on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local scope = Theme.Scope()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local request = ReplicatedStorage:WaitForChild("TycoonRemotes"):WaitForChild("AdminRequest")
local old = playerGui:FindFirstChild("TycoonAdminHUD")
if old then
	local stop = old:FindFirstChild("Stop")
	if stop and stop:IsA("BindableEvent") then stop:Fire() end
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "TycoonAdminHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 15
gui.Enabled = player:GetAttribute("IsGameAdmin") == true
gui.Parent = playerGui
local stop = Instance.new("BindableEvent")
stop.Name = "Stop"
stop.Parent = gui

local alive = true
local connections = {}
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local panelColor = Theme.Colors.panel
local cardColor = Theme.Colors.card
local textColor = Theme.Colors.text
local accent = Theme.Colors.gold
local muted = Theme.Colors.muted
local function make(className, properties, parent)
	local object = Instance.new(className)
	for name, value in pairs(properties) do object[name] = value end
	object.Parent = parent
 if className == "TextButton" then Theme.DecorateButton(scope, object, accent) end
	return object
end
local function corner(object, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, object)
end
local function text(parent, name, value, size, position, fontSize, color)
	return make("TextLabel", {
		Name = name, BackgroundTransparency = 1, Text = value, Size = size, Position = position,
		TextColor3 = color or textColor, TextSize = fontSize, Font = Enum.Font.GothamMedium,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
end

local toggle = make("TextButton", {
	Name = "AdminButton", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -204),
	Size = UDim2.fromOffset(110, 42), BackgroundColor3 = panelColor, BorderSizePixel = 0,
	Text = "Админ", TextColor3 = accent, TextSize = 15, Font = Enum.Font.GothamBold,
	Visible = false,
}, gui)
corner(toggle, 12)
local backdrop = make("TextButton", {
	Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 11, 22),
	BackgroundTransparency = 0.25, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 2,
}, gui)
local panel = make("Frame", {
	Name = "OwnerPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(440, 520), BackgroundColor3 = panelColor, BorderSizePixel = 0,
	Visible = false, ZIndex = 3,
}, gui)
Theme.Surface(panel, 18, accent)
text(panel, "Title", "Панель владельца", UDim2.new(1, -84, 0, 34), UDim2.fromOffset(18, 10), 21, accent)
text(panel, "Subtitle", "Действия применяются только к твоему персонажу.", UDim2.new(1, -36, 0, 38), UDim2.fromOffset(18, 46), 12, muted)
local close = make("TextButton", {
	Name = "Close", Position = UDim2.new(1, -56, 0, 8), Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = cardColor, BorderSizePixel = 0, Text = "×", TextSize = 26,
	Font = Enum.Font.GothamBold, TextColor3 = textColor,
}, panel)
corner(close, 10)

local list = make("ScrollingFrame", {
	Name = "Actions", Position = UDim2.fromOffset(18, 98), Size = UDim2.new(1, -36, 1, -138),
	BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
	ScrollBarImageColor3 = accent, ScrollingDirection = Enum.ScrollingDirection.Y,
}, panel)
make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local status = text(panel, "Status", "Действия доступны только владельцу игры.", UDim2.new(1, -36, 0, 28), UDim2.new(0, 18, 1, -34), 11, muted)

local lastSent = 0
local actions = {
	{ "GrantCoins", "+25 000 монет себе" },
	{ "Heal", "Восстановить здоровье" },
	{ "TeleportHome", "Вернуться на свой участок" },
}
if RunService:IsStudio() then
	table.insert(actions, { "PreviewVIP", "Studio: пример VIP-титула" })
	table.insert(actions, { "PreviewNeon", "Studio: пример неонового оружия" })
end
for index, action in ipairs(actions) do
	local button = make("TextButton", {
		Name = action[1], Size = UDim2.new(1, -8, 0, 46), LayoutOrder = index,
		BackgroundColor3 = cardColor, BorderSizePixel = 0, Text = action[2],
		TextColor3 = textColor, TextSize = 14, Font = Enum.Font.GothamBold,
	}, list)
	corner(button, 10)
	connect(button.Activated, function()
		if not alive or player:GetAttribute("IsGameAdmin") ~= true then return end
		if player:GetAttribute("DataReady") ~= true then
			status.Text = "Дождись загрузки прогресса."
			return
		end
		if os.clock() - lastSent < 0.5 then return end
		lastSent = os.clock()
		request:FireServer(action[1])
		status.Text = "Запрос отправлен. Результат появится в уведомлении."
	end)
end

local setup = make("Frame", {
	Name = "GamePassSetup", LayoutOrder = 10, Size = UDim2.new(1, -8, 0, 170),
	BackgroundColor3 = cardColor, BorderSizePixel = 0,
}, list)
corner(setup, 12)
text(setup, "Heading", "Как подключить пропуска", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 8), 15, accent)
text(setup, "Instructions", "Пропуска создаются в Creator Hub после публикации игры.\ncreate.roblox.com\n\nСоздай свои пропуска VIP и Neon, затем укажи их ID в ReplicatedStorage → Shared → TycoonConfig → GamePasses. Без настоящих ID покупки скрыты.", UDim2.new(1, -24, 1, -44), UDim2.fromOffset(12, 38), 12, textColor)

local modal = Theme.RegisterModal("Admin", panel, backdrop, nil, close)
local function setOpen(open)
 local allowed = player:GetAttribute("IsGameAdmin") == true and player:GetAttribute("ObbyActive") ~= true
 if open and allowed then modal:Open() else modal:Close() end
end
local function updateToggle()
 -- Access lives in Settings so the owner has no extra floating control.
 toggle.Visible = false
 if player:GetAttribute("ObbyActive") == true then modal:Close(true) end
end
connect(playerGui:GetAttributeChangedSignal("QuarterModalOpen"), updateToggle)
connect(player:GetAttributeChangedSignal("ObbyActive"), updateToggle)
updateToggle()
connect(toggle.Activated, function() setOpen(not modal.open) end)
connect(close.Activated, function() setOpen(false) end)
connect(backdrop.Activated, function() setOpen(false) end)
connect(player:GetAttributeChangedSignal("IsGameAdmin"), function()
	gui.Enabled = player:GetAttribute("IsGameAdmin") == true
	if not gui.Enabled then setOpen(false) end
end)

local cameraConnection
local function resize()
	local camera = Workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		panel.Size = UDim2.fromOffset(math.min(440, math.max(260, size.X - 28)), math.min(520, math.max(230, size.Y - 80)))
  toggle.Position = UDim2.new(.5, 0, 1, if size.Y >= 420 then -204 else -144)
	end
end
local function bindCamera()
	if cameraConnection then cameraConnection:Disconnect() end
	local camera = Workspace.CurrentCamera
	if camera then cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
	resize()
end
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)
bindCamera()
local function cleanup()
	if not alive then return end
	alive = false
 modal:Destroy()
 scope:Destroy()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	if cameraConnection then cameraConnection:Disconnect() end
	gui:Destroy()
end
connect(stop.Event, cleanup)
connect(script.Destroying, cleanup)
