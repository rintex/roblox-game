-- Только обратная связь: сервер определяет попадания, урон и награды.
-- Все эффекты локальные, с ограничением числа объектов и временем жизни.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local DEFAULT_COLOR = Color3.fromRGB(104, 224, 255)
local GOLD = Color3.fromRGB(255, 209, 101)
local RED = Color3.fromRGB(248, 100, 93)
local VIEW_DISTANCE = 210
local MAX_SEGMENT_LENGTH = 500
-- Текстура и звуки поставляются с Roblox, без загружаемых сторонних assets.
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SWISH_SOUND = "rbxasset://sounds/action_jump.mp3"

local oldFolder = Workspace:FindFirstChild("ClientHeroEffects")
if oldFolder then
	local oldStop = oldFolder:FindFirstChild("Stop")
	if oldStop and oldStop:IsA("BindableEvent") then oldStop:Fire() end
	oldFolder:Destroy()
end
local effects = Instance.new("Folder")
effects.Name = "ClientHeroEffects"
effects.Parent = Workspace
local stopEvent = Instance.new("BindableEvent")
stopEvent.Name = "Stop"
stopEvent.Parent = effects

local alive = true
local active, joints, targetGlows, connections = {}, {}, {}, {}
local activeCount = 0
local feedbackGui = nil
local nextSoundAt, nextHurtAt = 0, 0

local function quality()
	local value = player:GetAttribute("EffectsQuality")
	return if value == "Off" or value == "Low" then value else "High"
end

local function limit()
	return if quality() == "Off" then 8 elseif quality() == "Low" then 20 else 60
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function validVector(value)
	return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
		and math.abs(value.X) <= 1000000 and math.abs(value.Y) <= 1000000 and math.abs(value.Z) <= 1000000
end

local function effectColor(value)
	local r, g, b
	if typeof(value) == "Color3" then r, g, b = value.R, value.G, value.B
	elseif type(value) == "table" then
		r, g, b = value.r or value.R or value[1], value.g or value.G or value[2], value.b or value.B or value[3]
	end
	if not finite(r) or not finite(g) or not finite(b) then return DEFAULT_COLOR end
	if type(value) == "table" and math.max(r, g, b) > 1 then r, g, b = r / 255, g / 255, b / 255 end
	return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
end

local function focus()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	return root and root:IsA("BasePart") and root.Position or camera and camera.CFrame.Position
end

local function nearby(from, to)
	local point = focus()
	local distance = if quality() == "Low" then 120 else VIEW_DISTANCE
	return point and ((point - from).Magnitude <= distance or (point - to).Magnitude <= distance)
end

local function removeEffect(object)
	local entry = active[object]
	if not entry then return end
	active[object] = nil
	if entry.target and targetGlows[entry.target] == object then targetGlows[entry.target] = nil end
	activeCount -= 1
	if entry.connection then entry.connection:Disconnect() end
	if entry.tween then entry.tween:Cancel() end
	object:Destroy()
end

local function track(object, duration, tween)
	if not alive or activeCount >= limit() then object:Destroy(); return nil end
	activeCount += 1
	local entry = {tween = tween}
	active[object] = entry
	if tween then
		entry.connection = tween.Completed:Connect(function() removeEffect(object) end)
		tween:Play()
	end
	-- Резервная уборка также работает для отменённого tween и удалённой цели.
	task.delay(duration + 0.15, function() removeEffect(object) end)
	return object
end

local function part(name, size, cframe, color, shape, transparency, essential)
	if not alive or (quality() == "Off" and not essential) or activeCount >= limit() then return nil end
	local object = Instance.new("Part")
	object.Name = name
	object.Size, object.CFrame, object.Color = size, cframe, color
	object.Shape, object.Material = shape or Enum.PartType.Ball, Enum.Material.Neon
	object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
	object.CastShadow, object.Transparency = false, transparency or 0.15
	object.Parent = effects
	return object
end

local function animate(name, size, cframe, color, shape, duration, goals, transparency, essential)
	local object = part(name, size, cframe, color, shape, transparency, essential)
	if not object then return nil end
	local tween = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals)
	return track(object, duration, tween)
end

local function pulse(position, radius, color, duration, name)
	return animate(name or "ImpactRing", Vector3.new(0.1, 2, 2),
		CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.PartType.Cylinder, duration, {
			Size = Vector3.new(0.08, radius * 2, radius * 2), Transparency = 1,
		}, 0.65)
end

local function sparks(position, color, count, speed)
	if quality() ~= "High" then return end
	local anchor = part("ImpactParticles", Vector3.new(0.1, 0.1, 0.1), CFrame.new(position), color, nil, 1)
	if not anchor then return end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparks"
	emitter.Texture = SPARK_TEXTURE
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Lifetime = NumberRange.new(0.2, 0.45)
	emitter.Speed = NumberRange.new(speed or 4, (speed or 4) * 1.8)
	emitter.Drag = 4
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0)})
	emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	emitter.Parent = anchor
	if track(anchor, 0.65) then emitter:Emit(math.clamp(count or 8, 1, 20)) end
end

local function beam(from, target, color, width, duration, curved)
	if (target - from).Magnitude < 0.05 then return end
	local anchor = part("SkillBeamAnchor", Vector3.new(0.1, 0.1, 0.1), CFrame.new(from), color, nil, 1)
	if not anchor then return end
	local first, last = Instance.new("Attachment"), Instance.new("Attachment")
	first.Name, last.Name = "Origin", "Target"
	first.Parent, last.Parent = anchor, anchor
	last.Position = target - from
	local ray = Instance.new("Beam")
	ray.Name = "SkillBeam"
	ray.Attachment0, ray.Attachment1 = first, last
	ray.Color = ColorSequence.new(color)
	ray.Width0, ray.Width1 = width, width * 0.35
	ray.LightEmission, ray.FaceCamera = 0.9, true
	ray.Segments = if curved then 8 else 1
	ray.CurveSize0, ray.CurveSize1 = if curved then 1.4 else 0, if curved then -1.4 else 0
	ray.Transparency = NumberSequence.new(0.12)
	ray.Parent = anchor
	track(anchor, duration)
end

local function sound(kind, position, volume)
	if not alive or player:GetAttribute("SoundEnabled") == false or os.clock() < nextSoundAt then return end
	nextSoundAt = os.clock() + 0.12
	local anchor = Instance.new("Part")
	anchor.Name = "FeedbackSound"
	anchor.Size, anchor.CFrame = Vector3.new(0.1, 0.1, 0.1), CFrame.new(position)
	anchor.Transparency, anchor.Anchored = 1, true
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.CastShadow = false, false, false, false
	anchor.Parent = effects
	local audio = Instance.new("Sound")
	audio.Name = "LocalFeedback"
	audio.SoundId = SWISH_SOUND
	audio.Volume = volume or 0.12
	audio.PlaybackSpeed = if kind == "hurt" then 1.05 else 1.6
	audio.RollOffMinDistance, audio.RollOffMaxDistance = 8, 65
	audio.Parent = anchor
	if not track(anchor, 1.5) then return end
	-- При недоступном встроенном звуке визуальная обратная связь остаётся рабочей.
	pcall(function() audio:Play() end)
end

local function numberLabel(position, amount, critical)
	if not finite(amount) or amount <= 0 then return end
	local anchor = part("DamageNumber", Vector3.new(0.1, 0.1, 0.1), CFrame.new(position + Vector3.new(0, 2.8, 0)), DEFAULT_COLOR, nil, 1)
	if not anchor then return end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Damage"
	gui.Size, gui.AlwaysOnTop, gui.MaxDistance = UDim2.fromOffset(120, 48), true, 120
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	text.Font, text.TextSize = Enum.Font.GothamBold, if critical then 28 else 22
	text.Text = "−" .. tostring(math.clamp(math.floor(amount), 1, 99999))
	text.TextColor3 = if critical then GOLD else Color3.fromRGB(244, 250, 255)
	text.TextStrokeColor3, text.TextStrokeTransparency = Color3.fromRGB(28, 34, 48), 0.25
	text.Parent = gui
	local tween = TweenService:Create(anchor, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = anchor.CFrame + Vector3.new(0, 2, 0),
	})
	track(anchor, 0.75, tween)
end

local function highlight(target, color)
	if typeof(target) ~= "Instance" or not target:IsA("Model") or not target:IsDescendantOf(Workspace)
		or activeCount >= limit() then return end
	if targetGlows[target] then removeEffect(targetGlows[target]) end
	local glow = Instance.new("Highlight")
	glow.Name = "HitHighlight"
	glow.Adornee = target
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.FillColor, glow.OutlineColor = color, color
	glow.FillTransparency, glow.OutlineTransparency = 0.6, 0.15
	glow.Parent = effects
	if track(glow, 0.2, TweenService:Create(glow, TweenInfo.new(0.2), {FillTransparency = 1, OutlineTransparency = 1})) then
		active[glow].target = target
		targetGlows[target] = glow
	end
end

local function resetJoint(joint)
	local entry = joints[joint]
	if not entry then return end
	joints[joint] = nil
	if entry.tween then entry.tween:Cancel() end
	if joint.Parent then joint.C0 = entry.rest end
end

local function attackPose(actorUserId, kind)
	-- Короткая процедурная поза, без опубликованных чужих animation IDs.
	if actorUserId ~= player.UserId then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local joint
	for _, item in ipairs(character:GetDescendants()) do
		if item:IsA("Motor6D") and (item.Name == "RightShoulder" or item.Name == "Right Shoulder") then joint = item; break end
	end
	if not joint then return end
	resetJoint(joint)
	local entry = {rest = joint.C0}
	joints[joint] = entry
	local angle = if kind == "slam" then -1.15 else -0.55
	entry.tween = TweenService:Create(joint, TweenInfo.new(0.07), {C0 = entry.rest * CFrame.Angles(angle, 0, -0.12)})
	entry.tween:Play()
	task.delay(0.09, function()
		if joints[joint] ~= entry then return end
		if not alive or not joint.Parent or player.Character ~= character then resetJoint(joint); return end
		entry.tween:Cancel()
		entry.tween = TweenService:Create(joint, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {C0 = entry.rest})
		entry.tween:Play()
	end)
	task.delay(0.3, function() if joints[joint] == entry then resetJoint(joint) end end)
end

local function hurt(amount)
	if os.clock() < nextHurtAt or not finite(amount) or amount <= 0 then return end
	nextHurtAt = os.clock() + 0.16
	local guiParent = player:FindFirstChild("PlayerGui")
	if not guiParent then return end
	if not feedbackGui then
		feedbackGui = Instance.new("ScreenGui")
		feedbackGui.Name = "CombatFeedbackHUD"
		feedbackGui.ResetOnSpawn, feedbackGui.IgnoreGuiInset, feedbackGui.DisplayOrder = false, true, 4
		feedbackGui.Parent = guiParent
	end
	local flash = Instance.new("Frame")
	flash.Name = "DamageFlash"
	flash.Size, flash.BackgroundColor3, flash.BackgroundTransparency = UDim2.fromScale(1, 1), RED, 0.92
	flash.BorderSizePixel, flash.Active = 0, false
	flash.Parent = feedbackGui
	track(flash, 0.38, TweenService:Create(flash, TweenInfo.new(0.38), {BackgroundTransparency = 1}))
end

local ATTACKS = {web = true, repulsor = true, lightning = true, slam = true, beam = true, projectile = true, blast = true}
local function render(payload)
	if not alive or type(payload) ~= "table" or type(payload.kind) ~= "string" then return end
	local from, target = payload.from, payload.to
	if not validVector(from) or not validVector(target) or (target - from).Magnitude > MAX_SEGMENT_LENGTH
		or not nearby(from, target) then return end
	local kind, color = payload.kind, effectColor(payload.color)
	if kind == "hurt" and payload.victimUserId == player.UserId then
		if not finite(payload.amount) or payload.amount <= 0 then return end
		sound("hurt", target, 0.1)
		if quality() ~= "Off" then hurt(payload.amount) end
		return
	end
	-- Предупреждение об опасной атаке — часть управления боем, видно даже без VFX.
	if quality() == "Off" and kind ~= "boss_warning" then
		return
	end
	if kind == "hit" then
		if payload.actorUserId == player.UserId then numberLabel(target, payload.amount, payload.boss == true) end
		highlight(payload.target, color)
		sparks(target, color, 6, 3)
		return
	elseif kind == "victory" then
		local radius = if payload.boss == true then 14 else 5
		pulse(Vector3.new(target.X, 0.35, target.Z), radius, GOLD, 0.7, "VictoryRing")
		sparks(target + Vector3.new(0, 1.5, 0), GOLD, if payload.boss == true then 20 else 8, 9)
		-- Звук победы воспроизводит обработчик серверного Notice, без двойного ping.
		return
	elseif kind == "boss_warning" then
		local radius = if finite(payload.radius) then math.clamp(payload.radius, 1, 32) else 8
		local duration = if finite(payload.duration) then math.clamp(payload.duration, 0.15, 3) else 0.7
		from, target = Vector3.new(from.X, 0.35, from.Z), Vector3.new(target.X, 0.35, target.Z)
		if payload.style == "rush" and (target - from).Magnitude > 0.05 then
			animate("BossRushWarning", Vector3.new(radius * 2, 0.08, (target - from).Magnitude + radius * 2),
				CFrame.lookAt((from + target) / 2, target), RED, Enum.PartType.Block, duration, {Transparency = 0.68}, 0.9, true)
		else
			animate("BossAreaWarning", Vector3.new(0.07, radius * 2, radius * 2),
				CFrame.new(target) * CFrame.Angles(0, 0, math.pi / 2), RED, Enum.PartType.Cylinder, duration,
				{Transparency = 0.65}, 0.88, true)
		end
		return
	elseif kind == "boss_impact" then
		local radius = if finite(payload.radius) then math.clamp(payload.radius, 1, 32) else 8
		pulse(Vector3.new(target.X, 0.35, target.Z), radius, RED, 0.5, "BossImpact")
		sparks(target, RED, 16, 7)
		return
	end
	if not ATTACKS[kind] then return end
	attackPose(payload.actorUserId, kind)
	if payload.actorUserId == player.UserId then sound("attack", from, 0.07) end
	if kind == "slam" then
		local radius = if finite(payload.radius) then math.clamp(payload.radius, 1, 24) else 12
		pulse(Vector3.new(target.X, 0.35, target.Z), radius, color, 0.45, "HeroSlamPulse")
		sparks(target, color, 12, 7)
	elseif kind == "lightning" then
		local delta = target - from
		local segments = if quality() == "Low" then 2 else 5
		local previous = from
		for index = 1, segments do
			local nextPoint = from + delta * (index / segments)
			if index < segments then nextPoint += Vector3.new(if index % 2 == 0 then 0.8 else -0.8, 0.5, 0) end
			beam(previous, nextPoint, color, 0.32, 0.2)
			previous = nextPoint
		end
		sparks(target, color, 8, 5)
	elseif kind == "web" then
		beam(from, target, Color3.fromRGB(235, 246, 252), 0.14, 0.3, true)
		pulse(target, 2.1, color, 0.25, "WebContact")
	elseif kind == "projectile" then
		animate("HeroProjectile", Vector3.new(0.8, 0.8, 0.8), CFrame.new(from), color, nil, 0.18,
			{CFrame = CFrame.new(target), Size = Vector3.new(0.35, 0.35, 0.35), Transparency = 0.8})
		beam(from, target, color, 0.13, 0.12)
	else
		beam(from, target, color, if kind == "repulsor" then 0.5 else 0.25, 0.17)
		animate("HeroImpact", Vector3.new(0.45, 0.45, 0.45), CFrame.new(target), color, nil, 0.25,
			{Size = Vector3.new(2.2, 2.2, 2.2), Transparency = 1})
		sparks(target, color, 8, 4)
	end
end

local function clearTransient()
	for object in pairs(active) do removeEffect(object) end
	for joint in pairs(joints) do resetJoint(joint) end
end

local function cleanup()
	if not alive then return end
	alive = false
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
	clearTransient()
	if feedbackGui then feedbackGui:Destroy(); feedbackGui = nil end
	effects:Destroy()
end

table.insert(connections, stopEvent.Event:Connect(cleanup))
table.insert(connections, script.Destroying:Connect(cleanup))
table.insert(connections, effects.Destroying:Connect(cleanup))
table.insert(connections, player.CharacterRemoving:Connect(clearTransient))
table.insert(connections, player:GetAttributeChangedSignal("EffectsQuality"):Connect(clearTransient))
table.insert(connections, player:GetAttributeChangedSignal("SoundEnabled"):Connect(function()
	if player:GetAttribute("SoundEnabled") == false then
		for object in pairs(active) do if object.Name == "FeedbackSound" then removeEffect(object) end end
	end
end))

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 30)
	if not alive or not remotes then return end
	local remote = remotes:WaitForChild("Effect", 30)
	if not alive or not remote or not remote:IsA("RemoteEvent") then return end
	table.insert(connections, remote.OnClientEvent:Connect(render))
end)
