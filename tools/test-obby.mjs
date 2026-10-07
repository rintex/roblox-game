// Runs the actual server service with deterministic time, touches and player lifecycles.
import {readFile} from 'node:fs/promises';
import {LuauState} from 'luau-web';
const [config,service]=await Promise.all([
 readFile('src/shared/TycoonConfig.luau','utf8'),readFile('src/server/Modules/ObbyService.luau','utf8')
]);
const fixture=String.raw`
local Config=(function() CONFIG_SOURCE end)()
local clock=100
local os={clock=function() return clock end,time=function() return math.floor(clock)+100000 end}
local queued={}
local task={spawn=function(fn) fn() end,delay=function(seconds,fn) table.insert(queued,{seconds,fn}) end}
local function signal()
 local callbacks={}
 return {Connect=function(_,fn)
  local c={active=true};function c:Disconnect() self.active=false end
  table.insert(callbacks,{c,fn});return c
 end,Fire=function(_,...)
  for _,entry in ipairs(callbacks) do if entry[1].active then entry[2](...) end end
 end}
end
local Vector3={}
local vectorMeta={__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
Vector3.zero=Vector3.new(0,0,0)
local CFrame={new=function(x,y,z) return {Position=Vector3.new(x,y,z)} end}
local Players={PlayerAdded=signal(),PlayerRemoving=signal(),list={}}
function Players:GetPlayers() return self.list end
function Players:GetPlayerFromCharacter(char)
 for _,p in ipairs(self.list) do if p.Character==char then return p end end
end
local workspace={GetServerTimeNow=function() return clock+100000 end}
local game={GetService=function(_,name) assert(name=='Players');return Players end}
local function object(class,name,parent)
 local o={ClassName=class,Name=name,Parent=parent,children={}}
 function o:IsA(target) return class==target or (class=='Part' and target=='BasePart') end
 function o:FindFirstChild(target) return self.children[target] end
 function o:WaitForChild(target) return self.children[target] end
 function o:FindFirstChildOfClass(target) for _,child in pairs(self.children) do if child:IsA(target) then return child end end end
 if parent and parent.children then parent.children[name]=o end
 return o
end
local function rootPart(parent,name,pos)
 local part=object('Part',name,parent);part.Position=pos
 local stored={CFrame={Position=pos}}
 return setmetatable(part,{__index=function(_,k) return stored[k] end,__newindex=function(self,k,v)
  if k=='CFrame' then stored[k]=v;self.Position=v.Position else rawset(self,k,v) end
 end})
end
local world=object('Folder','RooftopObby',workspace)
local platforms=object('Folder','Platforms',world)
for index,point in ipairs(Config.Obby.Platforms) do
 local part=rootPart(platforms,'Stage'..index,Vector3.new(point.X,point.Y,point.Z));part.Touched=signal()
end
local start=rootPart(world,'StartStand',Vector3.new(-27,.6,78))
local prompt=object('ProximityPrompt','StartObbyPrompt',start);prompt.Enabled=true;prompt.Triggered=signal()
local recovery=rootPart(world,'RecoveryField',Vector3.new(0,.4,112));recovery.Touched=signal()
local p=object('Player','Tester',Players);p.UserId=1;p.attrs={DataReady=true};p.attrSignals={};p.CharacterAdded=signal()
function p:SetAttribute(key,value)
 local changed=self.attrs[key]~=value;self.attrs[key]=value
 if changed and self.attrSignals[key] then self.attrSignals[key]:Fire() end
end
function p:GetAttribute(key) return self.attrs[key] end
function p:GetAttributeChangedSignal(key) self.attrSignals[key]=self.attrSignals[key] or signal();return self.attrSignals[key] end
local function makeCharacter()
 local char=object('Model','Character',workspace)
 local root=rootPart(char,'HumanoidRootPart',Vector3.new(-27,4,78))
 local humanoid=object('Humanoid','Humanoid',char);humanoid.Health=100;humanoid.WalkSpeed=26;humanoid.JumpPower=55;humanoid.JumpHeight=8
 p.Character=char;return root,humanoid
end
local root,humanoid=makeCharacter();Players.list={p}
local data={Coins=75,XP=0,ObbyReadyAt=0,ObbyWins=0,ObbyBestMilliseconds=0}
local profiles={records={[p]=data},closing=false}
function profiles:Get(player) return self.records[player] end
function profiles:IsClosing() return self.closing end
local tycoon={states={[p]={profile=data}},syncs=0}
function tycoon:GetState(player) return self.states[player] end
function tycoon:SyncPlayer() self.syncs+=1 end
local notices={}
local notice={FireClient=function(_,player,payload) assert(player==p);table.insert(notices,payload) end}
local request={OnServerEvent=signal()}
local heroes={ApplyPerks=function(_,player,h) h.WalkSpeed=26 end}
local Service=(function() SERVICE_SOURCE end)()
local s=Service.new(Config,profiles,tycoon,notice,request,world,heroes);s:Start()
local checks=0
local function check(name,fn) fn();checks+=1 end
local function begin()
 clock+=2;root.Position=Vector3.new(-27,4,78);prompt.Triggered:Fire(p)
 assert(s.runs[p] and p:GetAttribute('ObbyActive') and s.runs[p].stage==1)
end
local function visit(index,seconds)
 clock+=seconds or 1
 local part=platforms:FindFirstChild('Stage'..index)
 root.Position=Vector3.new(part.Position.X,part.Position.Y+3,part.Position.Z)
 part.Touched:Fire(root)
end
check('start validates profile identity, life, distance and shutdown',function()
 root.Position=Vector3.new(200,4,78);prompt.Triggered:Fire(p);assert(not s.runs[p])
 root.Position=Vector3.new(0/0,4,78);prompt.Triggered:Fire(p);assert(not s.runs[p])
 root.Position=Vector3.new(-27,4,78);humanoid.Health=0;prompt.Triggered:Fire(p);assert(not s.runs[p]);humanoid.Health=100
 p:SetAttribute('DataReady',false);prompt.Triggered:Fire(p);assert(not s.runs[p]);p:SetAttribute('DataReady',true)
 profiles.closing=true;prompt.Triggered:Fire(p);assert(not s.runs[p]);profiles.closing=false
 profiles.records[p]={};prompt.Triggered:Fire(p);assert(not s.runs[p]);profiles.records[p]=data
end)
check('course begins with standard movement and explicit PvP exit',function()
 p:SetAttribute('ArenaCombatOptIn',true);begin()
 assert(humanoid.WalkSpeed==16 and humanoid.JumpPower==50 and not p:GetAttribute('ArenaCombatOptIn'))
 assert(root.Position.Y==8 and p:GetAttribute('ObbyStartedAt')==clock+100000)
end)
check('forged skips, remote stages, distant touches and speed runs do not advance',function()
 visit(16);assert(s.runs[p].stage==1 and data.Coins==75)
 request.OnServerEvent:Fire(p,'SetStage',16);request.OnServerEvent:Fire(p,'Reward',99999);assert(s.runs[p].stage==1)
 root.Position=Vector3.new(300,300,300);platforms.children.Stage2.Touched:Fire(root);assert(s.runs[p].stage==1)
 visit(2,0.1);assert(s.runs[p].stage==2)
 visit(3,0.1);assert(s.runs[p].stage==2)
 visit(3,1);visit(4,1);assert(s.runs[p].checkpoint==4)
end)
check('fall returns to last checkpoint and requires repeating intervening stages',function()
 visit(5,1);clock+=1;recovery.Touched:Fire(root)
 assert(s.runs[p].stage==4 and root.Position.Y==Config.Obby.Platforms[4].Y+4)
 visit(6,1);assert(s.runs[p].stage==4)
 visit(5,1)
end)
check('death respawn resumes the same run and checkpoint',function()
 local oldStarted=s.runs[p].startedAt
 root,humanoid=makeCharacter();clock+=1;p.CharacterAdded:Fire(p.Character)
 assert(s.runs[p].stage==4 and s.runs[p].startedAt==oldStarted and humanoid.WalkSpeed==16)
end)
check('valid sequential finish awards exact reward once, saves time and restores movement',function()
 for index=5,16 do visit(index,1) end
 assert(not s.runs[p] and not p:GetAttribute('ObbyActive'))
 assert(data.Coins==375 and data.XP==75 and data.ObbyWins==1 and data.ObbyBestMilliseconds>=15000)
 assert(data.ObbyReadyAt==os.time()+300 and humanoid.WalkSpeed==26 and humanoid.JumpPower==55)
 visit(16,1);assert(data.Coins==375 and data.ObbyWins==1)
end)
check('persisted reward cooldown prevents farming on a second complete run',function()
 begin();for index=2,16 do visit(index,1) end
 assert(data.Coins==375 and data.XP==75 and data.ObbyWins==2)
end)
check('minimum total time rejects a finish even if stages were visited quickly',function()
 begin();for index=2,15 do visit(index,0.5) end
 visit(16,0.5);assert(s.runs[p] and s.runs[p].stage==15)
 clock+=10;queued[#queued][2]();assert(not s.runs[p] and data.ObbyWins==3)
end)
check('full wallet retains eligibility; a later valid run can receive the reward',function()
 data.ObbyReadyAt=0;data.Coins=Config.MaxCoins;begin();for index=2,16 do visit(index,1) end
 assert(data.Coins==Config.MaxCoins and data.ObbyReadyAt==0)
 data.Coins=0;begin();for index=2,16 do visit(index,1) end;assert(data.Coins==300 and data.ObbyReadyAt>os.time())
end)
check('exit, lock loss, timeout and leaving stop the run without rewards',function()
 begin();clock+=2;request.OnServerEvent:Fire(p,'Exit');assert(not s.runs[p] and humanoid.WalkSpeed==26)
 begin();p:SetAttribute('DataReady',false);assert(not s.runs[p]);p:SetAttribute('DataReady',true)
 begin();clock+=Config.Obby.MaximumRunSeconds+1;visit(2);assert(not s.runs[p])
 begin();Players.PlayerRemoving:Fire(p);assert(not s.runs[p] and not s.playerConnections[p])
 s:Destroy()
end)
return checks
`;
const code=fixture.replace('CONFIG_SOURCE',config).replace('SERVICE_SOURCE',service);
const state=await LuauState.createAsync();
try{const result=await state.loadstring(code,'Rooftop obby server tests',true)();console.log(`Obby checks passed: ${result[0]} cases for sequential progress, checkpoints, death, profile safety, cooldowns, records and rewards.`);}finally{state.destroy();}
