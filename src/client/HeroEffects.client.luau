-- Косметические эффекты. Здесь нет урона, наград или запросов боевых действий.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local EFFECT_LIMIT = 36
local VIEW_DISTANCE = 400
local MAX_SEGMENT_LENGTH = 500
local DEFAULT_COLOR = Color3.fromRGB(104, 224, 255)

local oldFolder = Workspace:FindFirstChild("ClientHeroEffects")
if oldFolder then
	local oldStop = oldFolder:FindFirstChild("Stop")
	if oldStop and oldStop:IsA("BindableEvent") then
		oldStop:Fire()
	end
	oldFolder:Destroy()
end

local effects = Instance.new("Folder")
effects.Name = "ClientHeroEffects"
effects.Parent = Workspace
local stopEvent = Instance.new("BindableEvent")
stopEvent.Name = "Stop"
stopEvent.Parent = effects

local alive = true
local activeCount = 0
local active = {}
local connections = {}

local function finite(number)
	return type(number) == "number" and number == number
		and number > -math.huge and number < math.huge
end

local function validVector(value)
	return typeof(value) == "Vector3"
		and finite(value.X) and finite(value.Y) and finite(value.Z)
		and math.abs(value.X) <= 1000000
		and math.abs(value.Y) <= 1000000
		and math.abs(value.Z) <= 1000000
end

local function effectColor(value)
	local r, g, b
	if typeof(value) == "Color3" then
		r, g, b = value.R, value.G, value.B
	elseif type(value) == "table" then
		r = value.r or value.R or value[1]
		g = value.g or value.G or value[2]
		b = value.b or value.B or value[3]
	end
	if not finite(r) or not finite(g) or not finite(b) then
		return DEFAULT_COLOR
	end
	-- Поддерживаем как {0..1, 0..1, 0..1}, так и обычные RGB 0..255.
	if type(value) == "table" and math.max(r, g, b) > 1 then
		r, g, b = r / 255, g / 255, b / 255
	end
	return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
end

local function removeEffect(part)
	local entry = active[part]
	if not entry then
		return
	end
	active[part] = nil
	activeCount -= 1
	entry.connection:Disconnect()
	entry.tween:Cancel()
	part:Destroy()
end

local function animate(name, size, cframe, color, shape, duration, goals)
	if not alive or activeCount >= EFFECT_LIMIT then
		return
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Shape = shape
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 0.15
	part.Parent = effects
	local tween = TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals)
	local entry = { tween = tween }
	active[part] = entry
	activeCount += 1
	entry.connection = tween.Completed:Connect(function()
		removeEffect(part)
	end)
	tween:Play()
	-- Резервное удаление, если Tween был прерван.
	task.delay(duration + 0.2, function()
		removeEffect(part)
	end)
end

local function render(payload)
	if not alive or type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	local from, target = payload.from, payload.to
	if not validVector(from) or not validVector(target) then
		return
	end
	local displacement = target - from
	local distance = displacement.Magnitude
	if distance > MAX_SEGMENT_LENGTH then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	local focus = root and root:IsA("BasePart") and root.Position or camera and camera.CFrame.Position
	if focus and (focus - from).Magnitude > VIEW_DISTANCE and (focus - target).Magnitude > VIEW_DISTANCE then
		return
	end
	local color = effectColor(payload.color)
	if payload.kind == "slam" then
		-- Пульс радиусом 12 studs не взаимодействует с игровым миром.
		animate("HeroSlamPulse", Vector3.new(2, 1, 2), CFrame.new(target), color, Enum.PartType.Ball, 0.45, {
			Size = Vector3.new(24, 2, 24),
			Transparency = 1,
		})
		return
	end
	if distance > 0.05 then
		local thickness = payload.kind == "web" and 0.18 or 0.35
		animate("HeroSkillBeam", Vector3.new(thickness, thickness, distance), CFrame.lookAt((from + target) / 2, target), color, Enum.PartType.Block, 0.24, {
			Transparency = 1,
		})
		if payload.kind == "projectile" or payload.kind == "blast" then
			animate("HeroProjectile", Vector3.new(1.3, 1.3, 1.3), CFrame.new(from), color, Enum.PartType.Ball, 0.22, {
				CFrame = CFrame.new(target),
				Size = Vector3.new(0.4, 0.4, 0.4),
				Transparency = 1,
			})
		end
	end
	animate("HeroImpact", Vector3.new(0.8, 0.8, 0.8), CFrame.new(target), color, Enum.PartType.Ball, 0.3, {
		Size = Vector3.new(3, 3, 3),
		Transparency = 1,
	})
end

local function cleanup()
	if not alive then
		return
	end
	alive = false
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	for part in pairs(active) do
		removeEffect(part)
	end
	effects:Destroy()
end

table.insert(connections, stopEvent.Event:Connect(cleanup))
table.insert(connections, script.Destroying:Connect(cleanup))
table.insert(connections, effects.Destroying:Connect(cleanup))

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("TycoonRemotes", 30)
	if not alive or not remotes then
		return
	end
	local remote = remotes:WaitForChild("Effect", 30)
	if not alive or not remote or not remote:IsA("RemoteEvent") then
		return
	end
	table.insert(connections, remote.OnClientEvent:Connect(render))
end)
