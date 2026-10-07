-- Наступание на стенд меняет костюм. Нового RemoteEvent для этого не требуется.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Service = {}
Service.__index = Service

function Service.new(config, heroes, campus)
	return setmetatable({config = config, heroes = heroes, campus = campus, connections = {}, lastTouch = {}}, Service)
end

function Service:_equip(player, pad, id)
	if not pad:IsDescendantOf(Workspace) or player.Parent ~= Players or player:GetAttribute("ObbyActive") == true then return end
	local profile = self.heroes:_profile(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not profile or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return end
	local delta = root.Position - pad.Position
	-- Touch можно подделать через физику: отдельно проверяем положение тела на площадке.
	if delta.X ~= delta.X or delta.Y ~= delta.Y or delta.Z ~= delta.Z
		or math.abs(delta.X) > pad.Size.X / 2 + 0.5 or math.abs(delta.Z) > pad.Size.Z / 2 + 0.5
		or delta.Y < pad.Size.Y / 2 or delta.Y > pad.Size.Y / 2 + 5.5 then return end
	if profile.EquippedHero == id and (profile.EquippedWeapon or "") == "" then return end
	local now = os.clock()
	if now - (self.lastTouch[player] or -math.huge) < 1.2 then return end
	self.lastTouch[player] = now
	local ok, message = self.heroes:Equip(player, id)
	self.heroes:_notify(player, message, ok and "success" or "info")
end

function Service:Start()
	assert(not self.started, "CostumePadService уже запущен")
	self.started = true
	local gallery = self.campus:WaitForChild("Gallery")
	for _, model in ipairs(gallery:GetChildren()) do
		local id = model:GetAttribute("HeroId")
		local pad = model:FindFirstChild("Pedestal")
		assert(self.config.GetHero(id) and pad and pad:IsA("BasePart"), "Некорректный стенд костюма")
		pad.CanTouch = true
		table.insert(self.connections, pad.Touched:Connect(function(hit)
			local node = hit
			while node and node ~= Workspace do
				if node:IsA("Model") then
					local player = Players:GetPlayerFromCharacter(node)
					if player then self:_equip(player, pad, id); return end
				end
				node = node.Parent
			end
		end))
	end
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self.lastTouch[player] = nil end))
end

function Service:Destroy()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
	table.clear(self.lastTouch)
end

return Service
