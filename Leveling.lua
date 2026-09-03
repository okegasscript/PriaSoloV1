-- ============================================================
-- Leveling.lua - Modul Tab Leveling
-- ============================================================

local Leveling = {}

function Leveling.Setup(Window, DataPetModule, Fluent)
    local LevelingTab = Window:AddTab({ Title = "Leveling" })

    -- Variabel
    local petOptionsLvl = {}
    local selectedPetsLvl = {}
    local selectedUUIDsLvl = {}
    local dropdownControlLvl = nil
    local infoParagraphLvl = nil

    local petOptionsTarget = {}
    local selectedPetsTarget = {}
    local selectedUUIDsTarget = {}
    local dropdownControlTarget = nil
    local infoParagraphTarget = nil

    local targetLevel = 100
    local targetConcurrent = 1
    local autoLevelEnabled = false
    local levelingCoroutine = nil

    local SAVE_KEY_LVL = "SelectedPetUUIDs_Leveling"
    local SAVE_KEY_TARGET = "SelectedPetUUIDs_Target"
    local TARGET_KEY = "TargetLevel"
    local CONCURRENT_KEY = "TargetConcurrent"
    local ENABLE_KEY = "AutoLevelEnabled"

    local autoToggleRef = nil

    -- ============================================================
    -- FUNGSI EQUIP / UNEQUIP
    -- ============================================================
    local function equipPet(uuid)
        local Event = game:GetService("ReplicatedStorage").GameEvents.PetsService
        if not _G.GardenCFrame then
            _G.GardenCFrame = CFrame.new(-16.000007629395, 4, -116.50244903564, 1, 0, 0, 0, 1, 0, 0, 0, 1)
        end
        Event:FireServer("EquipPet", uuid, _G.GardenCFrame)
    end

    local function unequipPet(uuid)
        local Event = game:GetService("ReplicatedStorage").GameEvents.PetsService
        Event:FireServer("UnequipPet", uuid)
    end

    local function getEquippedUUIDs()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local DataService = nil
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        if modules then DataService = modules:FindFirstChild("DataService") end
        if not DataService then DataService = ReplicatedStorage:FindFirstChild("DataService") end
        if not DataService then DataService = _G.DataService end
        if not DataService then return {} end
        local success, mod = pcall(require, DataService)
        if not success or not mod then return {} end
        local data = mod:GetData()
        if not data then return {} end
        local equipped = data.EquippedPets
        if not equipped or type(equipped) ~= "table" then
            if data.PetsData then
                equipped = data.PetsData.EquippedPets
            end
        end
        return equipped or {}
    end

    local function unequipAllEquipped()
        local equipped = getEquippedUUIDs()
        for _, uuid in ipairs(equipped) do
            unequipPet(uuid)
            task.wait(0.3)
        end
    end

    -- ============================================================
    -- LEVELING COROUTINE
    -- ============================================================
    local function startLeveling()
        if levelingCoroutine and coroutine.status(levelingCoroutine) ~= "dead" then
            return
        end
        levelingCoroutine = coroutine.create(function()
            while autoLevelEnabled do
                local equipped = getEquippedUUIDs()
                if #equipped > 0 then
                    for _, uuid in ipairs(equipped) do
                        unequipPet(uuid)
                        task.wait(0.3)
                    end
                end

                for _, uuid in ipairs(selectedUUIDsLvl) do
                    equipPet(uuid)
                    task.wait(0.3)
                end

                local targetQueue = {}
                for _, pet in ipairs(selectedPetsTarget) do
                    table.insert(targetQueue, pet)
                end

                local activeTargets = {}
                local maxConcurrent = math.min(targetConcurrent, 3)

                while #targetQueue > 0 or #activeTargets > 0 do
                    while #activeTargets < maxConcurrent and #targetQueue > 0 do
                        local pet = table.remove(targetQueue, 1)
                        table.insert(activeTargets, pet)
                        equipPet(pet.uuid)
                        task.wait(0.3)
                    end

                    for i = #activeTargets, 1, -1 do
                        local pet = activeTargets[i]
                        local fresh = DataPetModule.findPet({ uuid = pet.uuid })
                        if fresh and fresh.level >= targetLevel then
                            unequipPet(pet.uuid)
                            table.remove(activeTargets, i)
                            task.wait(0.3)
                        end
                    end

                    task.wait(1)
                end

                unequipAllEquipped()

                if autoLevelEnabled then
                    autoLevelEnabled = false
                    _G[ENABLE_KEY] = false
                    if autoToggleRef then autoToggleRef:SetValue(false) end
                    _G.ACTIVE_MODULE = nil
                    Fluent:Notify({ Title = "Leveling", Description = "Semua target selesai, auto leveling dimatikan", Duration = 5 })
                end
                break
            end
        end)
        coroutine.resume(levelingCoroutine)
    end

    -- ============================================================
    -- UPDATE INFO
    -- ============================================================
    local function updatePetInfoLvl(pets)
        if not infoParagraphLvl then return end
        local contentText
        if pets and #pets > 0 then
            local lines = {}
            for i, pet in ipairs(pets) do
                table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
            end
            contentText = "Pet Tim Leveling:\n" .. table.concat(lines, "\n")
        else
            contentText = "Belum ada pet dipilih (Tim Leveling)"
        end
        if infoParagraphLvl.SetContent then
            infoParagraphLvl:SetContent(contentText)
        else
            infoParagraphLvl.Content = contentText
        end
    end

    local function updatePetInfoTarget(pets)
        if not infoParagraphTarget then return end
        local contentText
        if pets and #pets > 0 then
            local lines = {}
            for i, pet in ipairs(pets) do
                table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
            end
            contentText = "Pet Target:\n" .. table.concat(lines, "\n")
        else
            contentText = "Belum ada pet dipilih (Target)"
        end
        if infoParagraphTarget.SetContent then
            infoParagraphTarget:SetContent(contentText)
        else
            infoParagraphTarget.Content = contentText
        end
    end

    -- ============================================================
    -- REFRESH DROPDOWN
    -- ============================================================
    local function refreshPetDropdownLvl()
        if not DataPetModule then return end
        local pets = DataPetModule.findPets({ isFavorite = true })
        if #pets == 0 then
            if dropdownControlLvl then dropdownControlLvl:SetValues({}) end
            petOptionsLvl = {}; selectedPetsLvl = {}; selectedUUIDsLvl = {}
            updatePetInfoLvl({})
            return
        end
        local values = {}
        petOptionsLvl = {}
        for _, pet in ipairs(pets) do
            local label = string.format("%s %s %.2fkg Lv%d [%s]", pet.mutation, pet.name, pet.weight, pet.level, string.sub(pet.uuid, 1, 7))
            table.insert(values, label)
            petOptionsLvl[label] = pet
        end
        if dropdownControlLvl then
            dropdownControlLvl:SetValues(values)
            local savedUUIDs = _G[SAVE_KEY_LVL]
            local restoredLabels = {}
            if savedUUIDs and type(savedUUIDs) == "table" then
                for _, uuid in ipairs(savedUUIDs) do
                    for label, pet in pairs(petOptionsLvl) do
                        if pet.uuid == uuid then
                            table.insert(restoredLabels, label)
                            break
                        end
                    end
                end
            end
            if #restoredLabels > 0 then
                dropdownControlLvl:SetValue(restoredLabels)
                local selected = {}
                for _, label in ipairs(restoredLabels) do
                    if petOptionsLvl[label] then table.insert(selected, petOptionsLvl[label]) end
                end
                selectedPetsLvl = selected
                selectedUUIDsLvl = {}
                for _, pet in ipairs(selected) do table.insert(selectedUUIDsLvl, pet.uuid) end
                updatePetInfoLvl(selected)
            else
                dropdownControlLvl:SetValue({})
                selectedPetsLvl = {}; selectedUUIDsLvl = {}
                updatePetInfoLvl({})
            end
        end
    end

    local function refreshPetDropdownTarget()
        if not DataPetModule then return end
        local pets = DataPetModule.findPets({ isFavorite = false })
        if #pets == 0 then
            if dropdownControlTarget then dropdownControlTarget:SetValues({}) end
            petOptionsTarget = {}; selectedPetsTarget = {}; selectedUUIDsTarget = {}
            updatePetInfoTarget({})
            return
        end
        local values = {}
        petOptionsTarget = {}
        for _, pet in ipairs(pets) do
            local label = string.format("%s %s %.2fkg Lv%d [%s]", pet.mutation, pet.name, pet.weight, pet.level, string.sub(pet.uuid, 1, 7))
            table.insert(values, label)
            petOptionsTarget[label] = pet
        end
        if dropdownControlTarget then
            dropdownControlTarget:SetValues(values)
            local savedUUIDs = _G[SAVE_KEY_TARGET]
            local restoredLabels = {}
            if savedUUIDs and type(savedUUIDs) == "table" then
                for _, uuid in ipairs(savedUUIDs) do
                    for label, pet in pairs(petOptionsTarget) do
                        if pet.uuid == uuid then
                            table.insert(restoredLabels, label)
                            break
                        end
                    end
                end
            end
            if #restoredLabels > 0 then
                dropdownControlTarget:SetValue(restoredLabels)
                local selected = {}
                for _, label in ipairs(restoredLabels) do
                    if petOptionsTarget[label] then table.insert(selected, petOptionsTarget[label]) end
                end
                selectedPetsTarget = selected
                selectedUUIDsTarget = {}
                for _, pet in ipairs(selected) do table.insert(selectedUUIDsTarget, pet.uuid) end
                updatePetInfoTarget(selected)
            else
                dropdownControlTarget:SetValue({})
                selectedPetsTarget = {}; selectedUUIDsTarget = {}
                updatePetInfoTarget({})
            end
        end
    end

    -- ============================================================
    -- UI
    -- ============================================================
    local sectionLvl = LevelingTab:AddSection("Pilih Pet Tim Leveling Favorit")
    dropdownControlLvl = sectionLvl:AddDropdown("PetDropdownLvl", {
        Title = "Daftar Pet Favorite",
        Values = {},
        Multi = true,
        Default = {},
        Callback = function(selectedLabels)
            if selectedLabels and type(selectedLabels) == "table" and #selectedLabels > 0 then
                local selected = {}; local uuids = {}
                for _, label in ipairs(selectedLabels) do
                    if petOptionsLvl[label] then
                        table.insert(selected, petOptionsLvl[label])
                        table.insert(uuids, petOptionsLvl[label].uuid)
                    end
                end
                selectedPetsLvl = selected; selectedUUIDsLvl = uuids
                _G[SAVE_KEY_LVL] = uuids
                updatePetInfoLvl(selected)
            else
                selectedPetsLvl = {}; selectedUUIDsLvl = {}
                _G[SAVE_KEY_LVL] = {}
                updatePetInfoLvl({})
            end
        end
    })
    sectionLvl:AddButton({ Title = "↻ Refresh Daftar Favorite", Callback = function() refreshPetDropdownLvl() end })
    infoParagraphLvl = sectionLvl:AddParagraph({ Title = "Pet Tim Leveling", Content = "Belum ada pet dipilih (Tim Leveling)" })

    local sectionTarget = LevelingTab:AddSection("Pilih Target Leveling (Non-Favorit)")
    dropdownControlTarget = sectionTarget:AddDropdown("PetDropdownTarget", {
        Title = "Daftar Pet Non-Favorit",
        Values = {},
        Multi = true,
        Default = {},
        Callback = function(selectedLabels)
            if selectedLabels and type(selectedLabels) == "table" and #selectedLabels > 0 then
                local selected = {}; local uuids = {}
                for _, label in ipairs(selectedLabels) do
                    if petOptionsTarget[label] then
                        table.insert(selected, petOptionsTarget[label])
                        table.insert(uuids, petOptionsTarget[label].uuid)
                    end
                end
                selectedPetsTarget = selected; selectedUUIDsTarget = uuids
                _G[SAVE_KEY_TARGET] = uuids
                updatePetInfoTarget(selected)
            else
                selectedPetsTarget = {}; selectedUUIDsTarget = {}
                _G[SAVE_KEY_TARGET] = {}
                updatePetInfoTarget({})
            end
        end
    })
    sectionTarget:AddButton({ Title = "↻ Refresh Daftar Target", Callback = function() refreshPetDropdownTarget() end })
    infoParagraphTarget = sectionTarget:AddParagraph({ Title = "Pet Target", Content = "Belum ada pet dipilih (Target)" })

    -- Pengaturan
    local controlSectionLvl = LevelingTab:AddSection("Pengaturan Leveling")
    local targetInput = controlSectionLvl:AddInput("TargetLevelInput", {
        Title = "Target Level",
        Placeholder = "Masukkan target level (angka)",
        Default = tostring(_G[TARGET_KEY] or 100),
        Numeric = true,
        Finished = false,
        Callback = function(value)
            local num = tonumber(value)
            if num and num > 0 then
                targetLevel = num
                _G[TARGET_KEY] = num
            else
                Fluent:Notify({ Title = "Error", Description = "Masukkan angka yang valid!", Duration = 3 })
            end
        end
    })

    local concurrentInput = controlSectionLvl:AddInput("ConcurrentInput", {
        Title = "Target Bersamaan (max 3)",
        Placeholder = "Jumlah target diproses bersamaan",
        Default = tostring(_G[CONCURRENT_KEY] or 1),
        Numeric = true,
        Finished = false,
        Callback = function(value)
            local num = tonumber(value)
            if num and num >= 1 and num <= 3 then
                targetConcurrent = num
                _G[CONCURRENT_KEY] = num
            else
                Fluent:Notify({ Title = "Error", Description = "Masukkan angka 1-3!", Duration = 3 })
            end
        end
    })

    autoToggleRef = controlSectionLvl:AddToggle("AutoLevelToggle", {
        Title = "Auto Leveling",
        Description = "Aktifkan untuk mulai leveling otomatis",
        Default = _G[ENABLE_KEY] or false,
        Callback = function(value)
            if value then
                if _G.ACTIVE_MODULE == "AutoShark" and _G.AUTO_SHARK_TOGGLE then
                    _G.AUTO_SHARK_TOGGLE:SetValue(false)
                end
                _G.ACTIVE_MODULE = "Leveling"
                _G[ENABLE_KEY] = true
                autoLevelEnabled = true
                Fluent:Notify({ Title = "Auto Leveling", Description = "Auto leveling diaktifkan!", Duration = 3 })
                startLeveling()
            else
                _G[ENABLE_KEY] = false
                autoLevelEnabled = false
                if _G.ACTIVE_MODULE == "Leveling" then
                    _G.ACTIVE_MODULE = nil
                end
                Fluent:Notify({ Title = "Auto Leveling", Description = "Auto leveling dinonaktifkan", Duration = 3 })
                unequipAllEquipped()
            end
        end
    })
    _G.LEVELING_TOGGLE = autoToggleRef

    -- Load awal
    task.wait(0.5)
    refreshPetDropdownLvl()
    refreshPetDropdownTarget()
    if _G[TARGET_KEY] then
        targetLevel = _G[TARGET_KEY]
        targetInput:SetValue(tostring(targetLevel))
    end
    if _G[CONCURRENT_KEY] then
        targetConcurrent = _G[CONCURRENT_KEY]
        concurrentInput:SetValue(tostring(targetConcurrent))
    end
    if _G[ENABLE_KEY] ~= nil then
        autoLevelEnabled = _G[ENABLE_KEY]
        autoToggleRef:SetValue(autoLevelEnabled)
    end

    print("[Leveling.lua] Tab Leveling siap.")
end

return Leveling
