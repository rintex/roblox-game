-- Local visual droplets only. Server income does not depend on these parts.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local EFFECT_LIMIT = 36
local MAX_DISTANCE = 110
local DROPLET_INTERVAL = 0.8

local oldFolder = Workspace:FindFirstChild("ClientTycoonEffects")
if oldFolder then
	local oldStop = oldFolder:FindFirstChild("Stop")
	if oldStop and oldStop:IsA("BindableEvent") then
		oldStop:Fire()
	end
	oldFolder:Destroy()
end

local effects = Instance.new("Folder")
effects.Name = "ClientTycoonEffects"
effects.Parent = Workspace
local stopEvent = Instance.new("BindableEvent")
stopEvent.Name = "Stop"
stopEvent.Parent = effects

local alive = true
local pairsByStart = {}
local active = {}
local activeCount = 0
local connections = {}
local plots = nil

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
end

local function inspect(object)
	if object.Name ~= "DropletStart" or not object:IsA("BasePart") then
		return
	end
	local parent = object.Parent
	local ending = parent and parent:FindFirstChild("DropletEnd")
	if ending and ending:IsA("BasePart") then
		pairsByStart[object] = ending
	end
end

local function inspectAdded(object)
	inspect(object)
	if object.Name == "DropletEnd" and object:IsA("BasePart") and object.Parent then
		local start = object.Parent:FindFirstChild("DropletStart")
		if start then
			inspect(start)
		end
	end
end

local function bindPlots(folder)
	plots = folder
	table.clear(pairsByStart)
	for _, object in ipairs(folder:GetDescendants()) do
		inspect(object)
	end
	connect(folder.DescendantAdded, inspectAdded)
	connect(folder.DescendantRemoving, function(object)
		pairsByStart[object] = nil
		if object.Name == "DropletEnd" then
			for start, ending in pairs(pairsByStart) do
				if ending == object then
					pairsByStart[start] = nil
				end
			end
		end
	end)
end

local function removeDroplet(part)
	local entry = active[part]
	if not entry then
		return
	end
	active[part] = nil
	activeCount -= 1
	if entry.connection then
		entry.connection:Disconnect()
	end
	entry.tween:Cancel()
	part:Destroy()
end

local function emit(start, ending)
	if activeCount >= EFFECT_LIMIT then
		return
	end
	local part = Instance.new("Part")
	part.Name = "VisualDroplet"
	part.Size = Vector3.new(0.7, 0.7, 0.7)
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = start.Color
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.CFrame = start.CFrame
	part.Parent = effects
	local tween = TweenService:Create(part, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = ending.CFrame,
		Size = Vector3.new(0.25, 0.25, 0.25),
		Transparency = 0.45,
	})
	local entry = { tween = tween }
	active[part] = entry
	activeCount += 1
	entry.connection = tween.Completed:Connect(function()
		removeDroplet(part)
	end)
	tween:Play()
	-- Also clean up if the completion event is interrupted.
	task.delay(2, function()
		removeDroplet(part)
	end)
end

local function cleanup()
	if not alive then
		return
	end
	alive = false
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	for part in pairs(active) do
		removeDroplet(part)
	end
	table.clear(pairsByStart)
	effects:Destroy()
end
connect(stopEvent.Event, cleanup)
connect(script.Destroying, cleanup)

task.spawn(function()
	while alive do
		local currentPlots = Workspace:FindFirstChild("TycoonPlots")
		if currentPlots ~= plots then
			-- The world normally creates this folder once. Old signals are
			-- disconnected as well if it is rebuilt during a Studio test.
			for index = #connections, 3, -1 do
				connections[index]:Disconnect()
				table.remove(connections, index)
			end
			plots = nil
			table.clear(pairsByStart)
			if currentPlots then
				bindPlots(currentPlots)
			end
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			for start, ending in pairs(pairsByStart) do
				if not start:IsDescendantOf(Workspace) or not ending:IsDescendantOf(Workspace) then
					pairsByStart[start] = nil
				elseif (start.Position - root.Position).Magnitude <= MAX_DISTANCE then
					emit(start, ending)
				end
			end
		end
		task.wait(DROPLET_INTERVAL)
	end
end)
