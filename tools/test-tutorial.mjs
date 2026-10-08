// Production tutorial + real UITheme: target selection, status and lifecycle.
// These VM checks do not replace Studio screen/character testing.
import {readFile} from 'node:fs/promises';
import {LuauState} from 'luau-web';
const [tutorial,theme,config]=await Promise.all([
  'src/client/TutorialHUD.client.luau','src/shared/UITheme.luau','src/shared/TycoonConfig.luau',
].map(file=>readFile(file,'utf8')));
const fixture=String.raw`
local requests=0
local function signal()
 local entries={}
 return {
  Connect=function(_,callback)
   local entry={connected=true,callback=callback};table.insert(entries,entry)
   return {Disconnect=function() entry.connected=false end}
  end,
  Fire=function(_,...) for _,entry in ipairs(table.clone(entries)) do if entry.connected then entry.callback(...) end end end,
  Count=function() local count=0;for _,entry in ipairs(entries) do if entry.connected then count+=1 end end;return count end,
 }
end
local vector={}
local vm={__index=function(self,key)
 if key=='Magnitude' then return math.sqrt(self.X*self.X+self.Y*self.Y+self.Z*self.Z) end
 return vector[key]
end,__sub=function(a,b) return vector.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end}
function vector.new(x,y,z) return setmetatable({X=x,Y=y,Z=z or 0},vm) end
local Vector3={new=vector.new};local Vector2={new=vector.new}
local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local function tuple(...) return {...} end
local UDim={new=tuple};local UDim2={new=tuple,fromOffset=tuple,fromScale=tuple}
local ColorSequence={new=tuple};local TweenInfo={new=tuple}
local Enum=setmetatable({}, {__index=function(self,key)
 local category=setmetatable({}, {__index=function(category,name) rawset(category,name,name);return name end})
 rawset(self,key,category);return category
end})
local methods={}
local objectMeta={
 __index=function(self,key)
  if key=='AbsoluteSize' then
   assert(self.ClassName~='ScreenGui','AbsoluteSize must be read from Bounds, not ScreenGui')
   return self.values.AbsoluteSize or Vector2.new(1024,768)
  end
  return methods[key] or self.values[key]
 end,
 __newindex=function(self,key,value)
  if key~='Parent' then self.values[key]=value;return end
  local old=self.values.Parent;if old==value then return end
  if old then local index=table.find(old.children,self);if index then table.remove(old.children,index) end end
  self.values.Parent=value
  if value then table.insert(value.children,self) end
 end,
}
local function object(class,name)
 local result=setmetatable({values={ClassName=class,Name=name or class,ZIndex=1,Visible=true},children={},attrs={},attributeSignals={},propertySignals={}},objectMeta)
 result.Destroying=signal()
 if class=='BindableEvent' then result.Event=signal() end
 return result
end
local Instance={new=function(class) return object(class) end}
function methods:IsA(class)
 return self.ClassName==class or class=='BasePart' and self.ClassName=='Part'
  or class=='GuiObject' and (self.ClassName=='Frame' or self.ClassName=='TextLabel')
end
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants()
 local result={};for _,child in ipairs(self.children) do
  table.insert(result,child);for _,nested in ipairs(child:GetDescendants()) do table.insert(result,nested) end
 end;return result
end
function methods:FindFirstChild(name) for _,child in ipairs(self.children) do if child.Name==name then return child end end end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:GetAttribute(name) return self.attrs[name] end
function methods:GetAttributeChangedSignal(name)
 if not self.attributeSignals[name] then self.attributeSignals[name]=signal() end;return self.attributeSignals[name]
end
function methods:GetPropertyChangedSignal(name)
 if not self.propertySignals[name] then self.propertySignals[name]=signal() end;return self.propertySignals[name]
end
function methods:SetAttribute(name,value) self.attrs[name]=value;self:GetAttributeChangedSignal(name):Fire() end
function methods:Destroy()
 if self.destroyed then return end;self.destroyed=true;self.Destroying:Fire()
 for _,child in ipairs(self:GetChildren()) do child:Destroy() end;self.Parent=nil
end
function methods:Fire(...) self.Event:Fire(...) end
function methods:FireServer() requests+=1 end
local player=object('Player','Tester');player.UserId=24
local playerGui=object('PlayerGui','PlayerGui');playerGui.Parent=player
local character=object('Model','Character');player.Character=character
local root=object('Part','HumanoidRootPart');root.Position=Vector3.new(0,3,0);root.Parent=character
local workspace=object('Workspace','Workspace')
local storage=object('ReplicatedStorage','ReplicatedStorage')
local shared=object('Folder','Shared');shared.Parent=storage
local configModule=object('ModuleScript','TycoonConfig');configModule.Parent=shared
local themeModule=object('ModuleScript','UITheme');themeModule.Parent=shared
local heartbeat=signal()
local services={Players={LocalPlayer=player},Workspace=workspace,ReplicatedStorage=storage,RunService={Heartbeat=heartbeat},
 TweenService={Create=function() error('Tutorial requires no perpetual tweens') end},UserInputService={},GuiService={}}
local game={GetService=function(_,name) assert(services[name],name);return services[name] end}
local function loadConfig() CONFIG_SOURCE end
local function loadTheme() THEME_SOURCE end
local config=loadConfig();local theme=loadTheme()
local function require(module) if module==configModule then return config elseif module==themeModule then return theme end;error('Unexpected module') end
local plots=object('Folder','TycoonPlots');plots.Parent=workspace
local function part(parent,name,x,y,z)
 local result=object('Part',name);result.Position=Vector3.new(x,y,z);result.Parent=parent;return result
end
local function plot(name,owner,x)
 local model=object('Model',name);model:SetAttribute('OwnerUserId',owner);model.Parent=plots
 return model,part(model,'ClaimPad',x,.5,0)
end
local farPlot,farPad=plot('FarPlot',0,55)
local ownPlot,ownClaim=plot('OwnedPlot',24,3)
local nearPlot,nearPad=plot('NearPlot',0,12)
local floorPad=part(ownPlot,'UpgradePad',4,.5,0)
local collector=part(ownPlot,'Collector',5,.5,0)
local generator=part(ownPlot,'DropperUpgradePad',6,.5,0)
local campus=object('Folder','HeroCampus');campus.Parent=workspace
local gallery=object('Folder','Gallery');gallery.Parent=campus
local wrongHero=object('Model','AnotherHero');wrongHero:SetAttribute('HeroId',config.Heroes[2].Id);wrongHero.Parent=gallery
part(wrongHero,'Pedestal',1,.5,0)
local firstHero=object('Model','FirstHero');firstHero:SetAttribute('HeroId',config.Heroes[1].Id);firstHero.Parent=gallery
local costume=part(firstHero,'Pedestal',14,.5,0)
local arena=part(campus,'ArenaPortal',0,.5,-43)
local enemies=object('Folder','TrainingEnemies');enemies.Parent=workspace
local function enemy(name,alive,x)
 local model=object('Model',name);model:SetAttribute('Alive',alive);model.Parent=enemies
 local center=part(model,'Chest',x,3,-100);model.PrimaryPart=center;return model,center
end
local deadEnemy=enemy('DeadEnemy',false,0)
local farEnemy,farCenter=enemy('FarEnemy',true,14)
local nearEnemy,nearCenter=enemy('NearEnemy',true,3)
local script=object('LocalScript','TutorialHUD')
local function runTutorial() TUTORIAL_SOURCE end
runTutorial()
local gui=playerGui:FindFirstChild('QuarterTutorialHUD')
local bounds=gui:FindFirstChild('Bounds');local banner=bounds:FindFirstChild('NextGoal')
local title=banner:FindFirstChild('Title');local description=banner:FindFirstChild('Description');local distance=banner:FindFirstChild('Distance')
local glow=workspace:FindFirstChild('QuarterTutorialTarget')
assert(title.Text=='Загружаем твой квартал…' and banner.Visible and not glow.Enabled,'Loading has clear status and no target highlight')
player:SetAttribute('PersistenceStatus','error')
assert(title.Text=='Прогресс не удалось загрузить' and string.find(description.Text,'защищённым'),'Load failure does not pretend progress is ready')
player:SetAttribute('DataReady',true)
assert(glow.Enabled and glow.Adornee==nearPad,'Nearest free plot wins, rather than first plot or closer owned plot')
root.Position=Vector3.new(54,3,0);heartbeat:Fire(.4)
assert(glow.Adornee==farPad and distance.Text=='Рядом','Target follows player position on one throttled heartbeat')
farPlot:SetAttribute('OwnerUserId',99);nearPlot:SetAttribute('OwnerUserId',99);heartbeat:Fire(.4)
assert(not glow.Enabled and description.Text=='Все дома заняты. Подожди свободного участка.','Full server has an honest waiting message')
root.Position=Vector3.new(0,3,0)
for step,target in ipairs({floorPad,collector,generator,costume,arena}) do
 player:SetAttribute('TutorialStep',step+1)
 assert(glow.Enabled and glow.Adornee==target,'Tutorial target '..(step+1)..' resolves the existing world object')
end
player:SetAttribute('ArenaCombatOptIn',true);root.Position=Vector3.new(0,3,-100);heartbeat:Fire(.4)
assert(glow.Adornee==nearCenter,'Arena guides to nearest living enemy, skipping dead targets')
nearEnemy:SetAttribute('Alive',false);heartbeat:Fire(.4);assert(glow.Adornee==farCenter,'Dead NPC loses tutorial focus')
farEnemy:SetAttribute('Alive',false);heartbeat:Fire(.4);assert(not glow.Enabled and distance.Text=='','Empty arena does not retain an enabled target')
player:SetAttribute('TutorialStep',2)
player:SetAttribute('EffectsQuality','Off');assert(not glow.Enabled and banner.Visible and distance.Text~='','Effects Off keeps readable instructions and disables cosmetic highlight')
player:SetAttribute('EffectsQuality','High');assert(glow.Enabled)
playerGui:SetAttribute('QuarterModalOpen','Arsenal');assert(not banner.Visible and not glow.Enabled,'Open modal hides tutorial and glow')
playerGui:SetAttribute('QuarterModalOpen','');assert(banner.Visible and glow.Enabled)
player:SetAttribute('ObbyActive',true);assert(not banner.Visible and not glow.Enabled,'Obby HUD takes precedence')
player:SetAttribute('ObbyActive',false);assert(banner.Visible)
bounds.AbsoluteSize=Vector2.new(568,320);bounds:GetPropertyChangedSignal('AbsoluteSize'):Fire()
assert(banner.Size[2]==46 and banner.Position[4]==98,'Compact landscape has shorter placement')
playerGui:SetAttribute('QuarterToastOpen',true);assert(not banner.Visible and not glow.Enabled,'Short-landscape toast gets exclusive room')
bounds.AbsoluteSize=Vector2.new(360,760);bounds:GetPropertyChangedSignal('AbsoluteSize'):Fire()
assert(banner.Visible and banner.Size[1]==332,'Portrait fits within safe horizontal bounds')
playerGui:SetAttribute('QuarterToastOpen',false)
player:SetAttribute('TutorialStep',#config.TutorialSteps+1);assert(not banner.Visible and not glow.Enabled,'Completed tutorial removes its prompt')
player:SetAttribute('TutorialStep',2);player.Character=nil;heartbeat:Fire(.4)
assert(not glow.Enabled and distance.Text=='' and description.Text=='Ждём появления персонажа…','Missing character has an honest respawn message and no stale target')
player:SetAttribute('TutorialStep',1)
assert(description.Text=='Ждём появления персонажа…','Respawn does not falsely claim all houses are occupied')
player:SetAttribute('TutorialStep',2)
player.Character=character;heartbeat:Fire(.4);assert(glow.Enabled and glow.Adornee==floorPad)
assert(heartbeat:Count()==1,'Only one throttled tutorial loop exists')
local oldGui,oldGlow=gui,glow
runTutorial()
assert(oldGui.destroyed and oldGlow.destroyed and heartbeat:Count()==1,'Rerun replaces HUD/glow and disconnects old scope')
gui=playerGui:FindFirstChild('QuarterTutorialHUD');glow=workspace:FindFirstChild('QuarterTutorialTarget')
assert(gui and glow and requests==0,'Tutorial never requests currency, rewards or actions')
script:Destroy();assert(heartbeat:Count()==0 and not workspace:FindFirstChild('QuarterTutorialTarget') and not playerGui:FindFirstChild('QuarterTutorialHUD'),'Cleanup removes GUI, target and heartbeat')
player:SetAttribute('TutorialStep',1);heartbeat:Fire(1);assert(not playerGui:FindFirstChild('QuarterTutorialHUD'),'Destroyed scopes do not resurrect on later updates')
return 'Tutorial checks passed: production HUD/UITheme, nearest free/owned/hero/arena/NPC targets, loading/errors, compact toast/modal/obby priority, quality, completion, respawn, rerun and cleanup.'
`;
const state=await LuauState.createAsync();
try {
  const source=fixture.replace('CONFIG_SOURCE',config).replace('THEME_SOURCE',theme).replace('TUTORIAL_SOURCE',tutorial);
  console.log((await state.loadstring(source,'production tutorial integration',true)())[0]);
} finally {state.destroy();}
