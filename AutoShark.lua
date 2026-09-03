-- ============================================================
-- AutoShark.lua - FINAL (menggunakan Content)
-- ============================================================

local AutoShark = {}

function AutoShark.Setup(Window, DataPetModule, Fluent)
    local AutoSharkTab = Window:AddTab({ Title = "AutoShark" })

    -- Variabel
    local petOptionsShark = {}
    local petOptionsTarget = {}
    local petOptionsTumbal = {}

    local selectedUUIDsShark = {}
    local selectedUUIDsTarget = {}
    local selectedUUIDsTumbal = {}

    local dropdownControlShark = nil
    local dropdownControlTarget = nil
    local dropdownControlTumbal = nil
    local dropdownControlMutation = nil

    local infoParagraphShark = nil
    local infoParagraphTarget = nil
    local infoParagraphTumbal = nil

    local mutationOptions = {}
    local selectedMutation = nil

    local autoSharkEnabled = false
    local autoToggleRef = nil
    local sharkCoroutine = nil

    local SAVE_KEY_SHARK = "SelectedUUIDs_Shark"
    local SAVE_KEY_TARGET = "SelectedUUIDs_SharkTarget"
    local SAVE_KEY_TUMBAL = "SelectedUUIDs_SharkTumbal"
    local SAVE_KEY_MUTATION = "SelectedMutation_Shark"
    local ENABLE_KEY = "AutoSharkEnabled"

    local GARDEN_CFRAME = CFrame.new(-16.000007629395, 4, -116.50244903564, 1, 0, 0, 0, 1, 0, 0, 0, 1)

    -- ============================================================
    -- EQUIP / UNEQUIP
    -- ============================================================
    local function equipPet(uuid)
        local Event = game:GetService("ReplicatedStorage").GameEvents.PetsService
        Event:FireServer("EquipPet", uuid, GARDEN_CFRAME)
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
    -- CEK MIMIC
    -- ============================================================
    local function findMimicUUID(uuids)
        for _, uuid in ipairs(uuids) do
            local pet = DataPetModule.findPet({ uuid = uuid })
            if pet and pet.mutation == "Mimic" then
                return uuid
            end
        end
        return nil
    end

    -- ============================================================
    -- VALIDASI
    -- ============================================================
    local function validateBeforeStart()
        if #selectedUUIDsShark == 0 then
            Fluent:Notify({ Title = "Error", Description = "Pilih tim shark terlebih dahulu! (min 2 pet favorit, 1 di antaranya Mimic)", Duration = 5 })
            return false
        end
        if #selectedUUIDsTarget == 0 then
            Fluent:Notify({ Title = "Error", Description = "Pilih target terlebih dahulu!", Duration = 5 })
            return false
        end
        if #selectedUUIDsTumbal == 0 then
            Fluent:Notify({ Title = "Error", Description = "Pilih tumbal terlebih dahulu!", Duration = 5 })
            return false
        end
        if not selectedMutation then
            Fluent:Notify({ Title = "Error", Description = "Pilih target mutasi!", Duration = 5 })
            return false
        end

        local mimicUUID = findMimicUUID(selectedUUIDsShark)
        if not mimicUUID then
            Fluent:Notify({ Title = "Error", Description = "Tidak ada pet dengan mutasi 'Mimic' di tim shark!", Duration = 5 })
            return false
        end

        local sharkCount = 0
        for _, uuid in ipairs(selectedUUIDsShark) do
            if uuid ~= mimicUUID then
                sharkCount = sharkCount + 1
            end
        end
        if sharkCount == 0 then
            Fluent:Notify({ Title = "Error", Description = "Tim shark hanya berisi mimic, butuh setidaknya 1 shark!", Duration = 5 })
            return false
        end

        return true
    end

    -- ============================================================
    -- LOGIKA UTAMA
    -- ============================================================
    local function startAutoShark()
        if sharkCoroutine and coroutine.status(sharkCoroutine) ~= "dead" then
            return
        end

        if not validateBeforeStart() then
            if autoToggleRef then autoToggleRef:SetValue(false) end
            autoSharkEnabled = false
            _G[ENABLE_KEY] = false
            _G.ACTIVE_MODULE = nil
            return
        end

        local sharkUUIDs = selectedUUIDsShark
        local mimicUUID = findMimicUUID(sharkUUIDs)
        local sharkOnlyUUIDs = {}
        for _, uuid in ipairs(sharkUUIDs) do
            if uuid ~= mimicUUID then
                table.insert(sharkOnlyUUIDs, uuid)
            end
        end

        sharkCoroutine = coroutine.create(function()
            while autoSharkEnabled do
                unequipAllEquipped()
                task.wait(0.5)

                for _, uuid in ipairs(sharkUUIDs) do
                    equipPet(uuid)
                    task.wait(0.3)
                end

                local targetQueue = {}
                for _, uuid in ipairs(selectedUUIDsTarget) do
                    table.insert(targetQueue, uuid)
                end

                while #targetQueue > 0 and autoSharkEnabled do
                    local targetUUID = table.remove(targetQueue, 1)
                    local targetReachedMutation = false

                    while not targetReachedMutation and autoSharkEnabled do
                        local mimicCooldown = DataPetModule.getCooldown(mimicUUID)
                        while (mimicCooldown ~= nil and mimicCooldown > 0) and autoSharkEnabled do
                            task.wait(0.5)
                            mimicCooldown = DataPetModule.getCooldown(mimicUUID)
                        end

                        if not autoSharkEnabled then break end

                        for _, uuid in ipairs(sharkOnlyUUIDs) do
                            unequipPet(uuid)
                            task.wait(0.3)
                        end

                        local tumbalUUID = selectedUUIDsTumbal[1]
                        equipPet(targetUUID)
                        task.wait(0.3)
                        equipPet(tumbalUUID)
                        task.wait(0.3)

                        mimicCooldown = DataPetModule.getCooldown(mimicUUID)
                        while (mimicCooldown == nil or mimicCooldown < 8) and autoSharkEnabled do
                            task.wait(0.5)
                            mimicCooldown = DataPetModule.getCooldown(mimicUUID)
                        end

                        if not autoSharkEnabled then break end

                        unequipPet(targetUUID)
                        task.wait(0.3)
                        unequipPet(tumbalUUID)
                        task.wait(0.3)

                        for _, uuid in ipairs(sharkOnlyUUIDs) do
                            equipPet(uuid)
                            task.wait(0.3)
                        end

                        local freshTarget = DataPetModule.findPet({ uuid = targetUUID })
                        if freshTarget and freshTarget.mutation == selectedMutation then
                            targetReachedMutation = true
                            Fluent:Notify({ Title = "AutoShark", Description = "Target " .. freshTarget.name .. " mencapai mutasi " .. selectedMutation, Duration = 3 })
                        end
                    end
                end

                unequipAllEquipped()

                if autoSharkEnabled then
                    autoSharkEnabled = false
                    _G[ENABLE_KEY] = false
                    if autoToggleRef then autoToggleRef:SetValue(false) end
                    _G.ACTIVE_MODULE = nil
                    Fluent:Notify({ Title = "AutoShark", Description = "Semua target selesai, AutoShark dimatikan", Duration = 5 })
                end
                break
            end
        end)
        coroutine.resume(sharkCoroutine)
    end

    -- ============================================================
    -- UPDATE INFO (menggunakan properti Content)
    -- ============================================================
    local function updatePetInfoShark(uuids)
        if not infoParagraphShark then return end
        local contentText
        if uuids and #uuids > 0 then
            local lines = {}
            for i, uuid in ipairs(uuids) do
                local pet = DataPetModule.findPet({ uuid = uuid })
                if pet then
                    table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
                else
                    table.insert(lines, string.format("%d. UUID: %s (tidak ditemukan)", i, uuid))
                end
            end
            contentText = "Tim Shark:\n" .. table.concat(lines, "\n")
        else
            contentText = "Belum ada pet dipilih (Tim Shark)"
        end
        infoParagraphShark.Content = contentText
    end

    local function updatePetInfoTarget(uuids)
        if not infoParagraphTarget then return end
        local contentText
        if uuids and #uuids > 0 then
            local lines = {}
            for i, uuid in ipairs(uuids) do
                local pet = DataPetModule.findPet({ uuid = uuid })
                if pet then
                    table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
                else
                    table.insert(lines, string.format("%d. UUID: %s (tidak ditemukan)", i, uuid))
                end
            end
            contentText = "Target:\n" .. table.concat(lines, "\n")
        else
            contentText = "Belum ada pet dipilih (Target)"
        end
        infoParagraphTarget.Content = contentText
    end

    local function updatePetInfoTumbal(uuids)
        if not infoParagraphTumbal then return end
        local contentText
        if uuids and #uuids > 0 then
            local lines = {}
            for i, uuid in ipairs(uuids) do
                local pet = DataPetModule.findPet({ uuid = uuid })
                if pet then
                    table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
                else
                    table.insert(lines, string.format("%d. UUID: %s (tidak ditemukan)", i, uuid))
                end
            end
            contentText = "Tumbal:\n" .. table.concat(lines, "\n")
        else
            contentText = "Belum ada pet dipilih (Tumbal)"
        end
        infoParagraphTumbal.Content = contentText
    end

    -- ============================================================
    -- REFRESH DROPDOWN
    -- ============================================================
    local function refreshPetDropdownShark()
        if not DataPetModule then return end
        local pets = DataPetModule.findPets({ isFavorite = true })
        if #pets == 0 then
            if dropdownControlShark then dropdownControlShark:SetValues({}) end
            petOptionsShark = {}
            selectedUUIDsShark = {}
            updatePetInfoShark({})
            return
        end
        local labels = {}
        petOptionsShark = {}
        for _, pet in ipairs(pets) do
            local label = string.format("%s %s %.2fkg Lv%d", pet.mutation, pet.name, pet.weight, pet.level)
            table.insert(labels, label)
            petOptionsShark[label] = pet
        end
        if dropdownControlShark then
            dropdownControlShark:SetValues(labels)
            local savedUUIDs = _G[SAVE_KEY_SHARK] or {}
            if #savedUUIDs > 0 then
                local restoredLabels = {}
                for _, uuid in ipairs(savedUUIDs) do
                    for label, pet in pairs(petOptionsShark) do
                        if pet.uuid == uuid then
                            table.insert(restoredLabels, label)
                            break
                        end
                    end
                end
                if #restoredLabels > 0 then
                    dropdownControlShark:SetValue(restoredLabels)
                    selectedUUIDsShark = savedUUIDs
                    updatePetInfoShark(savedUUIDs)
                else
                    dropdownControlShark:SetValue({})
                    selectedUUIDsShark = {}
                    updatePetInfoShark({})
                end
            else
                dropdownControlShark:SetValue({})
                selectedUUIDsShark = {}
                updatePetInfoShark({})
            end
        end
    end

    local function refreshPetDropdownTarget()
        if not DataPetModule then return end
        local pets = DataPetModule.findPets({ isFavorite = false })
        if #pets == 0 then
            if dropdownControlTarget then dropdownControlTarget:SetValues({}) end
            petOptionsTarget = {}
            selectedUUIDsTarget = {}
            updatePetInfoTarget({})
            return
        end
        local labels = {}
        petOptionsTarget = {}
        for _, pet in ipairs(pets) do
            local label = string.format("%s %s %.2fkg Lv%d", pet.mutation, pet.name, pet.weight, pet.level)
            table.insert(labels, label)
            petOptionsTarget[label] = pet
        end
        if dropdownControlTarget then
            dropdownControlTarget:SetValues(labels)
            local savedUUIDs = _G[SAVE_KEY_TARGET] or {}
            if #savedUUIDs > 0 then
                local restoredLabels = {}
                for _, uuid in ipairs(savedUUIDs) do
                    for label, pet in pairs(petOptionsTarget) do
                        if pet.uuid == uuid then
                            table.insert(restoredLabels, label)
                            break
                        end
                    end
                end
                if #restoredLabels > 0 then
                    dropdownControlTarget:SetValue(restoredLabels)
                    selectedUUIDsTarget = savedUUIDs
                    updatePetInfoTarget(savedUUIDs)
                else
                    dropdownControlTarget:SetValue({})
                    selectedUUIDsTarget = {}
                    updatePetInfoTarget({})
                end
            else
                dropdownControlTarget:SetValue({})
                selectedUUIDsTarget = {}
                updatePetInfoTarget({})
            end
        end
    end

    local function refreshPetDropdownTumbal()
        if not DataPetModule then return end
        local pets = DataPetModule.findPets({ isFavorite = false })
        if #pets == 0 then
            if dropdownControlTumbal then dropdownControlTumbal:SetValues({}) end
            petOptionsTumbal = {}
            selectedUUIDsTumbal = {}
            updatePetInfoTumbal({})
            return
        end
        local filtered = {}
        if selectedMutation then
            for _, pet in ipairs(pets) do
                if pet.mutation == selectedMutation then
                    table.insert(filtered, pet)
                end
            end
        else
            filtered = pets
        end
        if #filtered == 0 then
            if dropdownControlTumbal then dropdownControlTumbal:SetValues({}) end
            petOptionsTumbal = {}
            selectedUUIDsTumbal = {}
            updatePetInfoTumbal({})
            Fluent:Notify({ Title = "Info", Description = "Tidak ada pet non-favorit dengan mutasi " .. (selectedMutation or "terpilih"), Duration = 3 })
            return
        end
        local labels = {}
        petOptionsTumbal = {}
        for _, pet in ipairs(filtered) do
            local label = string.format("%s %s %.2fkg Lv%d", pet.mutation, pet.name, pet.weight, pet.level)
            table.insert(labels, label)
            petOptionsTumbal[label] = pet
        end
        if dropdownControlTumbal then
            dropdownControlTumbal:SetValues(labels)
            local savedUUIDs = _G[SAVE_KEY_TUMBAL] or {}
            if #savedUUIDs > 0 then
                local restoredLabels = {}
                for _, uuid in ipairs(savedUUIDs) do
                    for label, pet in pairs(petOptionsTumbal) do
                        if pet.uuid == uuid then
                            table.insert(restoredLabels, label)
                            break
                        end
                    end
                end
                if #restoredLabels > 0 then
                    dropdownControlTumbal:SetValue(restoredLabels)
                    selectedUUIDsTumbal = savedUUIDs
                    updatePetInfoTumbal(savedUUIDs)
                else
                    dropdownControlTumbal:SetValue({})
                    selectedUUIDsTumbal = {}
                    updatePetInfoTumbal({})
                end
            else
                dropdownControlTumbal:SetValue({})
                selectedUUIDsTumbal = {}
                updatePetInfoTumbal({})
            end
        end
    end

    local function refreshMutationDropdown()
        if not DataPetModule then return end
        local allPets = DataPetModule.getAllPets()
        local mutationSet = {}
        for _, pet in pairs(allPets) do
            local petData = pet.PetData or {}
            local rawMut = petData.MutationType or "Normal"
            local mutationName = DataPetModule.getAutoMutationName(rawMut)
            mutationSet[mutationName] = true
        end
        mutationSet["Normal"] = true
        local values = {}
        mutationOptions = {}
        for mutName, _ in pairs(mutationSet) do
            table.insert(values, mutName)
            mutationOptions[mutName] = mutName
        end
        table.sort(values)
        if dropdownControlMutation then
            dropdownControlMutation:SetValues(values)
            local saved = _G[SAVE_KEY_MUTATION]
            if saved and mutationOptions[saved] then
                dropdownControlMutation:SetValue(saved)
                selectedMutation = saved
            else
                if #values > 0 then
                    dropdownControlMutation:SetValue(values[1])
                    selectedMutation = values[1]
                    _G[SAVE_KEY_MUTATION] = values[1]
                end
            end
            refreshPetDropdownTumbal()
        end
    end

    -- ============================================================
    -- UI COMPONENTS
    -- ============================================================
    local sectionShark = AutoSharkTab:AddSection("Pilih Tim Auto Shark (Favorit)")
    infoParagraphShark = sectionShark:AddParagraph({ Title = "Tim Shark", Content = "Belum ada pet dipilih (Tim Shark)" })
    dropdownControlShark = sectionShark:AddDropdown("PetDropdownShark", {
        Title = "Daftar Pet Favorite (Min 2: 1 Shark + 1 Mimic)",
        Values = {},
        Multi = true,
        Default = {},
        Callback = function(selected)
            local uuids = {}
            if type(selected) == "table" then
                for label, isSelected in pairs(selected) do
                    if isSelected and petOptionsShark[label] then
                        table.insert(uuids, petOptionsShark[label].uuid)
                    end
                end
            end
            selectedUUIDsShark = uuids
            _G[SAVE_KEY_SHARK] = uuids
            updatePetInfoShark(uuids)
            print("[AutoShark] SHARK SELECTED:", #uuids)
        end
    })
    sectionShark:AddButton({ Title = "↻ Refresh Daftar Shark", Callback = function() refreshPetDropdownShark() end })

    local sectionTarget = AutoSharkTab:AddSection("Pilih Target Pet (Non-Favorit)")
    infoParagraphTarget = sectionTarget:AddParagraph({ Title = "Target", Content = "Belum ada pet dipilih (Target)" })
    dropdownControlTarget = sectionTarget:AddDropdown("PetDropdownTarget", {
        Title = "Daftar Pet Non-Favorit",
        Values = {},
        Multi = true,
        Default = {},
        Callback = function(selected)
            local uuids = {}
            if type(selected) == "table" then
                for label, isSelected in pairs(selected) do
                    if isSelected and petOptionsTarget[label] then
                        table.insert(uuids, petOptionsTarget[label].uuid)
                    end
                end
            end
            selectedUUIDsTarget = uuids
            _G[SAVE_KEY_TARGET] = uuids
            updatePetInfoTarget(uuids)
            print("[AutoShark] TARGET SELECTED:", #uuids)
        end
    })
    sectionTarget:AddButton({ Title = "↻ Refresh Daftar Target", Callback = function() refreshPetDropdownTarget() end })

    local sectionTumbal = AutoSharkTab:AddSection("Pilih Tumbal Pet (Non-Favorit dengan Mutasi Target)")
    infoParagraphTumbal = sectionTumbal:AddParagraph({ Title = "Tumbal", Content = "Belum ada pet dipilih (Tumbal)" })
    dropdownControlTumbal = sectionTumbal:AddDropdown("PetDropdownTumbal", {
        Title = "Daftar Pet Tumbal (filter by mutasi)",
        Values = {},
        Multi = true,
        Default = {},
        Callback = function(selected)
            local uuids = {}
            if type(selected) == "table" then
                for label, isSelected in pairs(selected) do
                    if isSelected and petOptionsTumbal[label] then
                        table.insert(uuids, petOptionsTumbal[label].uuid)
                    end
                end
            end
            selectedUUIDsTumbal = uuids
            _G[SAVE_KEY_TUMBAL] = uuids
            updatePetInfoTumbal(uuids)
            print("[AutoShark] TUMBAL SELECTED:", #uuids)
        end
    })
    sectionTumbal:AddButton({ Title = "↻ Refresh Daftar Tumbal", Callback = function() refreshPetDropdownTumbal() end })

    local sectionMutation = AutoSharkTab:AddSection("Pilih Target Mutasi")
    dropdownControlMutation = sectionMutation:AddDropdown("MutationDropdown", {
        Title = "Daftar Mutasi",
        Values = {},
        Multi = false,
        Default = "",
        Callback = function(selected)
            if selected and mutationOptions[selected] then
                selectedMutation = selected
                _G[SAVE_KEY_MUTATION] = selected
                refreshPetDropdownTumbal()
            else
                selectedMutation = nil
                _G[SAVE_KEY_MUTATION] = nil
                refreshPetDropdownTumbal()
            end
        end
    })
    sectionMutation:AddButton({ Title = "↻ Refresh Daftar Mutasi", Callback = function() refreshMutationDropdown() end })

    local controlSectionShark = AutoSharkTab:AddSection("Pengaturan AutoShark")
    autoToggleRef = controlSectionShark:AddToggle("AutoSharkToggle", {
        Title = "Auto Shark",
        Description = "Aktifkan untuk menjalankan Auto Shark",
        Default = _G[ENABLE_KEY] or false,
        Callback = function(value)
            if value then
                if _G.ACTIVE_MODULE == "Leveling" and _G.LEVELING_TOGGLE then
                    _G.LEVELING_TOGGLE:SetValue(false)
                end
                _G.ACTIVE_MODULE = "AutoShark"
                _G[ENABLE_KEY] = true
                autoSharkEnabled = true
                Fluent:Notify({ Title = "Auto Shark", Description = "Auto Shark diaktifkan!", Duration = 3 })
                startAutoShark()
            else
                _G[ENABLE_KEY] = false
                autoSharkEnabled = false
                if _G.ACTIVE_MODULE == "AutoShark" then
                    _G.ACTIVE_MODULE = nil
                end
                Fluent:Notify({ Title = "Auto Shark", Description = "Auto Shark dinonaktifkan", Duration = 3 })
                unequipAllEquipped()
            end
        end
    })
    _G.AUTO_SHARK_TOGGLE = autoToggleRef

    -- ============================================================
    -- LOAD AWAL
    -- ============================================================
    task.wait(0.5)
    refreshPetDropdownShark()
    refreshPetDropdownTarget()
    refreshMutationDropdown()
    refreshPetDropdownTumbal()
    if _G[ENABLE_KEY] ~= nil then
        autoSharkEnabled = _G[ENABLE_KEY]
        autoToggleRef:SetValue(autoSharkEnabled)
    end

    print("[AutoShark.lua] Tab AutoShark siap.")
end

return AutoShark
