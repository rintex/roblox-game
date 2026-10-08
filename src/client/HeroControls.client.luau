-- Только управление: сервер проверяет оружие, расстояние и перезарядку навыка.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local ACTION_NAME = "TycoonHeroSkill"
local AIM_DISTANCE = 250
local LOCAL_COOLDOWN = 0.15
local RUNTIME_NAME = "HeroControlsRuntime"

-- При повторном запуске сначала отключаем старые кнопки и обработчики.
local oldRuntime = script.Parent:FindFirstChild(RUNTIME_NAME)
if oldRuntime then
	local oldStop = oldRuntime:FindFirstChild("Stop")
	if oldStop and oldStop:IsA("BindableEvent") then
		oldStop:Fire()
	end
	oldRuntime:Destroy()
end

local runtime = Instance.new("Folder")
runtime.Name = RUNTIME_NAME
runtime.Parent = script.Parent
local stopEvent = Instance.new("BindableEvent")
stopEvent.Name = "Stop"
stopEvent.Parent = runtime

local alive = true
local skillRemote = nil
local character = nil
local equippedTool = nil
local actionBound = false
local lastRequest = -math.huge
local connections = {}
local characterConnections = {}
local tools = {}
local cameraConnection = nil
local cooldownElapsed = 0

local function disconnectAll(list)
	for _, connection in ipairs(list) do
		connection:Disconnect()
	end
	table.clear(list)
end

local function isFiniteVector(value)
	if typeof(value) ~= "Vector3" then
		return false
	end
	for _, number in ipairs({ value.X, value.Y, value.Z }) do
		if number ~= number or math.abs(number) > 1000000 then
			return false
		end
	end
	return true
end

local function isHeroTool(tool)
	if not tool or not tool:IsA("Tool") then return false end
	local marker = tool:GetAttribute("HeroWeapon")
	-- Сервер помечает оружие строкой heroId или loot:weaponId.
	-- Это фильтр управления; владение и точный Tool проверяет сервер.
	return type(marker) == "string" and #marker > 0 and #marker <= 64
end

local function aimPosition(forceCenter)
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local inputType = UserInputService:GetLastInputType()
	local useCenter = forceCenter
		or inputType == Enum.UserInputType.Touch
		or string.find(inputType.Name, "^Gamepad") ~= nil
		or not UserInputService.MouseEnabled
	local ray
	if useCenter then
		local center = camera.ViewportSize / 2
		ray = camera:ViewportPointToRay(center.X, center.Y)
	else
		-- ScreenPointToRay учитывает верхнюю панель Roblox.
		local mousePosition = UserInputService:GetMouseLocation()
		ray = camera:ScreenPointToRay(mousePosition.X, mousePosition.Y)
	end
	if not isFiniteVector(ray.Origin) or not isFiniteVector(ray.Direction) then
		return nil
	end
	local excluded = {}
	if character then
		table.insert(excluded, character)
	end
	for _, name in ipairs({ "ClientHeroEffects", "ClientTycoonEffects" }) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(excluded, folder)
		end
	end
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = excluded
	parameters.IgnoreWater = true
	parameters.RespectCanCollide = false -- Учитываем CanQuery, а не CanCollide.
	local direction = ray.Direction * AIM_DISTANCE
	local result = Workspace:Raycast(ray.Origin, direction, parameters)
	local position = result and result.Position or ray.Origin + direction
	return isFiniteVector(position) and position or nil
end

local function modalOpen()
	local gui = player:FindFirstChildOfClass("PlayerGui")
	local modal = gui and gui:GetAttribute("QuarterModalOpen")
	return (type(modal) == "string" and modal ~= "") or UserInputService:GetFocusedTextBox() ~= nil
end

local function remainingCooldown()
	local readyAt = player:GetAttribute("AttackReadyAt")
	if type(readyAt) ~= "number" or readyAt ~= readyAt or math.abs(readyAt) == math.huge then return 0 end
	return math.max(0, readyAt - Workspace:GetServerTimeNow())
end

local function updateActionTitle()
	if not actionBound then return end
	local remaining = remainingCooldown()
	ContextActionService:SetTitle(ACTION_NAME, if remaining > 0 then string.format("%.1f с", remaining)
		elseif player:GetAttribute("ArenaCombatOptIn") ~= true then "Арена" else "Атака")
end

local function requestSkill(forceCenter)
	if not alive or not skillRemote or not skillRemote.Parent then
		return
	end
	if not isHeroTool(equippedTool) or equippedTool.Parent ~= character then
		return
	end
	if modalOpen() or player:GetAttribute("DataReady") ~= true
		or player:GetAttribute("ArenaCombatOptIn") ~= true or player:GetAttribute("ObbyActive") == true
		or remainingCooldown() > 0 then return end
	-- Это удобство для управления. Настоящая защита работает на сервере.
	local now = os.clock()
	if now - lastRequest < LOCAL_COOLDOWN then
		return
	end
	local position = aimPosition(forceCenter)
	if not position then
		return
	end
	lastRequest = now
	skillRemote:FireServer(position) -- Только Vector3, без цели или размера награды.
end

local function positionAction()
	if not actionBound then return end
	local camera = Workspace.CurrentCamera
	local landscape = camera and camera.ViewportSize.X > camera.ViewportSize.Y
	-- Portrait: right of the admin button and above jump. Landscape:
	-- keep below the inventory button and left of jump.
	ContextActionService:SetPosition(ACTION_NAME, if landscape then UDim2.new(1, -140, 1, -110) else UDim2.new(1, -130, 1, -200))
end

local function refreshAction()
	equippedTool = nil
	for tool in pairs(tools) do
		if tool.Parent == character and isHeroTool(tool) then
			equippedTool = tool
			break
		end
	end
	local shouldBind = alive and equippedTool ~= nil and skillRemote ~= nil
	if shouldBind == actionBound then
		return
	end
	actionBound = shouldBind
	if not actionBound then
		ContextActionService:UnbindAction(ACTION_NAME)
		return
	end
	ContextActionService:BindAction(ACTION_NAME, function(_, inputState, inputObject)
		if modalOpen() then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then
			local center = inputObject and (
				inputObject.UserInputType == Enum.UserInputType.Touch
				or string.find(inputObject.UserInputType.Name, "^Gamepad") ~= nil
			)
			requestSkill(center)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonR2)
	updateActionTitle()
	positionAction()
end

local function removeTool(tool)
	local toolConnections = tools[tool]
	if not toolConnections then
		return
	end
	disconnectAll(toolConnections)
	tools[tool] = nil
	refreshAction()
end

local function addTool(tool)
	if not alive or not tool:IsA("Tool") or tools[tool] then
		return
	end
	-- Один набор обработчиков на Tool; добавление других детей его не дублирует.
	local toolConnections = {}
	tools[tool] = toolConnections
	table.insert(toolConnections, tool.Activated:Connect(function()
		if tool == equippedTool then
			requestSkill(false)
		end
	end))
	table.insert(toolConnections, tool:GetAttributeChangedSignal("HeroWeapon"):Connect(refreshAction))
	refreshAction()
end

local function clearCharacter()
	disconnectAll(characterConnections)
	for _, toolConnections in pairs(tools) do
		disconnectAll(toolConnections)
	end
	table.clear(tools)
	character = nil
	refreshAction()
end

local function bindCharacter(newCharacter)
	if not alive or character == newCharacter then
		return
	end
	clearCharacter()
	character = newCharacter
	table.insert(characterConnections, newCharacter.ChildAdded:Connect(addTool))
	table.insert(characterConnections, newCharacter.ChildRemoved:Connect(removeTool))
	for _, child in ipairs(newCharacter:GetChildren()) do
		addTool(child)
	end
end

local function cleanup()
	if not alive then
		return
	end
	alive = false
	disconnectAll(connections)
	clearCharacter()
	skillRemote = nil
	if cameraConnection then cameraConnection:Disconnect() end
	runtime:Destroy()
end

table.insert(connections, stopEvent.Event:Connect(cleanup))
table.insert(connections, script.Destroying:Connect(cleanup))
table.insert(connections, runtime.Destroying:Connect(cleanup))
table.insert(connections, player:GetAttributeChangedSignal("AttackReadyAt"):Connect(updateActionTitle))
table.insert(connections, player:GetAttributeChangedSignal("ArenaCombatOptIn"):Connect(updateActionTitle))
table.insert(connections, RunService.Heartbeat:Connect(function(seconds)
	if not actionBound then return end
	cooldownElapsed += seconds
	if cooldownElapsed < 0.1 then return end
	cooldownElapsed = 0
	updateActionTitle()
end))
local function bindCamera()
	if cameraConnection then cameraConnection:Disconnect() end
	local camera = Workspace.CurrentCamera
	if camera then cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(positionAction) end
	positionAction()
end
table.insert(connections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
bindCamera()
table.insert(connections, player.CharacterAdded:Connect(bindCharacter))
table.insert(connections, player.CharacterRemoving:Connect(function(oldCharacter)
	if character == oldCharacter then
		clearCharacter()
	end
end))
if player.Character then
	bindCharacter(player.Character)
end

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 30)
	if not alive or not remotes then
		return
	end
	local remote = remotes:WaitForChild("SkillRequest", 30)
	if not alive or not remote or not remote:IsA("RemoteEvent") then
		return
	end
	skillRemote = remote
	refreshAction()
end)
