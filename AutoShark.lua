-- ============================================================
-- AutoShark.lua - Modul Tab AutoShark (FIXED - tanpa GetValue)
-- ============================================================

local AutoShark = {}

function AutoShark.Setup(Window, DataPetModule, Fluent)
    local AutoSharkTab = Window:AddTab({ Title = "AutoShark" })

    -- ============================================================
    -- VARIABEL
    -- ============================================================
    local petOptionsShark = {}
    local selectedPetsShark = {}
    local selectedUUIDsShark = {}
    local dropdownControlShark = nil
    local infoParagraphShark = nil

    local petOptionsTarget = {}
    local selectedPetsTarget = {}
    local selectedUUIDsTarget = {}
    local dropdownControlTarget = nil
    local infoParagraphTarget = nil

    local petOptionsTumbal = {}
    local selectedPetsTumbal = {}
    local selectedUUIDsTumbal = {}
    local dropdownControlTumbal = nil
    local infoParagraphTumbal = nil

    local mutationOptions = {}
    local selectedMutation = nil
    local dropdownControlMutation = nil

    local autoSharkEnabled = false
    local autoToggleRef = nil
    local sharkCoroutine = nil

    local SAVE_KEY_SHARK = "SelectedPetUUIDs_Shark"
    local SAVE_KEY_TARGET = "SelectedPetUUIDs_SharkTarget"
    local SAVE_KEY_TUMBAL = "SelectedPetUUIDs_SharkTumbal"
    local SAVE_KEY_MUTATION = "SelectedMutation_Shark"
    local ENABLE_KEY = "AutoSharkEnabled"

    local GARDEN_CFRAME = CFrame.new(-16.000007629395, 4, -116.50244903564, 1, 0, 0, 0, 1, 0, 0, 0, 1)

    -- ============================================================
    -- FUNGSI EQUIP / UNEQUIP
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
        print("=== VALIDASI AUTOSHARK ===")
        print("Tim Shark (selectedPetsShark):", #selectedPetsShark)
        print("Target (selectedPetsTarget):", #selectedPetsTarget)
        print("Tumbal (selectedPetsTumbal):", #selectedPetsTumbal)
        print("Mutasi Terpilih:", selectedMutation or "None")

        if #selectedPetsShark == 0 then
            Fluent:Notify({ Title = "Error", Description = "Pilih tim shark terlebih dahulu! (min 2 pet favorit, 1 di antaranya Mimic)", Duration = 5 })
            return false
        end
        if #selectedPetsTarget == 0 then
            Fluent:Notify({ Title = "Error", Description = "Pilih target terlebih dahulu!", Duration = 5 })
            return false
        end
        if #selectedPetsTumbal == 0 then
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
                for _, pet in ipairs(selectedPetsTarget) do
                    table.insert(targetQueue, pet)
                end

                while #targetQueue > 0 and autoSharkEnabled do
                    local currentTarget = table.remove(targetQueue, 1)
                    local targetUUID = currentTarget.uuid
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
    -- UPDATE INFO
    -- ============================================================
    local function updatePetInfoShark(pets)
        if not infoParagraphShark then return end
        local contentText
        if pets and #pets > 0 then
            local lines = {}
            for i, pet in ipairs(pets) do
                table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
            end
            contentText = "Tim Shark:\n" .. table.concat(lines, "\n")
        else
            contentText = "Belum ada pet dipilih (Tim Shark)"
        end
        if infoParagraphShark.SetContent then
            infoParagraphShark:SetContent(contentText)
        else
            infoParagraphShark.Content = contentText
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
            contentText = "Target:\n" .. table.concat(lines, "\n")
        else
            contentText = "Belum ada pet dipilih (Target)"
        end
        if infoParagraphTarget.SetContent then
            infoParagraphTarget:SetContent(contentText)
        else
            infoParagraphTarget.Content = contentText
        end
    end

    local function updatePetInfoTumbal(pets)
        if not infoParagraphTumbal then return end
        local contentText
        if pets and #pets > 0 then
            local lines = {}
            for i, pet in ipairs(pets) do
                table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
            end
            contentText = "Tumbal:\n" .. table.concat(lines, "\n")
        else
            contentText = "Belum ada pet dipilih (Tumbal)"
        end
        if infoParagraphTumbal.SetContent then
            infoParagraphTumbal:SetContent(contentText)
        else
            infoParagraphTumbal.Content = contentText
        end
    end

    -- ============================================================
    -- REFRESH DROPDOWN
    -- ============================================================
    local function refreshPetDropdownShark()
        if not DataPetModule then
            Fluent:Notify({ Title = "Error", Description = "DataPetModule tidak tersedia", Duration = 5 })
            return
        end
        local pets = DataPetModule.findPets({ isFavorite = true })
        if #pets == 0 then
            Fluent:Notify({ Title = "Info", Description = "Tidak ada pet favorite ditemukan", Duration = 5 })
            if dropdownControlShark then dropdownControlShark:SetValues({}) end
            petOptionsShark = {}; selectedPetsShark = {}; selectedUUIDsShark = {}
            updatePetInfoShark({})
            return
        end
        local values = {}
        petOptionsShark = {}
        for _, pet in ipairs(pets) do
            local label = string.format("%s %s %.2fkg Lv%d [%s]", pet.mutation, pet.name, pet.weight, pet.level, string.sub(pet.uuid, 1, 7))
            table.insert(values, label)
            petOptionsShark[label] = pet
        end
        if dropdownControlShark then
            dropdownControlShark:SetValues(values)
            local savedUUIDs = _G[SAVE_KEY_SHARK]
            local restoredLabels = {}
            if savedUUIDs and type(savedUUIDs) == "table" then
                for _, uuid in ipairs(savedUUIDs) do
                    for label, pet in pairs(petOptionsShark) do
                        if pet.uuid == uuid then
                            table.insert(restoredLabels, label)
                            break
                        end
                    end
                end
            end
            if #restoredLabels > 0 then
                dropdownControlShark:SetValue(restoredLabels)
                local selected = {}
                for _, label in ipairs(restoredLabels) do
                    if petOptionsShark[label] then table.insert(selected, petOptionsShark[label]) end
                end
                selectedPetsShark = selected
                selectedUUIDsShark = {}
                for _, pet in ipairs(selected) do table.insert(selectedUUIDsShark, pet.uuid) end
                updatePetInfoShark(selected)
            else
                dropdownControlShark:SetValue({})
                selectedPetsShark = {}; selectedUUIDsShark = {}
                updatePetInfoShark({})
            end
        end
    end

    local function refreshPetDropdownTarget()
        if not DataPetModule then
            Fluent:Notify({ Title = "Error", Description = "DataPetModule tidak tersedia", Duration = 5 })
            return
        end
        local pets = DataPetModule.findPets({ isFavorite = false })
        if #pets == 0 then
            Fluent:Notify({ Title = "Info", Description = "Tidak ada pet non-favorit ditemukan", Duration = 5 })
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

    local function refreshPetDropdownTumbal()
        if not DataPetModule then
            Fluent:Notify({ Title = "Error", Description = "DataPetModule tidak tersedia", Duration = 5 })
            return
        end
        local pets = DataPetModule.findPets({ isFavorite = false })
        if #pets == 0 then
            Fluent:Notify({ Title = "Info", Description = "Tidak ada pet non-favorit ditemukan", Duration = 5 })
            if dropdownControlTumbal then dropdownControlTumbal:SetValues({}) end
            petOptionsTumbal = {}; selectedPetsTumbal = {}; selectedUUIDsTumbal = {}
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
            Fluent:Notify({ Title = "Info", Description = "Tidak ada pet dengan mutasi " .. (selectedMutation or "terpilih"), Duration = 5 })
            if dropdownControlTumbal then dropdownControlTumbal:SetValues({}) end
            petOptionsTumbal = {}; selectedPetsTumbal = {}; selectedUUIDsTumbal = {}
            updatePetInfoTumbal({})
            return
        end

        local values = {}
        petOptionsTumbal = {}
        for _, pet in ipairs(filtered) do
            local label = string.format("%s %s %.2fkg Lv%d [%s]", pet.mutation, pet.name, pet.weight, pet.level, string.sub(pet.uuid, 1, 7))
            table.insert(values, label)
            petOptionsTumbal[label] = pet
        end
        if dropdownControlTumbal then
            dropdownControlTumbal:SetValues(values)
            local savedUUIDs = _G[SAVE_KEY_TUMBAL]
            local restoredLabels = {}
            if savedUUIDs and type(savedUUIDs) == "table" then
                for _, uuid in ipairs(savedUUIDs) do
                    for label, pet in pairs(petOptionsTumbal) do
                        if pet.uuid == uuid then
                            table.insert(restoredLabels, label)
                            break
                        end
                    end
                end
            end
            if #restoredLabels > 0 then
                dropdownControlTumbal:SetValue(restoredLabels)
                local selected = {}
                for _, label in ipairs(restoredLabels) do
                    if petOptionsTumbal[label] then table.insert(selected, petOptionsTumbal[label]) end
                end
                selectedPetsTumbal = selected
                selectedUUIDsTumbal = {}
                for _, pet in ipairs(selected) do table.insert(selectedUUIDsTumbal, pet.uuid) end
                updatePetInfoTumbal(selected)
            else
                dropdownControlTumbal:SetValue({})
                selectedPetsTumbal = {}; selectedUUIDsTumbal = {}
                updatePetInfoTumbal({})
            end
        end
    end

    local function refreshMutationDropdown()
        if not DataPetModule then
            Fluent:Notify({ Title = "Error", Description = "DataPetModule tidak tersedia", Duration = 5 })
            return
        end
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
    -- UI COMPONENTS - GUNAKAN CALLBACK BIASA DENGAN PARAMETER
    -- ============================================================
    local sectionShark = AutoSharkTab:AddSection("Pilih Tim Auto Shark (Favorit)")
    dropdownControlShark = sectionShark:AddDropdown("PetDropdownShark", {
        Title = "Daftar Pet Favorite (Min 2: 1 Shark + 1 Mimic)",
        Values = {},
        Multi = true,
        Default = {},
        Callback = function(selectedLabels)
            print("[AutoShark] SHARK CALLBACK RECEIVED:", selectedLabels)
            if selectedLabels and type(selectedLabels) == "table" and #selectedLabels > 0 then
                local selected = {}; local uuids = {}
                for _, label in ipairs(selectedLabels) do
                    if petOptionsShark[label] then
                        table.insert(selected, petOptionsShark[label])
                        table.insert(uuids, petOptionsShark[label].uuid)
                    end
                end
                selectedPetsShark = selected; selectedUUIDsShark = uuids
                _G[SAVE_KEY_SHARK] = uuids
                updatePetInfoShark(selected)
                print("[AutoShark] SHARK COUNT:", #selectedPetsShark)
            else
                selectedPetsShark = {}; selectedUUIDsShark = {}
                _G[SAVE_KEY_SHARK] = {}
                updatePetInfoShark({})
                print("[AutoShark] SHARK COUNT: 0 (cleared)")
            end
        end
    })
    sectionShark:AddButton({ Title = "↻ Refresh Daftar Shark", Callback = function() refreshPetDropdownShark() end })
    infoParagraphShark = sectionShark:AddParagraph({ Title = "Tim Shark", Content = "Belum ada pet dipilih (Tim Shark)" })

    local sectionTarget = AutoSharkTab:AddSection("Pilih Target Pet (Non-Favorit)")
    dropdownControlTarget = sectionTarget:AddDropdown("PetDropdownTarget", {
        Title = "Daftar Pet Non-Favorit",
        Values = {},
        Multi = true,
        Default = {},
        Callback = function(selectedLabels)
            print("[AutoShark] TARGET CALLBACK RECEIVED:", selectedLabels)
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
                print("[AutoShark] TARGET COUNT:", #selectedPetsTarget)
            else
                selectedPetsTarget = {}; selectedUUIDsTarget = {}
                _G[SAVE_KEY_TARGET] = {}
                updatePetInfoTarget({})
                print("[AutoShark] TARGET COUNT: 0 (cleared)")
            end
        end
    })
    sectionTarget:AddButton({ Title = "↻ Refresh Daftar Target", Callback = function() refreshPetDropdownTarget() end })
    infoParagraphTarget = sectionTarget:AddParagraph({ Title = "Target", Content = "Belum ada pet dipilih (Target)" })

    local sectionTumbal = AutoSharkTab:AddSection("Pilih Tumbal Pet (Non-Favorit dengan Mutasi Target)")
    dropdownControlTumbal = sectionTumbal:AddDropdown("PetDropdownTumbal", {
        Title = "Daftar Pet Tumbal (filter by mutasi)",
        Values = {},
        Multi = true,
        Default = {},
        Callback = function(selectedLabels)
            print("[AutoShark] TUMBAL CALLBACK RECEIVED:", selectedLabels)
            if selectedLabels and type(selectedLabels) == "table" and #selectedLabels > 0 then
                local selected = {}; local uuids = {}
                for _, label in ipairs(selectedLabels) do
                    if petOptionsTumbal[label] then
                        table.insert(selected, petOptionsTumbal[label])
                        table.insert(uuids, petOptionsTumbal[label].uuid)
                    end
                end
                selectedPetsTumbal = selected; selectedUUIDsTumbal = uuids
                _G[SAVE_KEY_TUMBAL] = uuids
                updatePetInfoTumbal(selected)
                print("[AutoShark] TUMBAL COUNT:", #selectedPetsTumbal)
            else
                selectedPetsTumbal = {}; selectedUUIDsTumbal = {}
                _G[SAVE_KEY_TUMBAL] = {}
                updatePetInfoTumbal({})
                print("[AutoShark] TUMBAL COUNT: 0 (cleared)")
            end
        end
    })
    sectionTumbal:AddButton({ Title = "↻ Refresh Daftar Tumbal", Callback = function() refreshPetDropdownTumbal() end })
    infoParagraphTumbal = sectionTumbal:AddParagraph({ Title = "Tumbal", Content = "Belum ada pet dipilih (Tumbal)" })

    local sectionMutation = AutoSharkTab:AddSection("Pilih Target Mutasi")
    dropdownControlMutation = sectionMutation:AddDropdown("MutationDropdown", {
        Title = "Daftar Mutasi",
        Values = {},
        Multi = false,
        Default = "",
        Callback = function(selected)
            print("[AutoShark] MUTASI CALLBACK RECEIVED:", selected)
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
            print("[AutoShark] TOGGLE:", value)
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

    print("[AutoShark.lua] Tab AutoShark siap dengan logika lengkap.")
end

return AutoShark
