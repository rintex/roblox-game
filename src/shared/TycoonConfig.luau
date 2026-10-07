-- All prices, rewards and unlock requirements are server-owned.
local Config = {
 GameTitle='Герои квартала',
 StartingCoins=75,
 Floors={
  {Name='Первый этаж',Cost=50,Income=5,XP=20},
  {Name='Второй этаж',Cost=200,Income=14,XP=40},
  {Name='Геройская лаборатория',Cost=600,Income=35,XP=70},
 },
 DropperCosts={60,140,320,900,2400}, DropperMultiplierStep=0.5,
 ThirdFloorIncomeMultiplier=1.5,ThirdFloorWalkSpeed=24,DefaultWalkSpeed=16,
 BonusCoins=120,BonusXP=15,BonusCooldown=60,
 IncomeInterval=1,ActionCooldown=0.35,MaxBank=100000,MaxCoins=1000000000,MaxXP=1000000000,
 MaxRebirths=20,RebirthBaseCost=25000,RebirthBonusStep=0.35,RebirthMinFloor=3,RebirthMinTier=5,
 DailyReward=500,DailyCooldown=86400,
 Quests={
  {Id='collector',Title='Собери 1 000 монет',Target=1000,RewardCoins=500,RewardXP=100},
  {Id='builder',Title='Построй три этажа',Target=3,RewardCoins=1000,RewardXP=150},
  {Id='fighter',Title='Победи пять противников',Target=5,RewardCoins=750,RewardXP=100},
 },
 Heroes={
  {Id='arachna',Name='Человек-паук',Style='spider',Description='Красно-синий костюм, маска с паутиной и паучий символ.',MinFloor=1,MinRebirths=0,Color={190,39,45},Weapon='Паутинный заряд',Damage=18,Range=100,Cooldown=0.8,Kind='ray',WalkSpeed=20},
  {Id='nightweaver',Name='Человек-паук: чёрный костюм',Style='symbiote',Description='Чёрный костюм с большим белым пауком и усиленным зарядом.',MinFloor=2,MinRebirths=0,Color={44,49,64},Weapon='Симбиотическая паутина',Damage=24,Range=110,Cooldown=0.7,Kind='ray',WalkSpeed=22},
  {Id='volt',Name='Железный человек',Style='iron',Description='Красно-золотая броня, светящийся реактор и репульсор.',MinFloor=3,MinRebirths=0,Color={184,36,40},Weapon='Репульсор',Damage=30,Range=120,Cooldown=0.65,Kind='ray',WalkSpeed=24},
  {Id='titan',Name='Халк',Style='hulk',Description='Зелёная кожа, мощные плечи, фиолетовые штаны и удар по земле.',MinFloor=3,MinRebirths=1,Color={100,166,67},Weapon='Удар Халка',Damage=45,Range=20,Cooldown=1.6,Kind='slam',WalkSpeed=22},
  {Id='frost',Name='Тор',Style='thor',Description='Броня с дисками, красный плащ и молот Мьёльнир.',MinFloor=3,MinRebirths=1,Color={159,180,204},Weapon='Мьёльнир',Damage=35,Range=110,Cooldown=1,Kind='ray',WalkSpeed=22},
  {Id='helios',Name='Железный человек: Mark 85',Style='iron_gold',Description='Золотая наноброня с усиленным реактором.',MinFloor=3,MinRebirths=2,Color={223,177,74},Weapon='Нанорепульсор',Damage=50,Range=130,Cooldown=0.7,Kind='ray',WalkSpeed=26},
 },
 Obby={RewardCoins=300,RewardXP=75,RewardCooldown=300,MinimumRunSeconds=15,MaximumRunSeconds=600,
  StageMinimumSeconds=0.45,WalkSpeed=16,JumpPower=50,JumpHeight=7.2,
  Platforms={
   {X=-27,Y=4,Z=90},{X=-24,Y=5,Z=100},{X=-20,Y=6,Z=110},{X=-26,Y=7,Z=120},
   {X=-20,Y=8,Z=130},{X=-12,Y=9,Z=136},{X=-2,Y=10,Z=137},{X=8,Y=11,Z=133},
   {X=17,Y=12,Z=126},{X=25,Y=13,Z=117},{X=27,Y=14,Z=106},{X=24,Y=15,Z=94},
   {X=17,Y=16,Z=85},{X=8,Y=17,Z=83},{X=-2,Y=18,Z=85},{X=-12,Y=19,Z=90},
  },Checkpoints={4,8,12}},
 Weapons={
  {Id='pulse_pistol',Name='Импульсный пистолет',Rarity='Обычное',LootWeight=40,Damage=12,Range=90,Cooldown=0.65,Kind='ray',Color={165,186,202}},
  {Id='thread_launcher',Name='Нитевой метатель',Rarity='Необычное',LootWeight=28,Damage=20,Range=100,Cooldown=0.9,Kind='ray',Color={59,204,167}},
  {Id='arc_rifle',Name='Дуговая винтовка',Rarity='Редкое',LootWeight=18,Damage=28,Range=110,Cooldown=0.75,Kind='ray',Color={78,186,255}},
  {Id='gravity_hammer',Name='Гравитационный молот',Rarity='Эпическое',LootWeight=9,Damage=45,Range=18,Cooldown=1.6,Kind='slam',Color={157,101,238}},
  {Id='frost_projector',Name='Полярный излучатель',Rarity='Легендарное',LootWeight=4,Damage=36,Range=110,Cooldown=1,Kind='ray',Color={255,176,64}},
  {Id='solar_lance',Name='Солнечное копьё',Rarity='Мифическое',LootWeight=1,Damage=60,Range=130,Cooldown=1.1,Kind='ray',Color={255,100,150}},
 },
 MaxWeaponCopies=99,
 Airdrops={FirstDelay=20,MinInterval=90,MaxInterval=180,FallSeconds=7,Lifetime=90,DuplicateCoins=100,
  Locations={{X=-62,Z=58},{X=62,Z=58},{X=-70,Z=-55},{X=70,Z=-55},{X=0,Z=80}}},
 -- Replace zero only with genuine Game Pass IDs from your published experience.
 GamePasses={
  VIP={Id=0,Name='Клуб героев',Description='Золотой титул над персонажем.'},
  Neon={Id=0,Name='Неоновый арсенал',Description='Косметический световой след оружия.'},
 },
 Persistence={StoreName='HouseTycoon_v1',SaveInterval=60,LockSeconds=180,MaxRetries=3},
 PlotLayout={},
 AdminUserIds={},
}
for _,z in ipairs({-170,-102,-34,34,102,170}) do
 for _,x in ipairs({-148,148}) do table.insert(Config.PlotLayout,{X=x,Z=z}) end
end
function Config.GetLevel(xp) return 1+math.floor(xp/100) end
function Config.RebirthCost(rebirths) return Config.RebirthBaseCost*(rebirths+1) end
function Config.IncomeFor(floor,tier,rebirths)
 local definition=Config.Floors[floor]
 if not definition then return 0 end
 local amount=definition.Income*(1+tier*Config.DropperMultiplierStep)*(1+(rebirths or 0)*Config.RebirthBonusStep)
 if floor==#Config.Floors then amount*=Config.ThirdFloorIncomeMultiplier end
 return math.floor(amount)
end
function Config.GetHero(id)
 for _,hero in ipairs(Config.Heroes) do if hero.Id==id then return hero end end
 return nil
end
function Config.GetWeapon(id)
 for _,weapon in ipairs(Config.Weapons) do if weapon.Id==id then return weapon end end
 return nil
end
function Config.CanUseHero(profile,hero)
 if type(profile)~='table' or type(hero)~='table' then return false end
 local rebirths=profile.Rebirths or 0
 local earnedFloor=if rebirths>0 then #Config.Floors else profile.Floor or 0
 return earnedFloor>=hero.MinFloor and rebirths>=hero.MinRebirths
end
return Config
