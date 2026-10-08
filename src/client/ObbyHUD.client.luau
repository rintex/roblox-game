-- Only the server advances course checkpoints; the client displays its state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(shared:WaitForChild("TycoonConfig"))
local Theme = require(shared:WaitForChild("UITheme"))
local request = ReplicatedStorage:WaitForChild("TycoonRemotes"):WaitForChild("ObbyRequest")
local old = playerGui:FindFirstChild("RooftopObbyHUD")
if old then
 local stop = old:FindFirstChild("Stop")
 if stop then stop:Fire() end
 old:Destroy()
end
local scope = Theme.Scope()
local gui = Theme.Make("ScreenGui", {Name = "RooftopObbyHUD", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 18, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
local stop = Theme.Make("BindableEvent", {Name = "Stop"}, gui)
local panel = Theme.Make("Frame", {Name = "CourseStatus", AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, 10), Size = UDim2.new(1, -28, 0, 172), BackgroundColor3 = Theme.Colors.panel, BorderSizePixel = 0, Visible = false}, gui)
Theme.Surface(panel, 18, Theme.Colors.gold)
Theme.Make("UISizeConstraint", {MaxSize = Vector2.new(420, 172)}, panel)
local entryScale = Theme.Make("UIScale", {Scale = 1}, panel)
Theme.Icon(panel, "star", Theme.Colors.gold, UDim2.fromOffset(19, 19), UDim2.fromOffset(14, 12))
Theme.Label(panel, "Title", "КРЫШИ КВАРТАЛА", UDim2.new(1, -68, 0, 25), UDim2.fromOffset(43, 9), 16, Theme.Colors.gold)
local progress = Theme.Label(panel, "Progress", "", UDim2.new(1, -28, 0, 24), UDim2.fromOffset(14, 37), 13)
local track = Theme.Make("Frame", {Name = "CourseTrack", Position = UDim2.fromOffset(14, 66), Size = UDim2.new(1, -28, 0, 5), BackgroundColor3 = Theme.Colors.card, BorderSizePixel = 0}, panel)
Theme.Round(track, 3)
local fill = Theme.Make("Frame", {Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Colors.gold, BorderSizePixel = 0}, track)
Theme.Round(fill, 3)
local best = Theme.Label(panel, "Best", "", UDim2.new(1, -28, 0, 32), UDim2.fromOffset(14, 77), 11, Theme.Colors.muted)
local lastRequest = -math.huge
for index, definition in ipairs({{"Checkpoint", "К точке"}, {"Exit", "В город"}}) do
 local button = Theme.Button(scope, panel, definition[1], definition[2], UDim2.new(.5, -21, 0, 44), UDim2.new((index - 1) * .5, 14 - (index - 1) * 7, 0, 116), if index == 1 then Theme.Colors.gold else nil)
 scope:Connect(button.Activated, function()
  if player:GetAttribute("ObbyActive") ~= true or os.clock() - lastRequest < 1 then return end
  lastRequest = os.clock()
  request:FireServer(definition[1])
 end)
end

local active = false
local function update()
 if not scope.alive then return end
 local nextActive = player:GetAttribute("ObbyActive") == true
 if nextActive ~= active then
  active = nextActive
  panel.Visible = active
  if active then
   Theme.CloseAll()
   entryScale.Scale = .95
   scope:Tween(entryScale, .18, {Scale = 1})
  end
 end
 if not active then return end
 local stage = player:GetAttribute("ObbyStage") or 1
 local checkpoint = player:GetAttribute("ObbyCheckpoint") or 1
 local started = player:GetAttribute("ObbyStartedAt") or Workspace:GetServerTimeNow()
 local elapsed = math.max(0, Workspace:GetServerTimeNow() - started)
 progress.Text = "Этап " .. stage .. " / " .. #Config.Obby.Platforms .. "   ·   " .. string.format("%.1f", elapsed) .. " сек."
 fill.Size = UDim2.fromScale(math.clamp((stage - 1) / math.max(1, #Config.Obby.Platforms - 1), 0, 1), 1)
 local record = player:GetAttribute("ObbyBestMilliseconds") or 0
 best.Text = "Контрольная точка " .. checkpoint .. " · падения не сбрасывают маршрут\n" .. (if record > 0 then "Рекорд " .. string.format("%.1f", record / 1000) .. " с · побед " .. (player:GetAttribute("ObbyWins") or 0) else "Награда: +" .. Config.Obby.RewardCoins .. " монет и +" .. Config.Obby.RewardXP .. " XP")
end
for _, name in ipairs({"ObbyActive", "ObbyStage", "ObbyCheckpoint", "ObbyStartedAt", "ObbyWins", "ObbyBestMilliseconds"}) do scope:Connect(player:GetAttributeChangedSignal(name), update) end
local function cleanup()
 if not scope.alive then return end
 scope:Destroy()
 gui:Destroy()
end
scope:Connect(stop.Event, cleanup)
scope:Connect(script.Destroying, cleanup)
update()
task.spawn(function()
 while scope.alive do
  task.wait(.2)
  if active then update() end
 end
end)
