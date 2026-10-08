// Execute the shipped client scripts against signal/tween/lifetime mocks.
// Checks contracts and allocation bounds; visual appearance still needs Studio.
import {readFile} from 'node:fs/promises';
import {LuauState} from 'luau-web';
const [hero,world,config]=await Promise.all([
  'src/client/HeroEffects.client.luau','src/client/DropperEffects.client.luau','src/shared/TycoonConfig.luau',
].map(file=>readFile(file,'utf8')));
const fixture=String.raw`
local clock, sounds, particles, requests = 100, 0, 0, 0
local os = {clock=function() return clock end}
local scheduled={}
local task={}
local function resumeTask(thread)
 local ok,seconds=coroutine.resume(thread)
 assert(ok, tostring(seconds))
 if coroutine.status(thread)~='dead' then table.insert(scheduled,{at=clock+(seconds or 0),thread=thread}) end
end
function task.spawn(fn) resumeTask(coroutine.create(fn)) end
function task.defer(fn) table.insert(scheduled,{at=clock,fn=fn}) end
function task.delay(seconds,fn) table.insert(scheduled,{at=clock+seconds,fn=fn}) end
function task.wait(seconds) return coroutine.yield(seconds or 0.03) end
local function advance(seconds)
 clock+=seconds
 local ready={}
 for index=#scheduled,1,-1 do
  if scheduled[index].at<=clock then table.insert(ready,table.remove(scheduled,index)) end
 end
 for _,entry in ipairs(ready) do if entry.fn then entry.fn() else resumeTask(entry.thread) end end
end
local function signal()
 local handlers={}
 return {
  Connect=function(_,fn)
   local entry={fn=fn,connected=true};table.insert(handlers,entry)
   return {Disconnect=function() entry.connected=false end}
  end,
  Fire=function(_,...) for _,entry in ipairs(table.clone(handlers)) do if entry.connected then entry.fn(...) end end end,
 }
end
local vector={}
local vm={
 __index=function(self,key)
  if key=='Magnitude' then return math.sqrt(self.X*self.X+self.Y*self.Y+self.Z*self.Z) end
  return vector[key]
 end,
 __add=function(a,b) return vector.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end,
 __sub=function(a,b) return vector.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end,
 __mul=function(a,b) return vector.new(a.X*b,a.Y*b,a.Z*b) end,
 __div=function(a,b) return vector.new(a.X/b,a.Y/b,a.Z/b) end,
}
function vector.new(x,y,z) return setmetatable({X=x,Y=y,Z=z,__type='Vector3'},vm) end
local Vector3={new=vector.new}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local cf={}
local cm={__index=cf,
 __mul=function(a,b) return setmetatable({Position=a.Position+b.Position,angle=(a.angle or 0)+(b.angle or 0)},cm) end,
 __add=function(a,b) return cf.new(a.Position+b) end,
}
-- Explicit reassignment makes the recursive metatable available to __mul.
cm.__mul=function(a,b) return setmetatable({Position=a.Position+b.Position,angle=(a.angle or 0)+(b.angle or 0)},cm) end
function cf.new(a,b,c)
 local position=if type(a)=='table' then a else Vector3.new(a or 0,b or 0,c or 0)
 return setmetatable({Position=position,angle=0},cm)
end
function cf.Angles(x,y,z) local result=cf.new();result.angle=x+y+z;return result end
function cf.lookAt(position) return cf.new(position) end
local CFrame=cf
local Color3={new=function(r,g,b) return {R=r,G=g,B=b,__type='Color3'} end}
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
local function tuple(...) return {...} end
local UDim2={new=tuple,fromOffset=tuple,fromScale=tuple}
local NumberRange={new=tuple};local NumberSequence={new=tuple};local NumberSequenceKeypoint={new=tuple}
local ColorSequence={new=tuple};local TweenInfo={new=tuple}
local Enum=setmetatable({}, {__index=function(self,key)
 local category=setmetatable({}, {__index=function(category,value) rawset(category,value,value);return value end})
 rawset(self,key,category);return category
end})
local methods={}
local im={
 __index=function(self,key)
  if key=='Position' and self.values.CFrame then return self.values.CFrame.Position end
  return methods[key] or self.values[key]
 end,
 __newindex=function(self,key,value)
  if key~='Parent' then self.values[key]=value;return end
  local previous=self.values.Parent
  if previous==value then return end
  if previous then
   local at=table.find(previous.children,self);if at then table.remove(previous.children,at) end
   local node=previous;while node do node.DescendantRemoving:Fire(self);node=node.Parent end
  end
  self.values.Parent=value
  if previous then previous.ChildRemoved:Fire(self) end
  if value then
   table.insert(value.children,self);value.ChildAdded:Fire(self)
   local node=value;while node do node.DescendantAdded:Fire(self);node=node.Parent end
  end
 end,
}
local function object(class,name)
 local result=setmetatable({values={ClassName=class,Name=name or class},children={},attrs={},attributeSignals={},propertySignals={},__type='Instance'},im)
 for _,key in ipairs({'ChildAdded','ChildRemoved','DescendantAdded','DescendantRemoving','Destroying'}) do result[key]=signal() end
 if class=='BindableEvent' then result.Event=signal() end
 if class=='RemoteEvent' then result.OnClientEvent=signal() end
 return result
end
function methods:IsA(class) return self.ClassName==class or class=='BasePart' and self.ClassName=='Part' end
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants()
 local result={}
 for _,child in ipairs(self.children) do table.insert(result,child);for _,nested in ipairs(child:GetDescendants()) do table.insert(result,nested) end end
 return result
end
function methods:FindFirstChild(name) for _,child in ipairs(self.children) do if child.Name==name then return child end end end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:FindFirstChildOfClass(class) for _,child in ipairs(self.children) do if child:IsA(class) then return child end end end
function methods:IsDescendantOf(ancestor) local node=self.Parent;while node do if node==ancestor then return true end;node=node.Parent end;return false end
function methods:GetAttribute(name) return self.attrs[name] end
function methods:GetAttributeChangedSignal(name) if not self.attributeSignals[name] then self.attributeSignals[name]=signal() end;return self.attributeSignals[name] end
function methods:SetAttribute(name,value) self.attrs[name]=value;self:GetAttributeChangedSignal(name):Fire() end
function methods:GetPropertyChangedSignal(name) if not self.propertySignals[name] then self.propertySignals[name]=signal() end;return self.propertySignals[name] end
function methods:Destroy()
 if self.destroyed then return end;self.destroyed=true;self.Destroying:Fire()
 for _,child in ipairs(self:GetChildren()) do child:Destroy() end
 self.Parent=nil
end
function methods:Fire(...) self.Event:Fire(...) end
function methods:Play() sounds+=1 end
function methods:Emit(amount) particles+=amount end
function methods:FireServer() requests+=1 end
local Instance={new=function(class) return object(class) end}
local function typeof(value) return type(value)=='table' and value.__type or type(value) end
local player=object('Player','Tester');player.UserId=24
player.CharacterRemoving=signal()
local character=object('Model','Character');player.Character=character
local root=object('Part','HumanoidRootPart');root.CFrame=CFrame.new(0,3,0);root.Parent=character
local humanoid=object('Humanoid','Humanoid');humanoid.Health=100;humanoid.Parent=character
local shoulder=object('Motor6D','RightShoulder');shoulder.C0=CFrame.new(1,1,0);shoulder.Parent=character
local originalJoint=shoulder.C0
local playerGui=object('PlayerGui','PlayerGui');playerGui.Parent=player
local workspace=object('Workspace','Workspace');character.Parent=workspace
local storage=object('ReplicatedStorage','ReplicatedStorage')
local remotes=object('Folder','TycoonRemotes');remotes.Parent=storage
local effect=object('RemoteEvent','Effect');effect.Parent=remotes
local notice=object('RemoteEvent','Notice');notice.Parent=remotes
local loot=object('RemoteEvent','LootResult');loot.Parent=remotes
local shared=object('Folder','Shared');shared.Parent=storage
local configObject=object('ModuleScript','TycoonConfig');configObject.Parent=shared
local function loadConfig() CONFIG_SOURCE end
local config=loadConfig()
local function require(module) assert(module==configObject);return config end
local TweenService={Create=function(_,item,info,goals)
 local tween={Completed=signal(),goals=goals}
 function tween:Play() for key,value in pairs(goals) do item[key]=value end end
 function tween:Cancel() self.Completed:Fire('Cancelled') end
 return tween
end}
local services={Players={LocalPlayer=player},Workspace=workspace,ReplicatedStorage=storage,TweenService=TweenService}
local game={GetService=function(_,name) assert(services[name],name);return services[name] end}
local script=object('LocalScript','HeroEffects')
local heroScript=script
local function runHero() HERO_SOURCE end
runHero()
local heroFolder=workspace:FindFirstChild('ClientHeroEffects')
local function count(folder) return #folder:GetChildren()-1 end
local function fire(kind,extra)
 local payload={kind=kind,from=Vector3.new(0,3,0),to=Vector3.new(12,3,0),color={75,200,240},actorUserId=24}
 for key,value in pairs(extra or {}) do payload[key]=value end
 effect.OnClientEvent:Fire(payload)
end
for _,payload in ipairs({false,{}, {kind='beam',from=Vector3.new(0/0,0,0),to=Vector3.new()},
 {kind='beam',from=Vector3.new(0,0,0),to=Vector3.new(1001,0,0)},
 {kind='beam',from=Vector3.new(900,0,0),to=Vector3.new(920,0,0)}}) do effect.OnClientEvent:Fire(payload) end
assert(count(heroFolder)==0,'Malformed and distant effect requests are ignored')
fire('web');assert(heroFolder:FindFirstChild('SkillBeamAnchor') and heroFolder:FindFirstChild('WebContact'),'Web has its own beam and contact style')
assert(shoulder.C0.angle~=0,'Accepted local attacks have a procedural shoulder pose')
advance(2);advance(0.5)
assert(count(heroFolder)==0 and shoulder.C0==originalJoint,'Attack effects and joint pose expire')
local target=object('Model','Enemy');target.Parent=workspace
fire('hit',{amount=28,target=target});assert(heroFolder:FindFirstChild('DamageNumber') and heroFolder:FindFirstChild('HitHighlight'))
assert(heroFolder:FindFirstChild('DamageNumber'):FindFirstChild('Damage'):FindFirstChildOfClass('TextLabel').Text=='−28')
advance(2)
fire('hit',{amount=28,target=target,actorUserId=99});assert(not heroFolder:FindFirstChild('DamageNumber'),'Other players do not spam local damage numbers')
advance(2)
fire('boss_warning',{radius=999,duration=999})
local warning=heroFolder:FindFirstChild('BossAreaWarning');assert(warning and warning.Size.Y==64 and warning.Position.Y==0.35,'Boss warning is bounded and on the floor')
advance(4);assert(count(heroFolder)==0,'Boss warning expires even with malformed duration')
fire('boss_warning',{radius=3.5,duration=1.15,style='rush'})
assert(heroFolder:FindFirstChild('BossRushWarning').Size.Z==19,'Rush warning includes the server attack endcaps')
advance(2)
fire('hurt',{amount=12,victimUserId=24})
assert(playerGui:FindFirstChild('CombatFeedbackHUD'):FindFirstChild('DamageFlash'),'Local damage has a nonblocking flash')
advance(2)
local before=particles
player:SetAttribute('EffectsQuality','Low')
fire('lightning');assert(particles==before,'Low quality disables decorative particle bursts')
for index=1,100 do fire('beam') end
assert(count(heroFolder)<=20,'Low-quality VFX budget is bounded')
player:SetAttribute('EffectsQuality','Off');assert(count(heroFolder)==0,'Changing quality clears old transient effects')
player:SetAttribute('SoundEnabled',false)
before=sounds;fire('victory',{boss=true});assert(count(heroFolder)==0 and sounds==before,'Off and sound disabled allocate nothing')
fire('boss_warning',{radius=10,duration=1});assert(count(heroFolder)==1,'Essential boss danger remains readable with effects Off')
advance(2);assert(count(heroFolder)==0,'Essential warning is short lived')
player:SetAttribute('EffectsQuality','High');player:SetAttribute('SoundEnabled',true)
fire('repulsor');assert(count(heroFolder)>0)
player.CharacterRemoving:Fire(character);assert(count(heroFolder)==0 and shoulder.C0==originalJoint,'Respawn restores joints and clears feedback')
heroScript:Destroy();fire('beam');assert(not workspace:FindFirstChild('ClientHeroEffects'),'Destroyed renderer disconnects remote callbacks')

-- Exercise the production world renderer, including rebuild and late replication.
player:SetAttribute('DataReady',true);player:SetAttribute('Coins',500);player:SetAttribute('Floor',1);player:SetAttribute('DropperTier',0);player:SetAttribute('Bank',10)
local plotFolder=object('Folder','TycoonPlots');plotFolder.Parent=workspace
local plot=object('Model','Plot1');plot:SetAttribute('OwnerUserId',24);plot:SetAttribute('OwnerReady',true);plot:SetAttribute('Floor',1);plot.Parent=plotFolder
local base=object('Part','Base');base.CFrame=CFrame.new(0,0.15,0);base.Parent=plot
local structure=object('Folder','Structure');structure.Parent=plot
local machine=object('Model','Dropper');machine.Parent=structure
local start=object('Part','DropletStart');start.CFrame=CFrame.new(1,5,0);start.Color=Color3.fromRGB(98,221,192);start.Parent=machine
local ending=object('Part','DropletEnd');ending.CFrame=CFrame.new(1,1,0);ending.Parent=machine
-- Missing purchase pads while replication catches up must not throw.
script=object('LocalScript','DropperEffects');local worldScript=script
local function runWorld() WORLD_SOURCE end
runWorld()
local worldFolder=workspace:FindFirstChild('ClientTycoonEffects')
assert(worldFolder:FindFirstChild('VisualDroplet'),'A nearby generator shows local droplets')
for _,name in ipairs({'UpgradePad','DropperUpgradePad','Collector'}) do
 local pad=object('Part',name);pad.CFrame=CFrame.new(0,0.5,0);pad.Parent=plot
end
player:SetAttribute('Coins',501)
local highlighted=0;for _,item in ipairs(worldFolder:GetChildren()) do if item.Name=='AvailablePurchase' then highlighted+=1 end end
assert(highlighted==3,'Only available owned purchases and collection get highlights')
plot:SetAttribute('Floor',2);assert(worldFolder:FindFirstChild('ConstructionRing') and worldFolder:FindFirstChild('ConstructionGlow'),'New floor has a construction effect')
advance(2)
local crates=object('Folder','Airdrops');crates.Parent=workspace
advance(1)
local crate=object('Model','FreeSupplyCrate');crate.Parent=crates
local body=object('Part','Crate');body.CFrame=CFrame.new(0,88,0);body.Parent=crate
local prompt=object('ProximityPrompt','LootPrompt');prompt.Enabled=false;prompt.Parent=body
assert(worldFolder:FindFirstChild('CrateArrival') and worldFolder:FindFirstChild('CrateLandingMarker'),'A falling crate marks the landing spot')
body.CFrame=CFrame.new(0,2.7,0);prompt.Enabled=true;prompt:GetPropertyChangedSignal('Enabled'):Fire()
assert(worldFolder:FindFirstChild('CrateLanding'),'Landing gets a short ground pulse')
loot.OnClientEvent:Fire({weaponId='solar_lance'});assert(worldFolder:FindFirstChild('LootReward'),'Server loot outcome has a rarity-colored reward effect')
player:SetAttribute('EffectsQuality','Off');player:SetAttribute('SoundEnabled',false)
assert(count(worldFolder)==0,'Off immediately clears drops, highlights and sounds')
before=sounds;notice.OnClientEvent:Fire({kind='success'});advance(3)
assert(count(worldFolder)==0 and sounds==before,'Off loop creates no new visual objects')
player:SetAttribute('EffectsQuality','Low')
advance(2);assert(worldFolder:FindFirstChild('VisualDroplet'))
plotFolder:Destroy();advance(2);advance(2)
assert(not worldFolder:FindFirstChild('VisualDroplet'),'Rebuilt or removed generators leave no cached effects')
worldScript:Destroy();advance(3)
assert(not workspace:FindFirstChild('ClientTycoonEffects'),'World renderer stops and removes all effects')
assert(requests==0,'Cosmetic renderers never request damage, currency or rewards')
return 'Effects checks passed: production VFX, damage labels, boss warnings, lifetime caps, quality/audio settings, respawn, construction, generator rebuild, crates and cleanup.'
`;
const state=await LuauState.createAsync();
try {
  const source=fixture.replace('CONFIG_SOURCE',config).replace('HERO_SOURCE',hero).replace('WORLD_SOURCE',world);
  console.log((await state.loadstring(source,'production effects integration',true)())[0]);
} finally {state.destroy();}
