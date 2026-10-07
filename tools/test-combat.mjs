// Executes production combat Luau under deterministic Roblox doubles.
// This verifies authoritative rules and object wiring; Studio still checks visuals/physics.
import {readFile} from 'node:fs/promises';
import {LuauState} from 'luau-web';

const [config, rules, service, style] = await Promise.all([
  readFile('src/shared/TycoonConfig.luau', 'utf8'),
  readFile('src/server/Modules/CombatRules.luau', 'utf8'),
  readFile('src/server/Modules/HeroCombatService.luau', 'utf8'),
  readFile('src/server/Modules/VisualStyle.luau', 'utf8'),
]);

const mock = String.raw`
local Config = (function() CONFIG_SOURCE end)()
local clock = 100
local os = {clock = function() return clock end}
local delayed = {}
local task = {spawn = function(fn) fn() end, delay = function(seconds, fn) table.insert(delayed, {seconds,fn}) end}
local function signal()
 local s = {listeners={}}
 function s:Connect(fn)
  local c = {active=true}; function c:Disconnect() self.active=false end
  table.insert(self.listeners,{c,fn}); return c
 end
 function s:Fire(...)
  for _,item in ipairs(self.listeners) do if item[1].active then item[2](...) end end
 end
 return s
end
local vectorMeta = {__type='Vector3'}
local function vector(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
function vectorMeta.__add(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vectorMeta.__sub(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vectorMeta.__mul(a,b)
 if type(a)=='number' then a,b=b,a end
 return vector(a.X*b,a.Y*b,a.Z*b)
end
function vectorMeta.__index(value,key)
 if key=='Magnitude' then return math.sqrt(value.X^2+value.Y^2+value.Z^2) end
 if key=='Unit' then return value*(1/value.Magnitude) end
end
local Vector3={new=vector}
local function typeof(value)
 local meta=type(value)=='table' and getmetatable(value)
 return meta and meta.__type or type(value)
end
local frameMeta={}
local function frame(x,y,z)
 return setmetatable({Position=type(x)=='table' and x or vector(x or 0,y or 0,z or 0)},frameMeta)
end
function frameMeta.__mul(a,b) return frame(a.Position+b.Position) end
local CFrame={new=frame,Angles=function() return frame() end}
local Color3={fromRGB=function(r,g,b) return {R=r,G=g,B=b,Lerp=function(self) return self end} end}
local UDim2={new=function(...) return {...} end,fromOffset=function() return {} end,fromScale=function() return {} end}
local UDim={new=function(...) return {...} end}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local Enum={Material={Metal='Metal',Neon='Neon',Glass='Glass',Fabric='Fabric',SmoothPlastic='SmoothPlastic'},SurfaceType={Smooth='Smooth'},
 NormalId={Front='Front',Back='Back'},SurfaceGuiSizingMode={FixedSize='FixedSize'},PartType={Ball='Ball'},
 ZIndexBehavior={Sibling='Sibling'},
 Font={GothamBold='GothamBold'},RaycastFilterType={Exclude='Exclude'}}
local RaycastParams={new=function() return {} end}
local methods={}
local instanceMeta={}
function instanceMeta.__index(self,key)
 if methods[key] then return methods[key] end
 return self.data[key]
end
function instanceMeta.__newindex(self,key,value)
 if key=='Parent' then
  local old=self.data.Parent
  if old and old.children then
   for index,child in ipairs(old.children) do if child==self then table.remove(old.children,index); break end end
  end
  self.data.Parent=value
  if value and value.children then table.insert(value.children,self) end
 else self.data[key]=value end
 if key=='CFrame' then self.data.Position=value.Position end
end
local Instance={new=function(class)
 return setmetatable({data={ClassName=class,Name=class},children={},attrs={},signals={}},instanceMeta)
end}
function methods:IsA(class) return self.ClassName==class or (class=='BasePart' and self.ClassName=='Part') end
function methods:GetChildren() local copy={};for _,child in ipairs(self.children) do table.insert(copy,child) end; return copy end
function methods:FindFirstChild(name) for _,child in ipairs(self.children) do if child.Name==name then return child end end;return nil end
function methods:FindFirstChildOfClass(class) for _,child in ipairs(self.children) do if child:IsA(class) then return child end end;return nil end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:IsDescendantOf(ancestor)
 local parent=self.Parent
 while parent do if parent==ancestor then return true end;parent=parent.Parent end
 return false
end
function methods:SetAttribute(name,value)
 local old=self.attrs[name];self.attrs[name]=value
 if old~=value and self.signals[name] then self.signals[name]:Fire() end
end
function methods:GetAttribute(name) return self.attrs[name] end
function methods:GetAttributeChangedSignal(name)
 if not self.signals[name] then self.signals[name]=signal() end
 return self.signals[name]
end
function methods:Destroy()
 self.Destroyed=true; self.Parent=nil
 for _,child in ipairs(self:GetChildren()) do child:Destroy() end
end
function methods:EquipTool(tool) tool.Parent=self.Parent end
function methods:TakeDamage(amount) self.Health=math.max(0,self.Health-amount);self.DamageCalls=(self.DamageCalls or 0)+1 end
local Players=Instance.new('Players')
Players.PlayerAdded=signal();Players.PlayerRemoving=signal()
local playerList={}
function methods:GetPlayers() return playerList end
function methods:GetPlayerFromCharacter(character)
 for _,player in ipairs(playerList) do if player.Character==character then return player end end
end
local Workspace=Instance.new('Workspace')
local rayQueue={}
local rayCount=0
function methods:Raycast(origin,direction,parameters)
 rayCount+=1
 assert(direction.Magnitude<=130.001,'Server ray must use catalog range')
 assert(parameters.FilterDescendantsInstances[1]~=nil,'Character must be excluded from ray')
 return table.remove(rayQueue,1)
end
local game={GetService=function(_,name)
 if name=='Players' then return Players end
 if name=='Workspace' then return Workspace end
 error(name)
end}
local Rules=(function() RULES_SOURCE end)()
local Style=(function() STYLE_SOURCE end)()
local script={Parent={WaitForChild=function(_,name) return name end}}
local function require(name)
 if name=='VisualStyle' then return Style end
 assert(name=='CombatRules');return Rules
end
local Service=(function() SERVICE_SOURCE end)()
local profiles={records={},closing=false}
function profiles:Get(player) return self.records[player] end
function profiles:IsClosing() return self.closing end
local tycoon={states={},syncs=0}
function tycoon:GetState(player) return self.states[player] end
function tycoon:SyncPlayer(player) self.syncs+=1 end
function tycoon:SetPerkHandler(fn) self.perkHandler=fn end
local notices={messages={}}
function notices:FireClient(player,payload) table.insert(self.messages,{player,payload}) end
local skill={OnServerEvent=signal()}
local effects={messages={}}
function effects:FireAllClients(payload) table.insert(self.messages,payload) end
local function makePart(parent,name,pos,size)
 local obj=Instance.new('Part');obj.Name=name;obj.Size=size or vector(2,2,1);obj.CFrame=frame(pos);obj.Parent=parent;return obj
end
local function makePlayer(id)
 local p=Instance.new('Player');p.UserId=id;p.Name='Player'..id;p.Parent=Players
 p.CharacterAdded=signal();p.CharacterAppearanceLoaded=signal();p:SetAttribute('DataReady',true)
 local char=Instance.new('Model');char.Name=p.Name;char.Parent=Workspace;p.Character=char
 local root=makePart(char,'HumanoidRootPart',vector(0,3,-100))
 local torso=makePart(char,'UpperTorso',vector(0,3,-100));local head=makePart(char,'Head',vector(0,5,-100))
 local humanoid=Instance.new('Humanoid');humanoid.Health=100;humanoid.WalkSpeed=16;humanoid.Parent=char
 local colors=Instance.new('BodyColors');colors.Parent=char
 for _,name in ipairs({'HeadColor3','TorsoColor3','LeftArmColor3','RightArmColor3','LeftLegColor3','RightLegColor3'}) do colors[name]=Color3.fromRGB(220,200,180) end
 local shirt=Instance.new('Shirt');shirt.ShirtTemplate='saved-shirt';shirt.Parent=char
 local pants=Instance.new('Pants');pants.PantsTemplate='saved-pants';pants.Parent=char
 local face=Instance.new('Decal');face.Transparency=0;face.Parent=head
 local backpack=Instance.new('Backpack');backpack.Parent=p
 table.insert(playerList,p)
 local profile={Coins=75,XP=0,Floor=1,Rebirths=0,EquippedHero='arachna',EquippedWeapon='',Inventory={},EnemiesDefeated=0}
 profiles.records[p]=profile;tycoon.states[p]={profile=profile,leaving=false}
 return p,profile,root,humanoid,colors
end
local a,profile,root,humanoid,baseColors=makePlayer(1)
local b,bprofile,broot,bhumanoid=makePlayer(2)
local service=Service.new(Config,profiles,tycoon,notices,skill,effects)
local checks=0
local function check(name,fn) fn();checks+=1 end
check('finite aim and server range',function()
 assert(not Rules.IsVector({X=1,Y=2,Z=3}))
 for _,value in ipairs({math.huge,-math.huge,0/0,100001}) do assert(not Rules.IsVector(vector(value,0,0))) end
 assert(not Rules.CastDirection(vector(0,0,0),vector(0,0,0),100))
 assert(not Rules.CastDirection(vector(0,0,0),vector(11000,0,0),100))
 local direction=Rules.CastDirection(vector(0,0,0),vector(500,0,0),100)
 assert(direction and direction.Magnitude==100)
 assert(not Rules.CooldownReady(1,0,math.huge))
end)
check('startup builds seven guarded targets and painted massless costume',function()
 service:Start()
 local targets=0;for _ in pairs(service.targets) do targets+=1 end
 assert(targets==7 and service.targetFolder.Parent==Workspace and tycoon.perkHandler)
 local armor=a.Character:FindFirstChild('HeroArmor');assert(armor)
 assert(armor:FindFirstChild('CostumeHead'):FindFirstChild('CostumeFace'))
 assert(armor:FindFirstChild('ChestArmor'):FindFirstChild('CostumeChest'))
 assert(a.Character:FindFirstChildOfClass('Shirt').ShirtTemplate=='')
 for _,piece in ipairs(armor:GetChildren()) do assert(piece.Massless and not piece.Anchored and not piece.CanCollide) end
 local tool=service.issuedTools[a]
 assert(tool and tool.Parent==a.Character and tool:GetAttribute('HeroWeapon')=='arachna')
 assert(tool:FindFirstChild('Handle') and not tool:FindFirstChild('Handle').Anchored)
end)
local bot=service.targets[service.targetFolder:FindFirstChild('TrainingBot1')]
local function queueHit(object) table.insert(rayQueue,{Instance=object,Position=object.Position}) end
local function fire(aim)
 clock+=2
 skill.OnServerEvent:Fire(a,aim or bot.center.Position)
end
check('server rejects missing profile dead player invalid aim and unequipped/fake tools',function()
 local initial=rayCount
 a:SetAttribute('DataReady',false);fire();assert(rayCount==initial)
 a:SetAttribute('DataReady',true)
 humanoid.Health=0;fire();assert(rayCount==initial);humanoid.Health=100
 fire({X=0,Y=4,Z=-100});fire(vector(0/0,0,0));fire(vector(math.huge,0,0));assert(rayCount==initial)
 local issued=service.issuedTools[a];issued.Parent=a:FindFirstChildOfClass('Backpack');fire();assert(rayCount==initial)
 local fake=Instance.new('Tool');fake:SetAttribute('HeroWeapon','arachna');fake.Parent=a.Character;fire();assert(rayCount==initial)
 fake:Destroy();issued.Parent=a.Character
 local stale=profiles.records[a];profiles.records[a]={};fire();assert(rayCount==initial);profiles.records[a]=stale
 profiles.closing=true;fire();assert(rayCount==initial);profiles.closing=false
 root.Position=vector(148,3,-102);fire();assert(rayCount==initial);root.Position=vector(0,3,-100)
end)
check('actual attack uses catalog damage and cooldown; exactly one kill reward',function()
 queueHit(bot.center);fire();assert(bot.health==62)
 local calls=rayCount
 queueHit(bot.center);skill.OnServerEvent:Fire(a,bot.center.Position);assert(rayCount==calls)
 table.clear(rayQueue)
 for _=1,4 do queueHit(bot.center);fire() end
 assert(bot.dead and bot.health==0 and profile.Coins==135 and profile.XP==40 and profile.EnemiesDefeated==1)
 local coins,xp=profile.Coins,profile.XP
 queueHit(bot.center);fire();assert(profile.Coins==coins and profile.XP==xp and #delayed==1)
 delayed[1][2]();assert(not bot.dead and bot.health==80)
end)
check('no damage through walls or beyond server range',function()
 local health=bot.health
 local wall=makePart(Workspace,'Wall',vector(-15,4,-100))
 queueHit(wall);fire();assert(bot.health==health)
 root.Position=vector(48,3,-158)
 -- Sentinel is within arena, but a caller cannot ask for an unwhitelisted model.
 local external={model=Instance.new('Model'),center=makePart(Workspace,'ForgedTarget',vector(48,4,-158)),health=80,dead=false}
 assert(not service:_damageTarget(a,profile,external,100,root.Position,100))
 assert(not service:_damageTarget(a,profile,bot,100,vector(500,3,500),100))
 root.Position=vector(0,3,-100)
end)
check('loot ownership hero unlocks and speed survive rebirth',function()
 clock+=1
 local ok=service:Equip(a,'helios');assert(not ok and profile.EquippedHero=='arachna')
 clock+=1;assert(not service:EquipWeapon(a,'solar_lance'))
 profile.Inventory.solar_lance=1
 clock+=1;assert(service:EquipWeapon(a,'solar_lance') and profile.EquippedWeapon=='solar_lance')
 assert(service.issuedTools[a]:GetAttribute('HeroWeapon')=='loot:solar_lance')
 profile.EquippedHero='';service:Refresh(a)
 assert(service.issuedTools[a] and not a.Character:FindFirstChild('HeroArmor'))
 profile.Rebirths=2;profile.Floor=0
 clock+=1;assert(service:Equip(a,'helios') and profile.EquippedWeapon=='' and humanoid.WalkSpeed==26)
 profile.EquippedHero='titan';service:ApplyPerks(a,humanoid,profile);assert(humanoid.WalkSpeed==24)
 profile.Inventory.solar_lance=0/0;assert(not Rules.OwnsWeapon(Config,profile,'solar_lance'))
 profile.Inventory.solar_lance=math.huge;assert(not Rules.OwnsWeapon(Config,profile,'solar_lance'))
 profile.Inventory.solar_lance=1
end)
check('changing equipment does not bypass previous weapon cooldown',function()
 profile.EquippedHero='titan';service:Refresh(a);clock+=2
 skill.OnServerEvent:Fire(a,bot.center.Position)
 local readyAt=service.nextAttackAt[a]
 assert(readyAt==clock+1.6)
 clock+=0.4;assert(service:Equip(a,'arachna'))
 local calls=rayCount;skill.OnServerEvent:Fire(a,bot.center.Position);assert(rayCount==calls and service.nextAttackAt[a]==readyAt)
end)
check('slam requires line of sight and does not damage targets outside radius',function()
 profile.EquippedHero='titan';service:Refresh(a)
 root.Position=vector(-30,3,-100)
 local botHealth=bot.health
 clock+=2;skill.OnServerEvent:Fire(a,bot.center.Position)
 assert(bot.health==botHealth,'Blocked slam must not damage a robot')
 queueHit(bot.center);clock+=2;skill.OnServerEvent:Fire(a,bot.center.Position)
 assert(bot.health==math.max(0,botHealth-45),'Nearby visible robot receives catalog slam damage')
 root.Position=vector(0,3,-100)
 profile.EquippedHero='arachna';service:Refresh(a)
end)
check('PvP requires both opt in arena and ignores ForceField or dead targets',function()
 a:SetAttribute('ArenaCombatOptIn',true);b:SetAttribute('ArenaCombatOptIn',true)
 broot.Position=vector(12,3,-100)
 local before=bhumanoid.Health;assert(service:_damagePlayer(a,b,18,root.Position,100) and bhumanoid.Health==before-18)
 assert(not service:_damagePlayer(a,a,18,root.Position,100))
 b:SetAttribute('ArenaCombatOptIn',false);assert(not service:_damagePlayer(a,b,18,root.Position,100));b:SetAttribute('ArenaCombatOptIn',true)
 a:SetAttribute('ArenaCombatOptIn',false);assert(not service:_damagePlayer(a,b,18,root.Position,100));a:SetAttribute('ArenaCombatOptIn',true)
 for _,position in ipairs({vector(49,3,-100),vector(0,3,-81),vector(0,31,-100)}) do broot.Position=position;assert(not service:_damagePlayer(a,b,18,root.Position,100)) end
 broot.Position=vector(12,3,-100)
 local field=Instance.new('ForceField');field.Parent=b.Character;assert(not service:_damagePlayer(a,b,18,root.Position,100));field:Destroy()
 bhumanoid.Health=0;assert(not service:_damagePlayer(a,b,18,root.Position,100));bhumanoid.Health=100
 b:SetAttribute('DataReady',false);assert(not service:_damagePlayer(a,b,18,root.Position,100));b:SetAttribute('DataReady',true)
 local coins,xp,kills=profile.Coins,profile.XP,profile.EnemiesDefeated
 queueHit(broot);fire();assert(bhumanoid.Health==82)
 assert(profile.Coins==coins and profile.XP==xp and profile.EnemiesDefeated==kills)
end)
check('reward caps and repeated dead damage',function()
 local bounded={Coins=Config.MaxCoins-1,XP=Config.MaxXP-2,EnemiesDefeated=0}
 local coins,xp=Rules.Reward(Config,bounded,60,40)
 assert(coins==1 and xp==2 and bounded.Coins==Config.MaxCoins and bounded.XP==Config.MaxXP)
 local enemy={health=5,dead=false};local damage,killed=Rules.ApplyDamage(enemy,18)
 assert(damage==5 and killed and enemy.dead)
 local nextDamage,nextKilled=Rules.ApplyDamage(enemy,18);assert(nextDamage==0 and not nextKilled)
end)
check('appearance removal restores base colors and cleanup cancels delayed respawn',function()
 profile.EquippedHero='arachna';service:Refresh(a)
 clock+=1;assert(service:Equip(a,''));assert(not service.issuedTools[a] and not a.Character:FindFirstChild('HeroArmor'))
 assert(baseColors.HeadColor3.R==220 and baseColors.TorsoColor3.R==220)
 assert(a.Character:FindFirstChildOfClass('Shirt').ShirtTemplate=='saved-shirt')
 assert(a.Character:FindFirstChildOfClass('Pants').PantsTemplate=='saved-pants')
 assert(a.Character:FindFirstChild('Head'):FindFirstChildOfClass('Decal').Transparency==0)
 a:SetAttribute('ArenaCombatOptIn',true);a.CharacterAdded:Fire(a.Character);assert(a:GetAttribute('ArenaCombatOptIn')==false)
 service:Destroy();assert(not service.targetFolder.Parent and not service.issuedTools[b])
 delayed[1][2]();assert(service.destroyed)
end)
return checks
`;

const code = mock.replace('CONFIG_SOURCE', config).replace('RULES_SOURCE', rules).replace('STYLE_SOURCE', style).replace('SERVICE_SOURCE', service);
const state = await LuauState.createAsync();
try {
  const run = state.loadstring(code, 'Combat server authority tests', true);
  const result = await run();
  console.log(`Combat tests passed: ${result[0]} cases for issued tools, unlocks, inventory, aim, cooldown, PvE rewards, walls, range, PvP opt in, ForceField, appearance and cleanup.`);
} finally {
  state.destroy();
}
