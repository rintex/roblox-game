-- Локальные эффекты города. Генераторы, покупки и груз считаются сервером.
-- Один редкий цикл обслуживает только ближайшие объекты; физики и Heartbeat нет.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 210, 104)
local TEAL = Color3.fromRGB(98, 221, 192)
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local PING_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local oldFolder = Workspace:FindFirstChild("ClientTycoonEffects")
if oldFolder then
	local oldStop = oldFolder:FindFirstChild("Stop")
	if oldStop and oldStop:IsA("BindableEvent") then oldStop:Fire() end
	oldFolder:Destroy()
end
local effects = Instance.new("Folder")
effects.Name = "ClientTycoonEffects"
effects.Parent = Workspace
local stopEvent = Instance.new("BindableEvent")
stopEvent.Name = "Stop"
stopEvent.Parent = effects

local alive = true
local pairsByStart, active, highlights = {}, {}, {}
local connections, plotConnections, crateConnections = {}, {}, {}
local activeCount = 0
local plots, crateFolder, config = nil, nil, nil
local nextPortalAt, nextSoundAt = 0, 0

local function quality()
	local value = player:GetAttribute("EffectsQuality")
	return if value == "Off" or value == "Low" then value else "High"
end
local function effectLimit() return if quality() == "Low" then 16 else 48 end
local function rootPart()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end
local function near(position, maximum)
	local root = rootPart()
	return root and (root.Position - position).Magnitude <= (maximum or (if quality() == "Low" then 80 else 130))
end
local function connect(signal, callback, group)
	local connection = signal:Connect(callback)
	table.insert(group or connections, connection)
end
local function disconnect(group)
	for _, connection in ipairs(group) do connection:Disconnect() end
	table.clear(group)
end
local function removeEffect(object)
	local entry = active[object]
	if not entry then return end
	active[object] = nil
	activeCount -= 1
	if entry.connection then entry.connection:Disconnect() end
	if entry.tween then entry.tween:Cancel() end
	object:Destroy()
end
local function track(object, duration, tween)
	if not alive or activeCount >= effectLimit() then object:Destroy(); return nil end
	active[object] = {tween = tween}
	activeCount += 1
	if tween then
		active[object].connection = tween.Completed:Connect(function() removeEffect(object) end)
		tween:Play()
	end
	task.delay(duration + 0.2, function() removeEffect(object) end)
	return object
end
local function visualPart(name, size, cframe, color)
	if not alive or quality() == "Off" or activeCount >= effectLimit() then return nil end
	local part = Instance.new("Part")
	part.Name, part.Size, part.CFrame, part.Color = name, size, cframe, color
	part.Material, part.Shape = Enum.Material.Neon, Enum.PartType.Ball
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.CastShadow = false
	part.Parent = effects
	return part
end
local function ring(position, radius, color, duration, name)
	local part = visualPart(name or "CityPulse", Vector3.new(0.07, 1.5, 1.5),
		CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color)
	if not part then return end
	part.Shape, part.Transparency = Enum.PartType.Cylinder, 0.75
	track(part, duration, TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, radius * 2, radius * 2), Transparency = 1,
	}))
end
local function particles(position, color, count)
	if quality() ~= "High" then return end
	local anchor = visualPart("CityParticles", Vector3.new(0.1, 0.1, 0.1), CFrame.new(position), color)
	if not anchor then return end
	anchor.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name, emitter.Texture = "SparkBurst", SPARK_TEXTURE
	emitter.Rate, emitter.LightEmission = 0, 0.7
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime, emitter.Speed = NumberRange.new(0.3, 0.75), NumberRange.new(3, 7)
	emitter.Drag, emitter.SpreadAngle = 3, Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0)})
	emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1)})
	emitter.Parent = anchor
	if track(anchor, 1) then emitter:Emit(math.clamp(count or 10, 1, 18)) end
end
local function feedbackSound(pitch)
	local root = rootPart()
	if not alive or not root or player:GetAttribute("SoundEnabled") == false or os.clock() < nextSoundAt then return end
	nextSoundAt = os.clock() + 0.35
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.CFrame = "CityFeedbackSound", Vector3.new(0.1, 0.1, 0.1), root.CFrame
	anchor.Transparency, anchor.Anchored = 1, true
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.CastShadow = false, false, false, false
	anchor.Parent = effects
	local sound = Instance.new("Sound")
	sound.SoundId, sound.Volume, sound.PlaybackSpeed = PING_SOUND, 0.14, pitch or 1.2
	sound.RollOffMinDistance, sound.RollOffMaxDistance = 8, 30
	sound.Parent = anchor
	if track(anchor, 1.5) then pcall(function() sound:Play() end) end
end
local function emit(start, ending)
	local part = visualPart("VisualDroplet", Vector3.new(0.6, 0.6, 0.6), start.CFrame, start.Color)
	if not part then return end
	track(part, 0.65, TweenService:Create(part, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = ending.CFrame, Size = Vector3.new(0.22, 0.22, 0.22), Transparency = 0.55,
	}))
end
local function inspect(object)
	if object.Name == "DropletStart" and object:IsA("BasePart") then
		local parent = object.Parent
		local ending = parent and parent:FindFirstChild("DropletEnd")
		if ending and ending:IsA("BasePart") then pairsByStart[object] = ending end
	elseif object.Name == "DropletEnd" and object:IsA("BasePart") and object.Parent then
		local start = object.Parent:FindFirstChild("DropletStart")
		if start then inspect(start) end
	end
end

local function clearHighlights()
	for pad, highlight in pairs(highlights) do highlight:Destroy(); highlights[pad] = nil end
end
local function refreshPurchases()
	if not alive then return end
	if quality() == "Off" or not config or player:GetAttribute("DataReady") ~= true then clearHighlights(); return end
	local ownPlot
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			if plot:GetAttribute("OwnerUserId") == player.UserId then ownPlot = plot; break end
		end
	end
	local wanted = {}
	local function available(name)
		local pad = ownPlot and ownPlot:FindFirstChild(name)
		if pad then wanted[pad] = true end
	end
	if ownPlot and ownPlot:GetAttribute("OwnerReady") == true then
		local coins = player:GetAttribute("Coins") or 0
		local floor, tier = player:GetAttribute("Floor") or 0, player:GetAttribute("DropperTier") or 0
		local nextFloor, nextTier = config.Floors[floor + 1], config.DropperCosts[tier + 1]
		if nextFloor and coins >= nextFloor.Cost then available("UpgradePad") end
		if floor > 0 and nextTier and coins >= nextTier then available("DropperUpgradePad") end
		if (player:GetAttribute("Bank") or 0) > 0 then available("Collector") end
	end
	for pad, highlight in pairs(highlights) do
		if not wanted[pad] or not pad.Parent or not near(pad.Position) then highlight:Destroy(); highlights[pad] = nil end
	end
	for pad in pairs(wanted) do
		if pad and pad:IsA("BasePart") and pad:IsDescendantOf(Workspace) and near(pad.Position) and not highlights[pad] then
			local highlight = Instance.new("Highlight")
			highlight.Name, highlight.Adornee = "AvailablePurchase", pad
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.FillColor, highlight.OutlineColor = TEAL, GOLD
			highlight.FillTransparency, highlight.OutlineTransparency = 0.88, 0.2
			highlight.Parent = effects
			highlights[pad] = highlight
		end
	end
end
local function construction(plot, floor)
	local base = plot:FindFirstChild("Base")
	if not base or not base:IsA("BasePart") or not near(base.Position) or quality() == "Off" then return end
	local structure = plot:FindFirstChild("Structure")
	if structure then
		local glow = Instance.new("Highlight")
		glow.Name, glow.Adornee = "ConstructionGlow", plot
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.FillColor, glow.OutlineColor = TEAL, GOLD
		glow.FillTransparency, glow.OutlineTransparency = 0.85, 0.2
		glow.Parent = effects
		track(glow, 0.75, TweenService:Create(glow, TweenInfo.new(0.75), {FillTransparency = 1, OutlineTransparency = 1}))
	end
	-- Этажи имеют верхнюю поверхность .8 + 12*n; пульс расположен над плитой.
	local position = base.Position + Vector3.new(0, 0.72 + (floor - 1) * 12, 0)
	ring(position, 22, TEAL, 0.8, "ConstructionRing")
	particles(position + Vector3.new(0, 1, 0), GOLD, 16)
end
local function bindPlots(folder)
	disconnect(plotConnections)
	table.clear(pairsByStart)
	clearHighlights()
	plots = folder
	if not folder then return end
	local watched = {}
	local function watchPlot(plot)
		if not plot:IsA("Model") or watched[plot] then return end
		watched[plot] = true
		local previous = plot:GetAttribute("Floor") or 0
		connect(plot:GetAttributeChangedSignal("Floor"), function()
			local current = plot:GetAttribute("Floor") or 0
			if current > previous and plot:GetAttribute("OwnerReady") == true then construction(plot, current) end
			previous = current
			refreshPurchases()
		end, plotConnections)
		connect(plot:GetAttributeChangedSignal("OwnerReady"), refreshPurchases, plotConnections)
		connect(plot:GetAttributeChangedSignal("OwnerUserId"), refreshPurchases, plotConnections)
	end
	for _, plot in ipairs(folder:GetChildren()) do watchPlot(plot) end
	for _, object in ipairs(folder:GetDescendants()) do inspect(object) end
	connect(folder.ChildAdded, watchPlot, plotConnections)
	connect(folder.DescendantAdded, inspect, plotConnections)
	connect(folder.DescendantRemoving, function(object)
		pairsByStart[object] = nil
		if object.Name == "DropletEnd" then
			for start, ending in pairs(pairsByStart) do if ending == object then pairsByStart[start] = nil end end
		end
	end, plotConnections)
	refreshPurchases()
end

local function crateArrival(prompt)
	if not prompt:IsA("ProximityPrompt") or prompt.Name ~= "LootPrompt" then return end
	local body = prompt.Parent
	if not body or not body:IsA("BasePart") then return end
	local landed = prompt.Enabled
	local ground = Vector3.new(body.Position.X, 0.25, body.Position.Z)
	if not landed and quality() ~= "Off" and near(ground, 170) then
		ring(ground, 7, GOLD, 1.2, "CrateArrival")
		particles(body.Position, TEAL, 8)
		local anchor = visualPart("CrateLandingMarker", Vector3.new(0.1, 0.1, 0.1), CFrame.new(ground), GOLD)
		if anchor then
			anchor.Transparency = 1
			local bottom, top = Instance.new("Attachment"), Instance.new("Attachment")
			bottom.Parent, top.Parent = anchor, anchor
			top.Position = Vector3.new(0, 12, 0)
			local beam = Instance.new("Beam")
			beam.Attachment0, beam.Attachment1 = bottom, top
			beam.Width0, beam.Width1, beam.FaceCamera, beam.LightEmission = 0.8, 0.15, true, 0.7
			beam.Color, beam.Transparency = ColorSequence.new(GOLD), NumberSequence.new(0.6)
			beam.Parent = anchor
			track(anchor, config and config.Airdrops.FallSeconds + 1 or 8)
		end
	end
	connect(prompt:GetPropertyChangedSignal("Enabled"), function()
		if not alive or landed or prompt.Enabled ~= true then return end
		landed = true
		if quality() ~= "Off" and body.Parent and near(body.Position, 150) then
			local point = Vector3.new(body.Position.X, 0.3, body.Position.Z)
			ring(point, 10, GOLD, 0.7, "CrateLanding")
			particles(point + Vector3.new(0, 1, 0), GOLD, 16)
		end
	end, crateConnections)
end
local function bindCrates(folder)
	disconnect(crateConnections)
	crateFolder = folder
	if not folder then return end
	local watched = {}
	local function inspectCrate(object)
		if object.Name == "LootPrompt" and not watched[object] then watched[object] = true; crateArrival(object) end
	end
	for _, object in ipairs(folder:GetDescendants()) do inspectCrate(object) end
	connect(folder.DescendantAdded, inspectCrate, crateConnections)
	-- Отсоединённые prompts не сохраняются между следующими грузами.
	connect(folder.ChildRemoved, function() task.defer(function() if alive and crateFolder == folder then bindCrates(folder) end end) end, crateConnections)
end
local function portals()
	local campus = Workspace:FindFirstChild("HeroCampus")
	if not campus then return end
	for _, name in ipairs({"ArenaPortal", "ReturnStand", "RebirthStand"}) do
		local pad = campus:FindFirstChild(name)
		if pad and pad:IsA("BasePart") and near(pad.Position, 90) then
			ring(pad.Position + Vector3.new(0, 0.32, 0), 4.5, pad.Color, 1.2, "PortalPulse")
		end
	end
end
local function clearTransient()
	for object in pairs(active) do removeEffect(object) end
	clearHighlights()
end
local function cleanup()
	if not alive then return end
	alive = false
	disconnect(connections)
	disconnect(plotConnections)
	disconnect(crateConnections)
	clearTransient()
	table.clear(pairsByStart)
	effects:Destroy()
end
connect(stopEvent.Event, cleanup)
connect(script.Destroying, cleanup)
connect(effects.Destroying, cleanup)
connect(player.CharacterRemoving, clearTransient)
connect(player:GetAttributeChangedSignal("EffectsQuality"), function() clearTransient(); refreshPurchases() end)
connect(player:GetAttributeChangedSignal("SoundEnabled"), function()
	if player:GetAttribute("SoundEnabled") == false then
		for object in pairs(active) do if object.Name == "CityFeedbackSound" then removeEffect(object) end end
	end
end)
for _, name in ipairs({"Coins", "Floor", "DropperTier", "PlotId", "Bank", "DataReady"}) do
	connect(player:GetAttributeChangedSignal(name), refreshPurchases)
end

task.spawn(function()
	local shared = ReplicatedStorage:WaitForChild("Shared", 30)
	local module = shared and shared:WaitForChild("TycoonConfig", 30)
	if alive and module and module:IsA("ModuleScript") then config = require(module); refreshPurchases() end
	local remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 30)
	if not alive or not remotes then return end
	local notice = remotes:WaitForChild("Notice", 30)
	local loot = remotes:WaitForChild("LootResult", 30)
	if not alive then return end
	if notice and notice:IsA("RemoteEvent") then
		connect(notice.OnClientEvent, function(payload)
			if type(payload) ~= "table" then return end
			if payload.kind == "success" or payload.kind == "reward" then feedbackSound(1.15)
			elseif payload.kind == "error" then feedbackSound(0.8) end
		end)
	end
	if loot and loot:IsA("RemoteEvent") then
		connect(loot.OnClientEvent, function(payload)
			if not config or type(payload) ~= "table" then return end
			local weapon = config.GetWeapon(payload.weaponId)
			local root = rootPart()
			if not weapon or not root then return end
			local color = Color3.fromRGB(weapon.Color[1], weapon.Color[2], weapon.Color[3])
			if quality() ~= "Off" then
				ring(root.Position - Vector3.new(0, 2.5, 0), 4, color, 0.7, "LootReward")
				particles(root.Position, color, if weapon.LootWeight <= 9 then 18 else 8)
			end
			feedbackSound(if weapon.LootWeight <= 9 then 1.45 else 1.2)
		end)
	end
end)

task.spawn(function()
	while alive do
		local currentPlots, currentCrates = Workspace:FindFirstChild("TycoonPlots"), Workspace:FindFirstChild("Airdrops")
		if currentPlots ~= plots then bindPlots(currentPlots) end
		if currentCrates ~= crateFolder then bindCrates(currentCrates) end
		if quality() ~= "Off" then
			for start, ending in pairs(pairsByStart) do
				if not start:IsDescendantOf(Workspace) or not ending:IsDescendantOf(Workspace) then pairsByStart[start] = nil
				elseif near(start.Position) then emit(start, ending) end
			end
			if os.clock() >= nextPortalAt then nextPortalAt = os.clock() + 3; portals() end
			refreshPurchases()
		end
		task.wait(if quality() == "Low" then 1.4 elseif quality() == "Off" then 2 else 0.8)
	end
end)
