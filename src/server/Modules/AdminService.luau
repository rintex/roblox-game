-- Only the experience owner / explicit allowlist may use this remote.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Service={};Service.__index=Service
function Service.new(config,profiles,tycoon,notice,request)
 return setmetatable({config=config,profiles=profiles,tycoon=tycoon,notice=notice,request=request,states={},connections={}},Service)
end
function Service:IsAuthorized(player)
 if RunService:IsStudio() and game.GameId==0 then return true end
 for _,id in ipairs(self.config.AdminUserIds or {}) do if id>0 and id==player.UserId then return true end end
 if game.CreatorId<=0 then return false end
 if game.CreatorType==Enum.CreatorType.User then return player.UserId==game.CreatorId end
 if game.CreatorType==Enum.CreatorType.Group then
  local ok,rank=pcall(function() return player:GetRankInGroup(game.CreatorId) end)
  return ok and rank==255
 end
 return false
end
function Service:_add(player)
 local authorized=self:IsAuthorized(player)
 if player.Parent~=Players then return end
 self.states[player]={authorized=authorized,last=-math.huge}
 player:SetAttribute('IsGameAdmin',authorized)
end
function Service:_request(player,command)
 local state=self.states[player]
 if not state or not state.authorized or player.Parent~=Players or type(command)~='string' then return end
 if self.profiles:IsClosing() or player:GetAttribute('DataReady')~=true then return end
 local profile=self.profiles:Get(player);if not profile then return end
 local now=os.clock();if now-state.last<1 then return end;state.last=now
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass('Humanoid')
 if command=='GrantCoins' then
  profile.Coins=math.min(self.config.MaxCoins,profile.Coins+25000);self.tycoon:SyncPlayer(player)
 elseif command=='Heal' then
  if humanoid and humanoid.Health>0 then humanoid.Health=humanoid.MaxHealth end
 elseif command=='TeleportHome' then
  player:SetAttribute('ArenaCombatOptIn',false)
  local root=character and character:FindFirstChild('HumanoidRootPart')
  local target=Vector3.new(0,5,14)
  local state=self.tycoon:GetState(player)
  if state and state.plot then local base=state.plot:FindFirstChild('Base');if base then target=base.Position+Vector3.new(0,5,-20) end end
  if root and humanoid and humanoid.Health>0 then root.CFrame=CFrame.new(target) end
 elseif command=='PreviewVIP' or command=='PreviewNeon' then
  if not RunService:IsStudio() then return end
  local attribute=if command=='PreviewVIP' then 'HasVIP' else 'HasNeon'
  player:SetAttribute(attribute,player:GetAttribute(attribute)~=true)
 else return end
 self.notice:FireClient(player,{kind='info',text='Команда владельца выполнена.'})
end
function Service:Start()
 table.insert(self.connections,self.request.OnServerEvent:Connect(function(player,command) self:_request(player,command) end))
 table.insert(self.connections,Players.PlayerAdded:Connect(function(player) task.spawn(function() self:_add(player) end) end))
 table.insert(self.connections,Players.PlayerRemoving:Connect(function(player) self.states[player]=nil end))
 for _,player in ipairs(Players:GetPlayers()) do task.spawn(function() self:_add(player) end) end
end
function Service:Destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end;table.clear(self.states)
end
return Service
