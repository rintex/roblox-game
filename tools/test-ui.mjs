import {readFile} from 'node:fs/promises';
import {LuauState} from 'luau-web';
const root='';
const [source,config,main,inventory,admin,obby]=await Promise.all(['src/shared/UITheme.luau','src/shared/TycoonConfig.luau','src/client/TycoonUI.client.luau','src/client/WeaponInventory.client.luau','src/client/AdminPanel.client.luau','src/client/ObbyHUD.client.luau'].map(path=>readFile(root+path,'utf8')));
const fixture=String.raw`
local function signal()
 local self={listeners={}}
 function self:Connect(fn)
  local connection={active=true}
  function connection:Disconnect() self.active=false end
  table.insert(self.listeners,{connection,fn})
  return connection
 end
 function self:Fire(...)
  for _,entry in ipairs(table.clone(self.listeners)) do if entry[1].active then entry[2](...) end end
 end
 function self:Count() local n=0;for _,entry in ipairs(self.listeners) do if entry[1].active then n+=1 end end;return n end
 return self
end
local objects={}
local Instance={new=function(className)
 local self={ClassName=className,Name=className,ZIndex=1,Visible=true,Selectable=true,Active=true,attributes={},signals={}}
 for _,name in ipairs({'MouseEnter','MouseLeave','SelectionGained','SelectionLost','MouseButton1Down','MouseButton1Up'}) do self[name]=signal() end
 function self:IsA(class)
  return self.ClassName==class or class=='GuiObject' and (self.ClassName=='Frame' or self.ClassName=='TextButton' or self.ClassName=='TextLabel')
 end
 function self:GetChildren()
  local children={};for _,object in ipairs(objects) do if object.Parent==self then table.insert(children,object) end end;return children
 end
 function self:FindFirstChild(name) for _,child in ipairs(self:GetChildren()) do if child.Name==name then return child end end end
 function self:FindFirstChildOfClass(class) for _,child in ipairs(self:GetChildren()) do if child.ClassName==class then return child end end end
 function self:IsDescendantOf(ancestor) local parent=self.Parent;while parent do if parent==ancestor then return true end;parent=parent.Parent end;return false end
 function self:SetAttribute(name,value) self.attributes[name]=value end
 function self:GetAttribute(name) return self.attributes[name] end
 function self:Destroy() self.destroyed=true;for _,child in ipairs(self:GetChildren()) do child:Destroy() end;self.Parent=nil end
 table.insert(objects,self);return self
end}
local delayed={}
local task={delay=function(_,fn) table.insert(delayed,fn) end}
local function flush() local queue=delayed;delayed={};for _,fn in ipairs(queue) do fn() end end
local Color3={fromRGB=function(...) return {...} end}
local ColorSequence={new=function(...) return {...} end}
local UDim={new=function(...) return {...} end}
local UDim2={new=function(...) return {...} end,fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}
local TweenInfo={new=function(...) return {...} end}
local player=Instance.new('Player')
local playerGui=Instance.new('PlayerGui');playerGui.Name='PlayerGui';playerGui.Parent=player
local input={InputBegan=signal(),focused=nil,last='Mouse'}
function input:GetLastInputType() return {Name=self.last} end
function input:GetFocusedTextBox() return self.focused end
local guiService={SelectedObject=nil}
local tweenService={}
function tweenService:Create(object,_,goals)
 local tween={Completed=signal(),cancelled=false}
 function tween:Play() for key,value in pairs(goals) do object[key]=value end;self.Completed:Fire() end
 function tween:Cancel() self.cancelled=true;self.Completed:Fire() end
 return tween
end
local Enum={Font={GothamMedium='medium',GothamBold='bold'},TextXAlignment={Left='left'},TextYAlignment={Center='center'},EasingStyle={Quad='quad'},EasingDirection={Out='out'},KeyCode={ButtonB='B',Backspace='Backspace'}}
local services={TweenService=tweenService,UserInputService=input,GuiService=guiService,Players={LocalPlayer=player}}
local game={GetService=function(_,name) return assert(services[name],name) end}
local Config=(function() CONFIG_SOURCE end)()
local Theme=(function() THEME_SOURCE end)()
local function modalObjects(name)
 local panel=Theme.Make('Frame',{Name=name},nil)
 local backdrop=Theme.Make('TextButton',{Name=name..'Backdrop'},nil)
 local selection=Theme.Make('TextButton',{Name=name..'Selection'},panel)
 return panel,backdrop,selection
end
local pa,ba,sa=modalObjects('A');local pb,bb,sb=modalObjects('B')
local closeA=0;local closeB=0
local a=Theme.RegisterModal('A',pa,ba,function() closeA+=1 end,sa)
local b=Theme.RegisterModal('B',pb,bb,function() closeB+=1 end,sb)
assert(not pa.Visible and not pb.Visible and input.InputBegan:Count()==1)
a:Open();assert(pa.Visible and ba.Visible and Theme.HasModal() and playerGui:GetAttribute('QuarterModalOpen')=='A')
b:Open();assert(not pa.Visible and pb.Visible and not a.open and b.open and closeA==1)
b:Close();assert(pb.Visible and not b.open and playerGui:GetAttribute('QuarterModalOpen')=='')
a:Open();assert(not pb.Visible and pa.Visible,'opening during old closing animation must finish old panel')
flush();assert(pa.Visible and not pb.Visible,'stale delayed close must not hide reopened window')
a:Close();a:Open();flush();assert(pa.Visible and a.open)
input.InputBegan:Fire({KeyCode='B'},true);assert(a.open,'processed UI input must be ignored')
input.InputBegan:Fire({KeyCode='B'},false);assert(not a.open and not Theme.HasModal())
flush();assert(not pa.Visible)
input.last='Gamepad1';b:Open();assert(guiService.SelectedObject==sb)
input.InputBegan:Fire({KeyCode='Backspace'},false);assert(not b.open and guiService.SelectedObject==nil)
flush()
Theme.CloseAll();a:Open();Theme.CloseAll();assert(not pa.Visible and not ba.Visible)
a:Destroy();b:Destroy();assert(input.InputBegan:Count()==0,'modal shared listener must be released')
local pc,bc,sc=modalObjects('C');local c=Theme.RegisterModal('same',pc,bc,nil,sc);c:Open()
local pd,bd,sd=modalObjects('D');local d=Theme.RegisterModal('same',pd,bd,nil,sd)
assert(not pc.Visible and not c.scope.alive,'registering duplicate name must tear down previous registration')
d:Open();d:Destroy();assert(not Theme.HasModal() and input.InputBegan:Count()==0)
local scope=Theme.Scope();local parent=Theme.Make('Frame',{},nil)
local button=Theme.Button(scope,parent,'Buy','Buy',UDim2.fromOffset(100,44))
Theme.SetButton(button,'Locked',false);button.MouseEnter:Fire();assert(not button.Active and not button.Selectable and button:FindFirstChild('PressScale').Scale==1)
Theme.SetButton(button,'Buy',true);button.MouseEnter:Fire();assert(button:FindFirstChild('PressScale').Scale>1)
button.MouseButton1Down:Fire();assert(button:FindFirstChild('PressScale').Scale<1)
button.MouseLeave:Fire();assert(button:FindFirstChild('PressScale').Scale==1)
local calls=0;Theme.Shortcut(scope,'M','Y',function() calls+=1 end)
input.InputBegan:Fire({KeyCode='M'},false);input.InputBegan:Fire({KeyCode='Y'},false);assert(calls==2)
input.focused={};input.InputBegan:Fire({KeyCode='M'},false);input.focused=nil
input.InputBegan:Fire({KeyCode='M'},true);assert(calls==2)
for _,weapon in ipairs(Config.Weapons) do local art=Theme.WeaponArt(parent,weapon,UDim2.new(),UDim2.fromOffset(70,70));assert(#art:GetChildren()>=5,'weapon native art must contain geometry') end
for _,hero in ipairs(Config.Heroes) do local art=Theme.HeroArt(parent,hero,UDim2.new(),UDim2.fromOffset(64,64));assert(art:FindFirstChild('Head') and art:FindFirstChild('Body')) end
scope:Destroy();assert(input.InputBegan:Count()==0);input.InputBegan:Fire({KeyCode='M'},false);assert(calls==2)
assert(Theme.Format(10001)=='10 001' and Theme.Format(0/0)=='0' and Theme.Compact(1000000)=='1.0M')
UI_RUNTIME_PHASE
return 'UI theme/modal/controls/native art + actual UI actions/layout: 22 scenarios passed'
`;
const phase=String.raw`-- Execute the actual four LocalScripts to check their integration, not just helper logic.
local uiClock=100
local os={clock=function() return uiClock end}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end}
local function dim(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end
UDim2={new=dim,fromOffset=function(x,y) return dim(0,x,0,y) end,fromScale=function(x,y) return dim(x,0,y,0) end}
for _,group in pairs(Enum) do setmetatable(group,{__index=function(self,key) rawset(self,key,key);return key end}) end
setmetatable(Enum,{__index=function(self,key) local group=setmetatable({},{__index=function(t,k) rawset(t,k,k);return k end});rawset(self,key,group);return group end})
local requests={}
local threads={}
task.spawn=function(fn)
 local thread=coroutine.create(fn);local ok,err=coroutine.resume(thread);assert(ok,err);table.insert(threads,thread)
end
task.wait=function(seconds) return coroutine.yield(seconds) end
task.defer=function(fn) fn() end
local originalNew=Instance.new
local function extend(object)
 object.AbsoluteSize={X=800,Y=600};object.attrsignals={};object.propsignals={}
 for _,name in ipairs({'Activated','ChildAdded','ChildRemoved','Destroying','HealthChanged','Event','OnClientEvent'}) do object[name]=signal() end
 function object:GetPropertyChangedSignal(name) if not self.propsignals[name] then self.propsignals[name]=signal() end;return self.propsignals[name] end
 function object:GetAttributeChangedSignal(name) if not self.attrsignals[name] then self.attrsignals[name]=signal() end;return self.attrsignals[name] end
 function object:SetAttribute(name,value) local previous=self.attributes[name];self.attributes[name]=value;if previous~=value then self:GetAttributeChangedSignal(name):Fire() end end
 function object:WaitForChild(name) return self:FindFirstChild(name) end
 function object:Fire(...) self.Event:Fire(...) end
 function object:FireServer(...) table.insert(requests,{remote=self.Name,args=table.pack(...)}) end
 local oldDestroy=object.Destroy
 function object:Destroy()
  if self.destroyed then return end;self.destroyed=true;self.Destroying:Fire();oldDestroy(self)
 end
 local oldIsA=object.IsA
 function object:IsA(class) return oldIsA(self,class) or class=='GuiObject' and self.ClassName=='ScrollingFrame' or class=='BasePart' and self.ClassName=='Part' end
 setmetatable(object,{__index=function(self,key)
  if key=="Parent" or key=="destroyed" then return nil end
  for _,child in ipairs(self:GetChildren()) do if child.Name==key then return child end end
 end})
 return object
end
Instance.new=function(class) return extend(originalNew(class)) end
extend(player);extend(playerGui);player.UserId=123
local workspace=Instance.new('Workspace');workspace.Name='Workspace'
local camera=Instance.new('Camera');camera.ViewportSize={X=800,Y=600};workspace.CurrentCamera=camera
function workspace:GetServerTimeNow() return 1000 end
services.Workspace=workspace
local replicated=Instance.new('ReplicatedStorage');services.ReplicatedStorage=replicated
local shared=Instance.new('Folder');shared.Name='Shared';shared.Parent=replicated
local configModule=Instance.new('ModuleScript');configModule.Name='TycoonConfig';configModule.Parent=shared
local themeModule=Instance.new('ModuleScript');themeModule.Name='UITheme';themeModule.Parent=shared
local require=function(module) if module==configModule then return Config elseif module==themeModule then return Theme else error('Unexpected module') end end
local remotes=Instance.new('Folder');remotes.Name='TycoonRemotes';remotes.Parent=replicated
for _,name in ipairs({'Notice','ActionRequest','MonetizationRequest','LootResult','AdminRequest','ObbyRequest'}) do local remote=Instance.new('RemoteEvent');remote.Name=name;remote.Parent=remotes end
services.HttpService={JSONDecode=function(_,value)
 if value=='weapons' then return {pulse_pistol=1} elseif value=='upgrades' then return {} else error('Unknown JSON fixture') end
end}
services.RunService={IsStudio=function() return true end}
input.TouchEnabled=false
local stats=Instance.new('Folder');stats.Name='leaderstats';stats.Parent=player
local coins=Instance.new('IntValue');coins.Name='Coins';coins.Value=0;coins.Parent=stats
local level=Instance.new('IntValue');level.Name='Level';level.Value=1;level.Parent=stats
local character=Instance.new('Model');player.Character=character
local humanoid=Instance.new('Humanoid');humanoid.Name='Humanoid';humanoid.Health=100;humanoid.MaxHealth=100;humanoid.Parent=character
player.CharacterAdded=signal()
for name,value in pairs({Floor=1,DropperTier=0,PlotId=1,XP=25,DataReady=true,PersistenceStatus='saved',WeaponInventory='weapons',WeaponUpgrades='upgrades',EquippedWeapon='pulse_pistol',EquippedHero='',IsGameAdmin=true,TutorialStep=1,CollectedTotal=1000,DailyReadyAt=0,DailyStreak=2,DailyNextReward=700}) do player:SetAttribute(name,value) end
local scriptParent=Instance.new('Folder')
local uiScripts={}
local function uiScript(name)
 local object=Instance.new('LocalScript');object.Name=name;object.Parent=scriptParent;table.insert(uiScripts,object);return object
end
;(function() local script=uiScript('TycoonUI');UI_MAIN_SOURCE end)()
;(function() local script=uiScript('WeaponInventory');UI_INVENTORY_SOURCE end)()
;(function() local script=uiScript('AdminPanel');UI_ADMIN_SOURCE end)()
;(function() local script=uiScript('ObbyHUD');UI_OBBY_SOURCE end)()
local main=playerGui:FindFirstChild('TycoonHUD'):FindFirstChild('TycoonUIRuntime')
local arsenal=playerGui:FindFirstChild('WeaponInventoryHUD'):FindFirstChild('WeaponInventoryRuntime')
local function child(parent,name) return assert(parent:FindFirstChild(name),'Missing '..name) end
local shop=child(main,'ShopPanel')
local settings=child(main,'SettingsPanel')
local inv=child(arsenal,'InventoryPanel')
local weaponList=child(inv,'WeaponList')
local pistol=child(weaponList,'pulse_pistol')
assert(not pistol.Upgrade.Active and not shop.Visible and not inv.Visible)
coins.Value=1000;coins:GetPropertyChangedSignal('Value'):Fire();assert(pistol.Upgrade.Active,'currency changes must refresh affordability')
main.Dashboard.ShopButton.Activated:Fire();assert(shop.Visible and not arsenal.InventoryButton.Visible)
input.InputBegan:Fire({KeyCode='I'},false);assert(inv.Visible and not shop.Visible,'inventory shortcut must replace base window')
uiClock+=1;pistol.Upgrade.Activated:Fire();assert(requests[#requests].args[1]=='UpgradeWeapon' and requests[#requests].args[2]=='loot:pulse_pistol')
input.InputBegan:Fire({KeyCode='P'},false);assert(settings.Visible and not inv.Visible)
local preferences=settings.Preferences
local before=player:GetAttribute('EffectsQuality');preferences.Quality.Activated:Fire();assert(before=='High' and player:GetAttribute('EffectsQuality')=='Low')
preferences.Sound.Activated:Fire();assert(player:GetAttribute('SoundEnabled')==false)
preferences.OwnerPanel.Activated:Fire();assert(playerGui:GetAttribute('QuarterModalOpen')=='Admin' and not settings.Visible)
local admin=playerGui.TycoonAdminHUD.OwnerPanel
uiClock+=1;admin.Actions.Heal.Activated:Fire();assert(requests[#requests].remote=='AdminRequest' and requests[#requests].args[1]=='Heal')
input.InputBegan:Fire({KeyCode='M'},false)
uiClock+=1;shop.ProgressList.Quest_collector.Claim.Activated:Fire();assert(requests[#requests].args[1]=='ClaimQuest' and requests[#requests].args[2]=='collector')
uiClock+=1;shop.ProgressList.Achievement_first_home.Claim.Activated:Fire();assert(requests[#requests].args[1]=='ClaimAchievement' and requests[#requests].args[2]=='first_home')
player:SetAttribute('Achievement_first_home',true)
uiClock+=1;shop.StyleList.Title_first_home.EquipTitle.Activated:Fire();assert(requests[#requests].args[1]=='EquipTitle' and requests[#requests].args[2]=='first_home')
assert(not shop.StyleList:FindFirstChild('Pass_VIP') and not shop.StyleList:FindFirstChild('Pass_Neon'),'unconfigured passes must remain absent')
player:SetAttribute('ArenaCombatOptIn',true);player:SetAttribute('AttackReadyAt',1001)
-- Resume the clock loop once to publish cooldown with loot equipped and no hero.
for _,thread in ipairs(threads) do if coroutine.status(thread)=='suspended' then local ok,err=coroutine.resume(thread);assert(ok,err) end end
assert(string.find(main.Dashboard.Vitality.Ability.Text,'1.0'),'loot-only cooldown must display')
player:SetAttribute('ObbyActive',true);assert(not shop.Visible and not inv.Visible and not main.Dashboard.Visible and playerGui:GetAttribute('QuarterModalOpen')=='')
assert(playerGui.RooftopObbyHUD.CourseStatus.Visible)
player:SetAttribute('ObbyActive',false)
camera.ViewportSize={X=568,Y=290};camera:GetPropertyChangedSignal('ViewportSize'):Fire()
arsenal.AbsoluteSize={X=568,Y=290};arsenal:GetPropertyChangedSignal('AbsoluteSize'):Fire()
assert(shop.Size.Y.Offset<=290-60 and inv.Size.Y.Offset<=290-60)
assert(not main.Dashboard.Vitality.Visible,'short landscape must reserve space for tutorial and dock')
for _,thread in ipairs(threads) do if coroutine.status(thread)=='suspended' then local ok,err=coroutine.resume(thread);assert(ok,err) end end
assert(string.find(main.Dashboard.Wallet.XP.Text,'100 HP'),'short landscape must keep health in wallet')
assert(string.find(main.Dashboard.Wallet.XP.Text,'1.0с'),'short landscape must keep server cooldown in wallet')
assert(main.Notification.Position.Y.Offset==98 and main.Notification.Size.Y.Offset==44,'short landscape toast shares tutorial slot instead of covering dock')
local dockTop=290-88-44;assert(98+46<dockTop,'tutorial should end above compact dock')
remotes.LootResult.OnClientEvent:Fire({weaponId='arc_rifle',count=1,duplicate=false,compensationCoins=0})
assert(arsenal.LootReveal.Visible and playerGui:GetAttribute('QuarterModalOpen')=='Loot')
arsenal.LootReveal.Continue.Activated:Fire();assert(arsenal.LootReveal.Continue.Text=='Готово' and string.find(arsenal.LootReveal.ResultDetail.Text,'Добавлено'))
for _,object in ipairs(uiScripts) do object:Destroy() end
assert(not Theme.HasModal() and input.InputBegan:Count()==0,'script destruction must disconnect shortcuts and release modals')
assert(coins:GetPropertyChangedSignal('Value'):Count()==0,'script destruction must release currency listeners')
`;
const state=await LuauState.createAsync();
try{const result=await state.loadstring(fixture.replace('CONFIG_SOURCE',()=>config).replace('THEME_SOURCE',()=>source).replace('UI_RUNTIME_PHASE',()=>phase).replace('UI_MAIN_SOURCE',()=>main).replace('UI_INVENTORY_SOURCE',()=>inventory).replace('UI_ADMIN_SOURCE',()=>admin).replace('UI_OBBY_SOURCE',()=>obby),'ui-theme-test',true)();console.log(result[0]);}finally{state.destroy();}
