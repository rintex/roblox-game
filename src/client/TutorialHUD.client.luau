-- Подсказка ведёт к реальному объекту; выполнение и награды определяет сервер.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(shared:WaitForChild("TycoonConfig"))
local Theme = require(shared:WaitForChild("UITheme"))
local previous = playerGui:FindFirstChild("QuarterTutorialHUD")
if previous then
	local stop = previous:FindFirstChild("Stop")
	if stop then stop:Fire() end
	previous:Destroy()
end
local scope = Theme.Scope()
local gui = Theme.Make("ScreenGui", {Name = "QuarterTutorialHUD", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 5, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
local stop = Theme.Make("BindableEvent", {Name = "Stop"}, gui)
local bounds = Theme.Make("Frame", {Name = "Bounds", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0}, gui)
local banner = Theme.Make("Frame", {Name = "NextGoal", AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, 108), Size = UDim2.fromOffset(420, 56), BackgroundColor3 = Theme.Colors.panel, BackgroundTransparency = .08, BorderSizePixel = 0, ZIndex = 1, Visible = false}, bounds)
Theme.Surface(banner, 12, Theme.Colors.teal)
local title = Theme.Label(banner, "Title", "", UDim2.new(1, -88, 0, 20), UDim2.fromOffset(12, 4), 13, Theme.Colors.teal)
local description = Theme.Label(banner, "Description", "", UDim2.new(1, -24, 0, 27), UDim2.fromOffset(12, 24), 11, Theme.Colors.text)
local distance = Theme.Label(banner, "Distance", "", UDim2.fromOffset(66, 20), UDim2.new(1, -76, 0, 4), 11, Theme.Colors.gold)
distance.TextXAlignment = Enum.TextXAlignment.Right
local glow = Theme.Make("Highlight", {Name = "QuarterTutorialTarget", Enabled = false, FillColor = Theme.Colors.teal, OutlineColor = Theme.Colors.gold, FillTransparency = .88, OutlineTransparency = .25, DepthMode = Enum.HighlightDepthMode.Occluded}, Workspace)
local shortDescriptions = {"Займи свободный дом · E / экранная кнопка.", "Построй первый этаж на синей площадке.", "Забери монеты из зелёной копилки.", "Улучши генератор на фиолетовой площадке.", "Наступи на стенд первого героя.", "Войди на арену и попади по бандиту."}

local function targetFor(step, root)
	local plots = Workspace:FindFirstChild("TycoonPlots")
	local ownPlot
	if plots then
		local nearest, best
		for _, plot in ipairs(plots:GetChildren()) do
			if plot:GetAttribute("OwnerUserId") == player.UserId then ownPlot = plot end
			if step == 1 and plot:GetAttribute("OwnerUserId") == 0 then
				local pad = plot:FindFirstChild("ClaimPad")
				local value = pad and (root.Position - pad.Position).Magnitude
				if value and (not best or value < best) then nearest, best = pad, value end
			end
		end
		if step == 1 then return nearest end
	end
	if step >= 2 and step <= 4 then
		local names = {[2] = "UpgradePad", [3] = "Collector", [4] = "DropperUpgradePad"}
		return ownPlot and ownPlot:FindFirstChild(names[step])
	end
	local campus = Workspace:FindFirstChild("HeroCampus")
	if step == 5 then
		local gallery = campus and campus:FindFirstChild("Gallery")
		if gallery then
			for _, model in ipairs(gallery:GetChildren()) do
				if model:GetAttribute("HeroId") == Config.Heroes[1].Id then return model:FindFirstChild("Pedestal") end
			end
		end
	elseif step == 6 then
		if player:GetAttribute("ArenaCombatOptIn") ~= true then return campus and campus:FindFirstChild("ArenaPortal") end
		local enemies = Workspace:FindFirstChild("TrainingEnemies")
		local nearest, best
		if enemies then
			for _, model in ipairs(enemies:GetChildren()) do
				if model:GetAttribute("Alive") == true and model.PrimaryPart then
					local value = (root.Position - model.PrimaryPart.Position).Magnitude
					if not best or value < best then nearest, best = model.PrimaryPart, value end
				end
			end
		end
		return nearest
	end
	return nil
end

local function refresh()
	if not scope.alive then return end
	local modal = playerGui:GetAttribute("QuarterModalOpen")
	local step = player:GetAttribute("TutorialStep") or 1
	local definition = Config.TutorialSteps[step]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local compact = bounds.AbsoluteSize.Y < 440
	local hidden = not definition or (type(modal) == "string" and modal ~= "") or player:GetAttribute("ObbyActive") == true
		or (compact and playerGui:GetAttribute("QuarterToastOpen") == true)
	banner.Visible = not hidden
	local width = math.min(420, math.max(240, bounds.AbsoluteSize.X - 28))
	banner.Size = UDim2.fromOffset(width, if compact then 46 else 56)
	banner.Position = UDim2.new(.5, 0, 0, if compact then 98 else 108)
	description.Size = UDim2.new(1, -24, 0, if compact then 17 else 27)
	if hidden then glow.Enabled = false; return end
	if player:GetAttribute("DataReady") ~= true then
		title.Text = if player:GetAttribute("PersistenceStatus") == "error" then "Прогресс не удалось загрузить" else "Загружаем твой квартал…"
		description.Text = if player:GetAttribute("PersistenceStatus") == "error" then "Переподключись: сохранение остаётся защищённым." else "Покупки откроются после загрузки."
		distance.Text = ""; glow.Enabled = false; return
	end
	title.Text = step .. "/" .. #Config.TutorialSteps .. " · " .. definition.Title
	description.Text = if compact then shortDescriptions[step] else definition.Description
	local target = root and targetFor(step, root)
	if not root then description.Text = "Ждём появления персонажа…"
	elseif step == 1 and not target then description.Text = "Все дома заняты. Подожди свободного участка." end
	if target and target:IsA("BasePart") then
		local value = (root.Position - target.Position).Magnitude
		distance.Text = if value <= 10 then "Рядом" else "→ " .. math.floor(value)
		glow.Adornee = target
		glow.Enabled = player:GetAttribute("EffectsQuality") ~= "Off"
	else distance.Text = ""; glow.Enabled = false end
end

local elapsed = 0
scope:Connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= .35 then elapsed = 0; refresh() end
end)
for _, name in ipairs({"TutorialStep", "DataReady", "PlotId", "ArenaCombatOptIn", "ObbyActive", "PersistenceStatus", "EffectsQuality"}) do scope:Connect(player:GetAttributeChangedSignal(name), refresh) end
scope:Connect(playerGui:GetAttributeChangedSignal("QuarterModalOpen"), refresh)
scope:Connect(playerGui:GetAttributeChangedSignal("QuarterToastOpen"), refresh)
scope:Connect(bounds:GetPropertyChangedSignal("AbsoluteSize"), refresh)
local function cleanup()
	if not scope.alive then return end
	scope:Destroy()
	glow:Destroy()
	gui:Destroy()
end
scope:Connect(stop.Event, cleanup)
scope:Connect(script.Destroying, cleanup)
refresh()
