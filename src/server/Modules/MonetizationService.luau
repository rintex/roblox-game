-- Game Pass ownership is checked by Roblox; clients never grant entitlements.
local Players=game:GetService('Players')
local MarketplaceService=game:GetService('MarketplaceService')
local Service={};Service.__index=Service
function Service.new(config,profiles,notice,request)
 return setmetatable({config=config,profiles=profiles,notice=notice,request=request,connections={},states={},destroyed=false},Service)
end
local function create(parent,class,name)
 local object=parent:FindFirstChild(name)
 if object then if object:IsA(class) then return object else return nil end end
 object=Instance.new(class);object.Name=name;object.Parent=parent;return object
end
function Service:_cosmetics(player)
 if self.destroyed or not self.states[player] or player.Parent~=Players then return end
 local character=player.Character
 if character then
  local head=character:FindFirstChild('Head')
  if head then
   local title=head:FindFirstChild('HeroClubTitle')
   local earned=player:GetAttribute('DisplayTitle')
   earned=if type(earned)=='string' and #earned<=240 then earned else ''
   local vip=player:GetAttribute('HasVIP')==true
   if vip or earned~='' then
    title=create(head,'BillboardGui','HeroClubTitle')
    if title then
     title.Size=UDim2.fromOffset(220,34);title.StudsOffset=Vector3.new(0,2.5,0);title.MaxDistance=75
     local label=create(title,'TextLabel','Title')
     if label then
      label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1
      label.Text=if vip and earned~='' then 'КЛУБ ГЕРОЕВ · '..earned elseif vip then 'КЛУБ ГЕРОЕВ' else earned
      label.TextColor3=if vip then Color3.fromRGB(255,218,89) else Color3.fromRGB(101,225,196)
      label.Font=Enum.Font.GothamBold;label.TextScaled=true
     end
    end
   elseif title then title:Destroy() end
  end
 end
 local containers={}
 if character then table.insert(containers,character) end
 local backpack=player:FindFirstChildOfClass('Backpack');if backpack then table.insert(containers,backpack) end
 for _,container in ipairs(containers) do
  for _,tool in ipairs(container:GetChildren()) do
   if tool:IsA('Tool') and tool:GetAttribute('HeroWeapon') then
    local handle=tool:FindFirstChild('Handle')
    if handle and handle:IsA('BasePart') then
     if player:GetAttribute('HasNeon')==true then
      local a=create(handle,'Attachment','HeroNeonA');local b=create(handle,'Attachment','HeroNeonB')
      local trail=create(handle,'Trail','HeroNeonTrail')
      if a and b and trail then
       a.Position=Vector3.new(0,0.5,0);b.Position=Vector3.new(0,-0.5,0)
       trail.Attachment0=a;trail.Attachment1=b;trail.Lifetime=0.25
       trail.Color=ColorSequence.new(Color3.fromRGB(91,233,239));trail.Transparency=NumberSequence.new(0.25)
      end
     else
      for _,name in ipairs({'HeroNeonTrail','HeroNeonA','HeroNeonB'}) do
       local object=handle:FindFirstChild(name);if object then object:Destroy() end
      end
     end
    end
   end
  end
 end
end
function Service:_ready(player)
 return not self.destroyed and self.states[player]~=nil and player.Parent==Players and player:GetAttribute('DataReady')==true
  and self.profiles:Get(player)~=nil and not self.profiles:IsClosing()
end
function Service:_verify(player,key)
 local state=self.states[player]
 if not state or not self:_ready(player) or (key~='VIP' and key~='Neon') then return false end
 local pass=self.config.GamePasses[key]
 if not pass or type(pass.Id)~='number' or pass.Id<=0 then return false end
 local ok,owned=pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId,pass.Id) end)
 if ok and owned==true and self.states[player]==state and self:_ready(player) then
  player:SetAttribute(key=='VIP' and 'HasVIP' or 'HasNeon',true)
  self:_cosmetics(player);return true
 end
 return false
end
function Service:_request(player,key)
 local state=self.states[player]
 if type(key)~='string' or not state or not self:_ready(player) then return end
 local pass=self.config.GamePasses[key]
 if not pass or (key~='VIP' and key~='Neon') then return end
 local now=os.clock();if now-state.last<3 then return end;state.last=now
 if type(pass.Id)~='number' or pass.Id<=0 then return end
 if self:_verify(player,key) then
  self.notice:FireClient(player,{kind='info',text='Этот пропуск уже у вас.'});return
 end
 if self.states[player]~=state or not self:_ready(player) then return end
 local ok,info=pcall(function() return MarketplaceService:GetProductInfo(pass.Id,Enum.InfoType.GamePass) end)
 if self.states[player]~=state or not self:_ready(player) then return end
 if not ok or type(info)~='table' or info.IsForSale~=true then
  self.notice:FireClient(player,{kind='error',text='Покупка сейчас недоступна. Попробуйте позже.'})
  return
 end
 local prompted=pcall(function() MarketplaceService:PromptGamePassPurchase(player,pass.Id) end)
 if not prompted then self.notice:FireClient(player,{kind='error',text='Не удалось открыть покупку Roblox.'}) end
end
function Service:_add(player)
 if self.destroyed or player.Parent~=Players or self.states[player] then return end
 local state={last=-math.huge,connections={},characterConnections={}};self.states[player]=state
 player:SetAttribute('HasVIP',false);player:SetAttribute('HasNeon',false)
 local function connect(signal,fn) table.insert(state.connections,signal:Connect(fn)) end
 local function load()
  if self.states[player]==state and self:_ready(player) then for key in pairs(self.config.GamePasses) do self:_verify(player,key) end end
 end
 connect(player:GetAttributeChangedSignal('DataReady'),function() task.spawn(load) end)
 connect(player:GetAttributeChangedSignal('HasVIP'),function() self:_cosmetics(player) end)
 connect(player:GetAttributeChangedSignal('HasNeon'),function() self:_cosmetics(player) end)
 connect(player:GetAttributeChangedSignal('DisplayTitle'),function() self:_cosmetics(player) end)
 local function watch(container,list,characterOnly)
  table.insert(list,container.ChildAdded:Connect(function() task.defer(function()
   if self.states[player]==state and (not characterOnly or player.Character==container) then self:_cosmetics(player) end
  end) end))
  self:_cosmetics(player)
 end
 local function characterAdded(character)
  if self.destroyed or self.states[player]~=state or player.Character~=character then return end
  for _,connection in ipairs(state.characterConnections) do connection:Disconnect() end
  table.clear(state.characterConnections)
  watch(character,state.characterConnections,true)
  task.spawn(function()
   character:WaitForChild('Head',5)
   if self.states[player]==state and player.Character==character then self:_cosmetics(player) end
  end)
 end
 connect(player.CharacterAdded,characterAdded)
 if player.Character then characterAdded(player.Character) end
 task.spawn(function()
  local backpack=player:WaitForChild('Backpack',10)
  if backpack and self.states[player]==state then watch(backpack,state.connections,false) end
 end)
 task.spawn(load)
end
function Service:Start()
 assert(not self.started and not self.destroyed,'MonetizationService is already running or destroyed');self.started=true
 table.insert(self.connections,self.request.OnServerEvent:Connect(function(player,key) self:_request(player,key) end))
 table.insert(self.connections,MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player,id,purchased)
  if purchased~=true or not self:_ready(player) then return end
  for key,pass in pairs(self.config.GamePasses) do
   if pass.Id>0 and pass.Id==id and self:_verify(player,key) then
    self.notice:FireClient(player,{kind='success',text='Покупка подтверждена Roblox: '..pass.Name});return
   end
  end
 end))
 table.insert(self.connections,Players.PlayerAdded:Connect(function(player) self:_add(player) end))
 table.insert(self.connections,Players.PlayerRemoving:Connect(function(player)
  self:_remove(player)
 end))
 for _,player in ipairs(Players:GetPlayers()) do self:_add(player) end
end
function Service:_remove(player)
 local state=self.states[player];self.states[player]=nil
 if not state then return end
 for _,connection in ipairs(state.connections or {}) do connection:Disconnect() end
 for _,connection in ipairs(state.characterConnections or {}) do connection:Disconnect() end
end
function Service:Destroy()
 if self.destroyed then return end;self.destroyed=true
 for _,c in ipairs(self.connections) do c:Disconnect() end
 table.clear(self.connections)
 for player in pairs(self.states) do self:_remove(player) end
end
return Service
