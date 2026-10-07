-- Course display and recovery buttons. Only the server advances checkpoints.
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Workspace=game:GetService('Workspace')
local player=Players.LocalPlayer
local playerGui=player:WaitForChild('PlayerGui')
local config=require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('TycoonConfig'))
local request=ReplicatedStorage:WaitForChild('TycoonRemotes'):WaitForChild('ObbyRequest')
local old=playerGui:FindFirstChild('RooftopObbyHUD')
if old then local stop=old:FindFirstChild('Stop');if stop then stop:Fire() end;old:Destroy() end
local gui=Instance.new('ScreenGui');gui.Name='RooftopObbyHUD';gui.ResetOnSpawn=false
 gui.IgnoreGuiInset=false;gui.DisplayOrder=18;gui.Parent=playerGui
local stop=Instance.new('BindableEvent');stop.Name='Stop';stop.Parent=gui
local alive=true;local connections={};local lastRequest=-math.huge
local function make(class,name,parent)
 local value=Instance.new(class);value.Name=name;value.Parent=parent;return value
end
local function round(object)
 local corner=make('UICorner','Round',object);corner.CornerRadius=UDim.new(0,12)
end
local panel=make('Frame','CourseStatus',gui)
panel.AnchorPoint=Vector2.new(0.5,0);panel.Position=UDim2.new(0.5,0,0,12)
panel.Size=UDim2.new(1,-28,0,160);panel.BackgroundColor3=Color3.fromRGB(25,31,43)
panel.BorderSizePixel=0;panel.Visible=false;round(panel)
local limit=make('UISizeConstraint','WidthLimit',panel);limit.MaxSize=Vector2.new(420,160)
local title=make('TextLabel','Title',panel)
title.Position=UDim2.fromOffset(14,10);title.Size=UDim2.new(1,-28,0,26)
title.BackgroundTransparency=1;title.Text='КРЫШИ КВАРТАЛА';title.TextColor3=Color3.fromRGB(255,211,100)
title.Font=Enum.Font.GothamBold;title.TextSize=18
local progress=make('TextLabel','Progress',panel)
progress.Position=UDim2.fromOffset(14,39);progress.Size=UDim2.new(1,-28,0,46)
progress.BackgroundTransparency=1;progress.TextColor3=Color3.fromRGB(236,244,255)
progress.TextSize=14;progress.Font=Enum.Font.GothamMedium;progress.TextWrapped=true
local best=make('TextLabel','Best',panel)
best.Position=UDim2.fromOffset(14,84);best.Size=UDim2.new(1,-28,0,22)
best.BackgroundTransparency=1;best.TextColor3=Color3.fromRGB(171,192,211)
best.TextSize=12;best.Font=Enum.Font.GothamMedium
for index,definition in ipairs({{'Checkpoint','К точке'},{'Exit','Выйти'}}) do
 local button=make('TextButton',definition[1],panel)
 button.Position=UDim2.new((index-1)*0.5,14-(index-1)*7,0,113)
 button.Size=UDim2.new(0.5,-21,0,36);button.BorderSizePixel=0;round(button)
 button.BackgroundColor3=Color3.fromRGB(93,217,171);button.TextColor3=Color3.fromRGB(25,31,43)
 button.Font=Enum.Font.GothamBold;button.TextSize=14;button.Text=definition[2]
 table.insert(connections,button.Activated:Connect(function()
  if player:GetAttribute('ObbyActive')~=true or os.clock()-lastRequest<1 then return end
  lastRequest=os.clock();request:FireServer(definition[1])
 end))
end
local function setOtherUI(visible)
 local main=playerGui:FindFirstChild('TycoonHUD');local runtime=main and main:FindFirstChild('TycoonUIRuntime')
 if runtime then
  for _,name in ipairs({'Dashboard','Guide'}) do local value=runtime:FindFirstChild(name);if value then value.Visible=visible end end
  if not visible then
   for _,name in ipairs({'ShopPanel','ShopBackdrop'}) do local value=runtime:FindFirstChild(name);if value then value.Visible=false end end
  end
 end
 local inventory=playerGui:FindFirstChild('WeaponInventoryHUD');local inventoryRuntime=inventory and inventory:FindFirstChild('WeaponInventoryRuntime')
 local inventoryButton=inventoryRuntime and inventoryRuntime:FindFirstChild('InventoryButton');if inventoryButton then inventoryButton.Visible=visible end
 if inventoryRuntime and not visible then
  for _,name in ipairs({'InventoryPanel','LootReveal','Backdrop'}) do local value=inventoryRuntime:FindFirstChild(name);if value then value.Visible=false end end
 end
 local admin=playerGui:FindFirstChild('TycoonAdminHUD');local adminButton=admin and admin:FindFirstChild('AdminButton');if adminButton then adminButton.Visible=visible end
 if admin and not visible then
  for _,name in ipairs({'OwnerPanel','Backdrop'}) do local value=admin:FindFirstChild(name);if value then value.Visible=false end end
 end
end
local function update()
 if not alive then return end
 local active=player:GetAttribute('ObbyActive')==true;panel.Visible=active;setOtherUI(not active)
 if not active then return end
 local stage=player:GetAttribute('ObbyStage') or 1
 local checkpoint=player:GetAttribute('ObbyCheckpoint') or 1
 local started=player:GetAttribute('ObbyStartedAt') or Workspace:GetServerTimeNow()
 local elapsed=math.max(0,Workspace:GetServerTimeNow()-started)
 progress.Text='Этап '..stage..' / '..#config.Obby.Platforms..'  ·  '..string.format('%.1f',elapsed)..' сек.\nКонтрольная точка: '..checkpoint..' · падение не сбрасывает весь маршрут'
 local record=player:GetAttribute('ObbyBestMilliseconds') or 0
 best.Text=if record>0 then ('Рекорд: '..string.format('%.1f',record/1000)..' сек. · Побед: '..(player:GetAttribute('ObbyWins') or 0)) else 'Награда: +300 монет и +75 XP · раз в 5 минут'
end
for _,name in ipairs({'ObbyActive','ObbyStage','ObbyCheckpoint','ObbyStartedAt','ObbyWins','ObbyBestMilliseconds'}) do
 table.insert(connections,player:GetAttributeChangedSignal(name):Connect(update))
end
local function cleanup()
 if not alive then return end;alive=false
 for _,connection in ipairs(connections) do connection:Disconnect() end
 setOtherUI(true);gui:Destroy()
end
table.insert(connections,stop.Event:Connect(cleanup));table.insert(connections,script.Destroying:Connect(cleanup))
update()
task.spawn(function() while alive do task.wait(0.2);update() end end)
