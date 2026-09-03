-- ============================================================
-- AutoShark.lua - Modul Tab AutoShark
-- ============================================================

local AutoShark = {}

function AutoShark.Setup(Window, DataPetModule, Fluent)
    local AutoSharkTab = Window:AddTab({ Title = "AutoShark" })

    -- Tim Auto Shark (Favorite)
    local petOptionsShark = {}
    local selectedPetsShark = {}
    local selectedUUIDsShark = {}
    local dropdownControlShark = nil
    local infoParagraphShark = nil

    -- Target Pet (Non-Favorit)
    local petOptionsSharkTarget = {}
    local selectedPetsSharkTarget = {}
    local selectedUUIDsSharkTarget = {}
    local dropdownControlSharkTarget = nil
    local infoParagraphSharkTarget = nil

    -- Target Mutasi (single select)
    local mutationOptions = {}
    local selectedMutation = nil
    local dropdownControlMutation = nil

    local SAVE_KEY_SHARK = "SelectedPetUUIDs_Shark"
    local SAVE_KEY_SHARK_TARGET = "SelectedPetUUIDs_SharkTarget"
    local SAVE_KEY_MUTATION = "SelectedMutation"
    local SHARK_ENABLE_KEY = "AutoSharkEnabled"

    -- Update info shark
    local function updatePetInfoShark(pets)
        if not infoParagraphShark then return end
        local contentText
        if pets and #pets > 0 then
            local lines = {}
            for i, pet in ipairs(pets) do
                table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
            end
            contentText = "Tim Auto Shark:\n" .. table.concat(lines, "\n")
        else
            contentText = "Belum ada pet dipilih (Tim Auto Shark)"
        end
        if infoParagraphShark.SetContent then
            infoParagraphShark:SetContent(contentText)
        else
            infoParagraphShark.Content = contentText
        end
    end

    -- Update info target shark
    local function updatePetInfoSharkTarget(pets)
        if not infoParagraphSharkTarget then return end
        local contentText
        if pets and #pets > 0 then
            local lines = {}
            for i, pet in ipairs(pets) do
                table.insert(lines, string.format("%d. %s %s %.2fkg Lv%d", i, pet.mutation, pet.name, pet.weight, pet.level))
            end
            contentText = "Target Shark:\n" .. table.concat(lines, "\n")
        else
            contentText = "Belum ada pet dipilih (Target Shark)"
        end
        if infoParagraphSharkTarget.SetContent then
            infoParagraphSharkTarget:SetContent(contentText)
        else
            infoParagraphSharkTarget.Content = contentText
        end
    end

    -- Refresh shark favorite
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

    -- Refresh shark target (non-favorit)
    local function refreshPetDropdownSharkTarget()
        if not DataPetModule then
            Fluent:Notify({ Title = "Error", Description = "DataPetModule tidak tersedia", Duration = 5 })
            return
        end
        local pets = DataPetModule.findPets({ isFavorite = false })
        if #pets == 0 then
            Fluent:Notify({ Title = "Info", Description = "Tidak ada pet non-favorit ditemukan", Duration = 5 })
            if dropdownControlSharkTarget then dropdownControlSharkTarget:SetValues({}) end
            petOptionsSharkTarget = {}; selectedPetsSharkTarget = {}; selectedUUIDsSharkTarget = {}
            updatePetInfoSharkTarget({})
            return
        end
        local values = {}
        petOptionsSharkTarget = {}
        for _, pet in ipairs(pets) do
            local label = string.format("%s %s %.2fkg Lv%d [%s]", pet.mutation, pet.name, pet.weight, pet.level, string.sub(pet.uuid, 1, 7))
            table.insert(values, label)
            petOptionsSharkTarget[label] = pet
        end
        if dropdownControlSharkTarget then
            dropdownControlSharkTarget:SetValues(values)
            local savedUUIDs = _G[SAVE_KEY_SHARK_TARGET]
            local restoredLabels = {}
            if savedUUIDs and type(savedUUIDs) == "table" then
                for _, uuid in ipairs(savedUUIDs) do
                    for label, pet in pairs(petOptionsSharkTarget) do
                        if pet.uuid == uuid then
                            table.insert(restoredLabels, label)
                            break
                        end
                    end
                end
            end
            if #restoredLabels > 0 then
                dropdownControlSharkTarget:SetValue(restoredLabels)
                local selected = {}
                for _, label in ipairs(restoredLabels) do
                    if petOptionsSharkTarget[label] then table.insert(selected, petOptionsSharkTarget[label]) end
                end
                selectedPetsSharkTarget = selected
                selectedUUIDsSharkTarget = {}
                for _, pet in ipairs(selected) do table.insert(selectedUUIDsSharkTarget, pet.uuid) end
                updatePetInfoSharkTarget(selected)
            else
                dropdownControlSharkTarget:SetValue({})
                selectedPetsSharkTarget = {}; selectedUUIDsSharkTarget = {}
                updatePetInfoSharkTarget({})
            end
        end
    end

    -- Refresh mutasi (unique dari semua pet)
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
        end
    end

    -- UI Shark
    local sectionShark = AutoSharkTab:AddSection("Pilih Tim Auto Shark (Favorit)")
    dropdownControlShark = sectionShark:AddDropdown("PetDropdownShark", {
        Title = "Daftar Pet Favorite",
        Values = {},
        Multi = true,
        Default = {},
        Callback = function(selectedLabels)
            if selectedLabels and #selectedLabels > 0 then
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
            else
                selectedPetsShark = {}; selectedUUIDsShark = {}
                _G[SAVE_KEY_SHARK] = {}
                updatePetInfoShark({})
            end
        end
    })
    sectionShark:AddButton({ Title = "↻ Refresh Daftar Shark", Callback = function() refreshPetDropdownShark() end })
    infoParagraphShark = sectionShark:AddParagraph({ Title = "Tim Auto Shark", Content = "Belum ada pet dipilih (Tim Auto Shark)" })

    -- UI Target Shark
    local sectionSharkTarget = AutoSharkTab:AddSection("Pilih Target Pet (Non-Favorit)")
    dropdownControlSharkTarget = sectionSharkTarget:AddDropdown("PetDropdownSharkTarget", {
        Title = "Daftar Pet Non-Favorit",
        Values = {},
        Multi = true,
        Default = {},
        Callback = function(selectedLabels)
            if selectedLabels and #selectedLabels > 0 then
                local selected = {}; local uuids = {}
                for _, label in ipairs(selectedLabels) do
                    if petOptionsSharkTarget[label] then
                        table.insert(selected, petOptionsSharkTarget[label])
                        table.insert(uuids, petOptionsSharkTarget[label].uuid)
                    end
                end
                selectedPetsSharkTarget = selected; selectedUUIDsSharkTarget = uuids
                _G[SAVE_KEY_SHARK_TARGET] = uuids
                updatePetInfoSharkTarget(selected)
            else
                selectedPetsSharkTarget = {}; selectedUUIDsSharkTarget = {}
                _G[SAVE_KEY_SHARK_TARGET] = {}
                updatePetInfoSharkTarget({})
            end
        end
    })
    sectionSharkTarget:AddButton({ Title = "↻ Refresh Daftar Target", Callback = function() refreshPetDropdownSharkTarget() end })
    infoParagraphSharkTarget = sectionSharkTarget:AddParagraph({ Title = "Target Shark", Content = "Belum ada pet dipilih (Target Shark)" })

    -- UI Mutasi
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
                print("[AutoShark] Mutasi dipilih:", selected)
            else
                selectedMutation = nil
                _G[SAVE_KEY_MUTATION] = nil
            end
        end
    })
    sectionMutation:AddButton({ Title = "↻ Refresh Daftar Mutasi", Callback = function() refreshMutationDropdown() end })

    -- Pengaturan AutoShark
    local controlSectionShark = AutoSharkTab:AddSection("Pengaturan AutoShark")
    local autoSharkToggle = controlSectionShark:AddToggle("AutoSharkToggle", {
        Title = "Auto Shark",
        Description = "Aktifkan untuk menjalankan Auto Shark",
        Default = _G[SHARK_ENABLE_KEY] or false,
        Callback = function(value)
            if value then
                if _G.ACTIVE_MODULE == "Leveling" and _G.LEVELING_TOGGLE then
                    _G.LEVELING_TOGGLE:SetValue(false)
                end
                _G.ACTIVE_MODULE = "AutoShark"
                _G[SHARK_ENABLE_KEY] = true
                Fluent:Notify({ Title = "Auto Shark", Description = "Auto Shark diaktifkan!", Duration = 3 })
            else
                _G[SHARK_ENABLE_KEY] = false
                if _G.ACTIVE_MODULE == "AutoShark" then
                    _G.ACTIVE_MODULE = nil
                end
                Fluent:Notify({ Title = "Auto Shark", Description = "Auto Shark dinonaktifkan", Duration = 3 })
            end
        end
    })
    _G.AUTO_SHARK_TOGGLE = autoSharkToggle

    -- Load awal
    task.wait(0.5)
    refreshPetDropdownShark()
    refreshPetDropdownSharkTarget()
    refreshMutationDropdown()
    if _G[SHARK_ENABLE_KEY] ~= nil then
        autoSharkToggle:SetValue(_G[SHARK_ENABLE_KEY])
    end

    print("[AutoShark.lua] Tab AutoShark siap.")
    return AutoSharkTab
end

return AutoShark
