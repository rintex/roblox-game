-- Game Pass ownership is checked by Roblox; clients never grant entitlements.
local Players=game:GetService('Players')
local MarketplaceService=game:GetService('MarketplaceService')
local Service={};Service.__index=Service
function Service.new(config,profiles,notice,request)
 return setmetatable({config=config,profiles=profiles,notice=notice,request=request,connections={},states={}},Service)
end
local function create(parent,class,name)
 local object=parent:FindFirstChild(name)
 if object then if object:IsA(class) then return object else return nil end end
 object=Instance.new(class);object.Name=name;object.Parent=parent;return object
end
function Service:_cosmetics(player)
 local character=player.Character
 if character then
  local head=character:FindFirstChild('Head')
  if head then
   local title=head:FindFirstChild('HeroClubTitle')
   if player:GetAttribute('HasVIP')==true then
    title=create(head,'BillboardGui','HeroClubTitle')
    if title then
     title.Size=UDim2.fromOffset(180,32);title.StudsOffset=Vector3.new(0,2.5,0);title.MaxDistance=75
     local label=create(title,'TextLabel','Title')
     if label then
      label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1;label.Text='КЛУБ ГЕРОЕВ'
      label.TextColor3=Color3.fromRGB(255,218,89);label.Font=Enum.Font.GothamBold;label.TextScaled=true
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
 return player.Parent==Players and player:GetAttribute('DataReady')==true
  and self.profiles:Get(player)~=nil and not self.profiles:IsClosing()
end
function Service:_verify(player,key)
 local pass=self.config.GamePasses[key]
 if not pass or type(pass.Id)~='number' or pass.Id<=0 then return false end
 local ok,owned=pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId,pass.Id) end)
 if ok and owned==true and self:_ready(player) then
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
 local ok,info=pcall(function() return MarketplaceService:GetProductInfo(pass.Id,Enum.InfoType.GamePass) end)
 if not ok or type(info)~='table' or info.IsForSale~=true or not self:_ready(player) then
  if player.Parent==Players then self.notice:FireClient(player,{kind='error',text='Покупка сейчас недоступна. Попробуйте позже.'}) end
  return
 end
 local prompted=pcall(function() MarketplaceService:PromptGamePassPurchase(player,pass.Id) end)
 if not prompted then self.notice:FireClient(player,{kind='error',text='Не удалось открыть покупку Roblox.'}) end
end
function Service:_add(player)
 if self.states[player] then return end
 local state={last=-math.huge,connections={}};self.states[player]=state
 player:SetAttribute('HasVIP',false);player:SetAttribute('HasNeon',false)
 local function connect(signal,fn) table.insert(state.connections,signal:Connect(fn)) end
 local function load()
  if self:_ready(player) then for key in pairs(self.config.GamePasses) do self:_verify(player,key) end end
 end
 connect(player:GetAttributeChangedSignal('DataReady'),function() task.spawn(load) end)
 connect(player:GetAttributeChangedSignal('HasVIP'),function() self:_cosmetics(player) end)
 connect(player:GetAttributeChangedSignal('HasNeon'),function() self:_cosmetics(player) end)
 local function watch(container)
  connect(container.ChildAdded,function() task.defer(function() self:_cosmetics(player) end) end)
  self:_cosmetics(player)
 end
 connect(player.CharacterAdded,function(character)
  watch(character);task.spawn(function() character:WaitForChild('Head',5);if player.Character==character then self:_cosmetics(player) end end)
 end)
 if player.Character then watch(player.Character) end
 task.spawn(function()
  local backpack=player:WaitForChild('Backpack',10)
  if backpack and self.states[player]==state then watch(backpack) end
 end)
 task.spawn(load)
end
function Service:Start()
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
  local state=self.states[player];if state then for _,c in ipairs(state.connections) do c:Disconnect() end end
  self.states[player]=nil
 end))
 for _,player in ipairs(Players:GetPlayers()) do self:_add(player) end
end
function Service:Destroy()
 for _,c in ipairs(self.connections) do c:Disconnect() end
 for _,state in pairs(self.states) do for _,c in ipairs(state.connections) do c:Disconnect() end end
 table.clear(self.states)
end
return Service
