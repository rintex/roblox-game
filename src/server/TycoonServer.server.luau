-- Небольшая точка входа: карта, сохранения и экономика находятся в модулях.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TycoonConfig"))
local modules = script.Parent:WaitForChild("Modules")
local ProfileService = require(modules:WaitForChild("ProfileService"))
local HouseWorld = require(modules:WaitForChild("HouseWorld"))
local TycoonService = require(modules:WaitForChild("TycoonService"))
local notice = ReplicatedStorage:WaitForChild("TycoonRemotes"):WaitForChild("Notice")

local map = Workspace:WaitForChild("SimulatorMap")
if map:GetAttribute("MapReady") ~= true then
	-- Stage1Map создаёт геометрию до установки MapReady.
	while map.Parent and map:GetAttribute("MapReady") ~= true do
		map:GetAttributeChangedSignal("MapReady"):Wait()
	end
end

local plots = HouseWorld.BuildPlots(Workspace, config)
local profiles = ProfileService.new(config)
local tycoon = TycoonService.new(config, profiles, HouseWorld, plots, notice)
tycoon:Start()

print("Домики готовы: займите участок, стройте 3 этажа, забирайте монеты и улучшайте генератор.")
