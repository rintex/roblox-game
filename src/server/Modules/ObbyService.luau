-- Server checkpoints and sequential progress. The client never chooses stage or reward.
local Service={};Service.__index=Service
local function finite(value) return type(value)=='number' and value==value and math.abs(value)~=math.huge end
local function near(root,part,horizontal,vertical)
 local offset=root.Position-part.Position
 return finite(offset.X) and finite(offset.Y) and finite(offset.Z)
  and math.abs(offset.X)<=horizontal and math.abs(offset.Z)<=horizontal and math.abs(offset.Y)<=vertical
end
function Service.new(config,profiles,tycoon,notice,request,world,heroes)
 return setmetatable({config=config,profiles=profiles,tycoon=tycoon,notice=notice,request=request,world=world,heroes=heroes,
  players=game:GetService('Players'),runService=game:GetService('RunService'),runs={},connections={},playerConnections={},lastRequest={},started=false,destroyed=false},Service)
end
function Service:_context(player,allowDetachedWorld)
 if self.destroyed or (not allowDetachedWorld and self.world.Parent~=workspace) or self.profiles:IsClosing() or player.Parent~=self.players or player:GetAttribute('DataReady')~=true then return nil end
 local profile=self.profiles:Get(player);local state=self.tycoon:GetState(player)
 if not profile or not state or state.profile~=profile or state.leaving then return nil end
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass('Humanoid')
 local root=character and character:FindFirstChild('HumanoidRootPart')
 if not humanoid or not (humanoid.Health>0) or not root or not root:IsA('BasePart') then return nil end
 return profile,humanoid,root
end
function Service:_notice(player,text,kind)
 if player.Parent==self.players then self.notice:FireClient(player,{text=text,kind=kind or 'info'}) end
end
function Service:_syncRun(player,run)
 player:SetAttribute('ObbyActive',run~=nil)
 player:SetAttribute('ObbyStage',run and run.stage or 0)
 player:SetAttribute('ObbyCheckpoint',run and run.checkpoint or 0)
 player:SetAttribute('ObbyStartedAt',run and run.serverStartedAt or 0)
end
function Service:_standardMovement(humanoid)
 local settings=self.config.Obby
 humanoid.WalkSpeed=settings.WalkSpeed;humanoid.JumpPower=settings.JumpPower;humanoid.JumpHeight=settings.JumpHeight
end
function Service:_teleport(root,index)
 local point=self.config.Obby.Platforms[index]
 root.CFrame=CFrame.new(point.X,point.Y+4,point.Z)
 root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
end
function Service:_start(player,prompt)
 local profile,humanoid,root=self:_context(player)
 if not profile or not prompt.Enabled or not prompt.Parent or not near(root,prompt.Parent,12,8) then return end
 local now=os.clock()
 if now-(self.lastRequest[player] or -math.huge)<1 then return end
 self.lastRequest[player]=now
 local original=self.runs[player]
 local run={stage=1,checkpoint=1,startedAt=now,serverStartedAt=workspace:GetServerTimeNow(),lastStageAt=now,lastRecoveryAt=-math.huge,
  jumpPower=original and original.jumpPower or humanoid.JumpPower,jumpHeight=original and original.jumpHeight or humanoid.JumpHeight}
 self.runs[player]=run
 player:SetAttribute('ArenaCombatOptIn',false)
 self:_syncRun(player,run);self:_standardMovement(humanoid);self:_teleport(root,1)
 self:_notice(player,'Обби началось! Зелёные крыши — контрольные точки. После падения можно продолжить.','info')
end
function Service:_end(player,teleport)
 local run=self.runs[player];self.runs[player]=nil;self:_syncRun(player,nil)
 local profile,humanoid,root=self:_context(player,true)
 if profile then
  if run then humanoid.JumpPower=run.jumpPower;humanoid.JumpHeight=run.jumpHeight end
  self.heroes:ApplyPerks(player,humanoid,profile)
  if teleport then
   root.CFrame=CFrame.new(-27,5,75);root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
  end
 end
end
function Service:_recover(player)
 local run=self.runs[player];if not run then return end
 local profile,humanoid,root=self:_context(player);if not profile then return end
 local now=os.clock()
 if now-run.lastRecoveryAt<0.8 then return end
 run.lastRecoveryAt=now;run.stage=run.checkpoint;run.lastStageAt=now
 self:_standardMovement(humanoid);self:_teleport(root,run.checkpoint);self:_syncRun(player,run)
end
function Service:_visit(player,index,platform)
 local run=self.runs[player];if not run or index~=run.stage+1 then return end
 local profile,_,root=self:_context(player);if not profile then return end
 local now=os.clock();local settings=self.config.Obby
 if now-run.startedAt>settings.MaximumRunSeconds then
  self:_end(player,true);self:_notice(player,'Забег закончился. Начни заново на стартовой площадке.');return
 end
 if not platform:IsDescendantOf(self.world) or not near(root,platform,5.5,5)
  or now-run.lastStageAt<settings.StageMinimumSeconds then return end
 if index==#settings.Platforms and now-run.startedAt<settings.MinimumRunSeconds then
  if not run.finishScheduled then
   run.finishScheduled=true
   local remaining=settings.MinimumRunSeconds-(now-run.startedAt)
   self:_notice(player,'Ты на финише! Подтверждаем результат — останься на золотой крыше.')
   task.delay(remaining+0.05,function()
    if self.runs[player]==run and run.stage==index-1 then self:_visit(player,index,platform) end
   end)
  end
  return
 end
 run.stage=index;run.lastStageAt=now
 for _,checkpoint in ipairs(settings.Checkpoints) do
  if index==checkpoint then run.checkpoint=index;self:_notice(player,'Контрольная точка '..index..' сохранена!','success');break end
 end
 self:_syncRun(player,run)
 if index~=#settings.Platforms then return end
 local milliseconds=math.floor((now-run.startedAt)*1000+0.5)
 local wallTime=os.time()
 if wallTime>=(profile.ObbyReadyAt or 0) then
  local coins=math.min(settings.RewardCoins,self.config.MaxCoins-profile.Coins)
  if coins>0 then
   profile.Coins+=coins;profile.XP=math.min(self.config.MaxXP,profile.XP+settings.RewardXP)
   profile.ObbyReadyAt=wallTime+settings.RewardCooldown
   self:_notice(player,'Финиш! +'..coins..' монет и +'..settings.RewardXP..' XP.','success')
  else self:_notice(player,'Финиш! Кошелёк заполнен; награда не списана.','info') end
 else
  self:_notice(player,'Финиш! Следующая денежная награда через '..math.ceil(profile.ObbyReadyAt-wallTime)..' сек.','info')
 end
 profile.ObbyWins=math.min(self.config.MaxCoins,(profile.ObbyWins or 0)+1)
 if (profile.ObbyBestMilliseconds or 0)==0 or milliseconds<profile.ObbyBestMilliseconds then profile.ObbyBestMilliseconds=milliseconds end
 -- The reward is already committed to the server profile. A HUD sync failure
 -- must never leave the run active or allow a second finish to grant it again.
 local synced=pcall(function() self.tycoon:SyncPlayer(player) end)
 self:_end(player,false)
 if not synced then warn('Obby: не удалось обновить интерфейс после финиша') end
end
function Service:_step(now)
 if self.destroyed then return end
 if self.profiles:IsClosing() or self.world.Parent~=workspace then self:Destroy();return end
 for player,run in pairs(self.runs) do
  if now-run.startedAt>self.config.Obby.MaximumRunSeconds then
   self:_end(player,true);self:_notice(player,'Время забега вышло. Начни заново на стартовой площадке.')
  end
 end
end
function Service:_playerFromHit(hit)
 if not hit then return nil end
 local node=hit.Parent
 while node and node~=workspace do
  if node:IsA('Model') then
   local player=self.players:GetPlayerFromCharacter(node);if player then return player end
  end
  node=node.Parent
 end
 return nil
end
function Service:_watch(player)
 if self.playerConnections[player] then return end
 self:_syncRun(player,nil)
 self.playerConnections[player]={
  player.CharacterAdded:Connect(function(character)
   local run=self.runs[player];if not run then return end
   task.spawn(function()
    character:WaitForChild('HumanoidRootPart',10);character:WaitForChild('Humanoid',10)
    if player.Character==character and self.runs[player]==run then
     run.lastRecoveryAt=-math.huge;self:_recover(player)
    end
   end)
  end),
  player:GetAttributeChangedSignal('DataReady'):Connect(function()
   if player:GetAttribute('DataReady')~=true and self.runs[player] then self:_end(player,false) end
  end),
 }
end
function Service:Start()
 assert(not self.started and not self.destroyed,'ObbyService is already running or destroyed');self.started=true
 local platforms=self.world:FindFirstChild('Platforms')
 for index=2,#self.config.Obby.Platforms do
  local platform=platforms:FindFirstChild('Stage'..index)
  assert(platform and platform:IsA('BasePart'),'Missing obby stage '..index)
  table.insert(self.connections,platform.Touched:Connect(function(hit)
   local player=self:_playerFromHit(hit);if player then self:_visit(player,index,platform) end
  end))
 end
 local start=self.world:FindFirstChild('StartStand');local prompt=start:FindFirstChild('StartObbyPrompt')
 table.insert(self.connections,prompt.Triggered:Connect(function(player) self:_start(player,prompt) end))
 local recovery=self.world:FindFirstChild('RecoveryField')
 table.insert(self.connections,recovery.Touched:Connect(function(hit)
  local player=self:_playerFromHit(hit);if player then self:_recover(player) end
 end))
 table.insert(self.connections,self.request.OnServerEvent:Connect(function(player,command)
  if type(command)~='string' or (command~='Checkpoint' and command~='Exit') or not self.runs[player] then return end
  local now=os.clock();if now-(self.lastRequest[player] or -math.huge)<1 then return end
  self.lastRequest[player]=now
  if command=='Checkpoint' then self:_recover(player) else self:_end(player,true) end
 end))
 table.insert(self.connections,self.players.PlayerAdded:Connect(function(player) self:_watch(player) end))
 table.insert(self.connections,self.players.PlayerRemoving:Connect(function(player)
  self.runs[player]=nil;self.lastRequest[player]=nil
  for _,connection in ipairs(self.playerConnections[player] or {}) do connection:Disconnect() end
  self.playerConnections[player]=nil
 end))
 local accumulated=0
 table.insert(self.connections,self.runService.Heartbeat:Connect(function(seconds)
  accumulated+=seconds
  if accumulated<1 then return end
  accumulated=0;self:_step(os.clock())
 end))
 for _,player in ipairs(self.players:GetPlayers()) do self:_watch(player) end
end
function Service:Destroy()
 if self.destroyed then return end
 for player in pairs(self.runs) do self:_end(player,false) end
 self.destroyed=true
 for _,connection in ipairs(self.connections) do connection:Disconnect() end
 for _,connections in pairs(self.playerConnections) do for _,connection in ipairs(connections) do connection:Disconnect() end end
 table.clear(self.connections);table.clear(self.playerConnections);table.clear(self.lastRequest);self.started=false
end
return Service
