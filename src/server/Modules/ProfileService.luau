-- DataStore + блокировка сессии: два сервера не перезаписывают один профиль.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Schema = require(script.Parent:WaitForChild("ProfileSchema"))

local ProfileService = {}
ProfileService.__index = ProfileService

function ProfileService.new(config)
	local self = setmetatable({
		config = config,
		records = {},
		closing = false,
		sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false),
		store = nil,
	}, ProfileService)
	if game.GameId ~= 0 then
		local ok, store = pcall(function()
			return DataStoreService:GetDataStore(config.Persistence.StoreName)
		end)
		if ok then self.store = store end
	end
		task.spawn(function()
			while not self.closing do
				task.wait(config.Persistence.SaveInterval)
				if self.closing then break end
				for player, record in pairs(self.records) do
					if record.ready and not record.saving and not record.releasing then
						task.spawn(function()
							if record.cancelled then self:Release(player) else self:Save(player) end
						end)
					end
				end
			end
		end)
	game:BindToClose(function()
		self.closing = true
		local pending = 0
		for player in pairs(self.records) do
			pending += 1
			task.spawn(function()
				self:Release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 27
		while pending > 0 and os.clock() < deadline do task.wait(0.1) end
	end)
	return self
end

function ProfileService:IsClosing()
	return self.closing
end

function ProfileService:_update(key, callback)
	local lastError
	for attempt = 1, self.config.Persistence.MaxRetries do
		local ok, result = pcall(function() return self.store:UpdateAsync(key, callback) end)
		if ok then return true, result end
		lastError = result
		if attempt < self.config.Persistence.MaxRetries then task.wait(0.8 * attempt) end
	end
	return false, lastError
end

function ProfileService:_sessionProfile(player, record)
	if record.cancelled then
		record.loading = false
		self.records[player] = nil
		return nil, "Игрок вышел во время загрузки"
	end
	record.profile = Schema.New(self.config)
	record.ready = true
	record.mode = "session"
	record.loading = false
	player:SetAttribute("PersistenceMode", "session")
	player:SetAttribute("PersistenceStatus", "session")
	return record.profile
end

function ProfileService:Load(player)
	if self.closing then return nil, "Сервер завершает работу" end
	if self.records[player] then return nil, "Профиль уже загружается" end
	local record = {
		key = "Player_" .. player.UserId,
		token = self.sessionId .. ":" .. player.UserId .. ":" .. HttpService:GenerateGUID(false),
		ready = false, loading = true, cancelled = false, saving = false, player = player,
	}
	self.records[player] = record
	player:SetAttribute("PersistenceStatus", "loading")
	if not self.store then
		if RunService:IsStudio() then return self:_sessionProfile(player, record) end
		self.records[player] = nil
		record.loading = false
		return nil, "Хранилище прогресса недоступно"
	end
	local reason
	local ok, stored = self:_update(record.key, function(old)
		reason = nil
		if record.cancelled then reason = "Игрок вышел"; return nil end
		if old ~= nil and (type(old) ~= "table" or old.Version ~= 1 or type(old.Data) ~= "table") then
			reason = "Неизвестный формат сохранения"; return nil
		end
		local now = os.time()
		local lock = old and old.Session
		if type(lock) == "table" and lock.Id ~= record.token
			and type(lock.ExpiresAt) == "number" and lock.ExpiresAt > now then
			reason = "Профиль ещё открыт на другом сервере. Попробуйте войти позже."; return nil
		end
		return {
			Version = 1, Data = Schema.Normalize(old and old.Data, self.config, now),
			Session = { Id = record.token, ExpiresAt = now + self.config.Persistence.LockSeconds },
			UpdatedAt = now,
		}
	end)
	if record.cancelled then
		-- Не сохраняем стартовые значения, если игрок вышел во время UpdateAsync.
		if ok and stored and stored.Session and stored.Session.Id == record.token then
			self:_update(record.key, function(old)
				if old and old.Session and old.Session.Id == record.token then
					old.Session = nil
					return old
				end
				return nil
			end)
		end
		self.records[player] = nil
		record.loading = false
		return nil, "Игрок вышел во время загрузки"
	end
	if not ok then
		if RunService:IsStudio() then return self:_sessionProfile(player, record) end
		self.records[player] = nil
		record.loading = false
		return nil, "Не удалось загрузить прогресс. Попробуйте войти позже."
	end
	if not stored or not stored.Session or stored.Session.Id ~= record.token then
		self.records[player] = nil
		record.loading = false
		return nil, reason or "Не удалось получить блокировку профиля"
	end
	record.profile = Schema.Normalize(stored.Data, self.config, os.time())
	record.ready = true
	record.mode = "saved"
	record.loading = false
	player:SetAttribute("PersistenceMode", "saved")
	player:SetAttribute("PersistenceStatus", "saved")
	return record.profile
end

function ProfileService:Get(player)
	local record = self.records[player]
	return if record and record.ready and not record.cancelled then record.profile else nil
end

function ProfileService:_persist(record, release)
	if record.mode == "session" then return true end
	local deadline = os.clock() + 12
	while record.saving and os.clock() < deadline do task.wait(0.1) end
	if record.saving then return false, "Предыдущее сохранение ещё выполняется" end
	if not record.ready or (record.cancelled and not release) then return false, "Профиль закрыт" end
	record.saving = true
	record.player:SetAttribute("PersistenceStatus", "saving")
	local snapshot = Schema.Copy(record.profile)
	local lostLock = false
	local ok, stored = self:_update(record.key, function(old)
		lostLock = false
		if not old or type(old) ~= "table" or old.Version ~= 1
			or type(old.Session) ~= "table" or old.Session.Id ~= record.token then
			lostLock = true; return nil
		end
		local now = os.time()
		return {
			Version = 1, Data = snapshot, UpdatedAt = now,
			Session = if release then nil else { Id = record.token, ExpiresAt = now + self.config.Persistence.LockSeconds },
		}
	end)
	record.saving = false
	if not ok or not stored then
		record.player:SetAttribute("PersistenceStatus", "error")
		if lostLock then
			record.ready = false
			record.player:SetAttribute("DataReady", false)
			record.player:Kick("Профиль открыт в другой сессии. Войдите в игру снова.")
		end
		warn("Не удалось сохранить профиль пользователя " .. record.player.UserId)
		return false, "Сохранение не подтверждено"
	end
	record.player:SetAttribute("PersistenceStatus", "saved")
	return true
end

function ProfileService:Save(player)
	local record = self.records[player]
	if not record or record.cancelled then return false, "Профиль не загружен" end
	return self:_persist(record, false)
end

function ProfileService:Release(player)
	local record = self.records[player]
	if not record then return true end
	record.cancelled = true
	player:SetAttribute("DataReady", false)
	-- Выход и BindToClose могут одновременно ждать одну загрузку/запись.
	local deadline = os.clock() + 25
	while (record.loading or record.releasing) and os.clock() < deadline do task.wait(0.1) end
	if record.loading or record.releasing then return false, "Загрузка или сохранение ещё выполняются" end
	if self.records[player] ~= record then return true end
	if not record.ready then self.records[player] = nil; return true end
	record.releasing = true
	local ok, message = self:_persist(record, true)
	record.releasing = false
	-- При сетевой ошибке сохраняем снимок в памяти для следующей попытки.
	if ok or not record.ready then self.records[player] = nil end
	return ok, message
end

return ProfileService
