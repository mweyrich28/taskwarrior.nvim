local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local taskwarrior = require("taskwarrior_nvim.taskwarrior")
local M = {}

M.project_picker = function()
    local function fetch_projects(callback)
        taskwarrior.cmd({ "_unique", "project" }, {
            on_exit = function(j, code, signal)
                local results = j:result()
                table.insert(results, 1, "[New Project]")
                vim.schedule(function()
                    callback(results)
                end)
            end,
        }):start()
    end

    local function fetch_tags(callback)
        taskwarrior.cmd({ "_unique", "tags" }, {
            on_exit = function(j, code, signal)
                local results = j:result()
                table.insert(results, 1, "[New Tag]")
                vim.schedule(function()
                    callback(results)
                end)
            end,
        }):start()
    end

    local function tag_picker(selected_project, callback)
        fetch_tags(function(tags)
            pickers.new({}, {
                prompt_title = "Select or Create Tags (multi-select with Tab)",
                finder = finders.new_table({
                    results = tags,
                    entry_maker = function(entry)
                        return {
                            value = entry,
                            display = entry,
                            ordinal = entry,
                        }
                    end,
                }),
                sorter = conf.generic_sorter({}),
                attach_mappings = function(prompt_bufnr, map)
                    local selected_tags = {}
                    
                    local function toggle_tag(tag_name)
                        if selected_tags[tag_name] then
                            selected_tags[tag_name] = nil
                            vim.notify("Removed tag: " .. tag_name, vim.log.levels.INFO)
                        else
                            selected_tags[tag_name] = true
                            vim.notify("Added tag: " .. tag_name, vim.log.levels.INFO)
                        end
                    end
                    
                    -- Multi-select with Tab
                    map("i", "<Tab>", function()
                        local selection = actions_state.get_selected_entry()
                        
                        if not selection then 
                            return 
                        end
                        
                        local value = selection.value
                        
                        if value == "[New Tag]" then
                            vim.schedule(function()
                                local new_tag = vim.fn.input("New tag name: ")
                                if new_tag ~= "" then
                                    toggle_tag(new_tag)
                                end
                            end)
                        else
                            toggle_tag(value)
                        end
                    end)
                    
                    map("n", "<Tab>", function()
                        local selection = actions_state.get_selected_entry()
                        
                        if not selection then 
                            return 
                        end
                        
                        local value = selection.value
                        
                        if value == "[New Tag]" then
                            vim.schedule(function()
                                local new_tag = vim.fn.input("New tag name: ")
                                if new_tag ~= "" then
                                    toggle_tag(new_tag)
                                end
                            end)
                        else
                            toggle_tag(value)
                        end
                    end)

                    actions.select_default:replace(function()
                        -- If no tags selected yet, add the currently highlighted tag
                        local tag_count = 0
                        for _ in pairs(selected_tags) do
                            tag_count = tag_count + 1
                        end
                        
                        if tag_count == 0 then
                            local selection = actions_state.get_selected_entry()
                            if selection and selection.value ~= "[New Tag]" then
                                selected_tags[selection.value] = true
                            elseif selection and selection.value == "[New Tag]" then
                                vim.schedule(function()
                                    local new_tag = vim.fn.input("New tag name: ")
                                    if new_tag ~= "" then
                                        selected_tags[new_tag] = true
                                    end
                                    
                                    actions.close(prompt_bufnr)
                                    -- Convert selected_tags table to array
                                    local tag_list = {}
                                    for tag, _ in pairs(selected_tags) do
                                        table.insert(tag_list, tag)
                                    end
                                    callback(selected_project, tag_list)
                                end)
                                return -- Exit early for new tag creation
                            end
                        end
                        
                        actions.close(prompt_bufnr)
                        -- Convert selected_tags table to array
                        local tag_list = {}
                        for tag, _ in pairs(selected_tags) do
                            table.insert(tag_list, tag)
                        end
                        callback(selected_project, tag_list)
                    end)
                    
                    return true
                end,
            }):find()
        end)
    end

    local function create_task(project_name, selected_tags)
        vim.schedule(function()
            local description = vim.fn.input("Task description: ")
            if description == "" then
                vim.schedule(function()
                    vim.notify("Task description cannot be empty", vim.log.levels.WARN)
                end)
                return
            end
            
            local cmd_parts = { description, "project:" .. project_name }
            for _, tag in ipairs(selected_tags) do
                table.insert(cmd_parts, "+" .. tag)
            end
            local cmd_string = table.concat(cmd_parts, " ")
            
            -- Use the same pattern as your working <C-a> function
            taskwarrior.cmd({ "add", unpack(vim.split(cmd_string, " ")) }, {
                on_exit = function(j, code, signal)
                    vim.schedule(function()
                        vim.notify(table.concat(j:result(), " "), vim.log.levels.INFO)
                    end)
                end,
            }):start()
        end)
    end

    fetch_projects(function(projects)
        pickers.new({}, {
            prompt_title = "Select or Create Project",
            finder = finders.new_table({
                results = projects,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry,
                        ordinal = entry,
                    }
                end,
            }),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local selection = actions_state.get_selected_entry().value
                    
                    local function proceed_with_project(project_name)
                        -- Open tag picker after project selection
                        tag_picker(project_name, create_task)
                    end
                    
                    if selection == "[New Project]" then
                        vim.schedule(function()
                            local new_project = vim.fn.input("New project name: ")
                            if new_project ~= "" then
                                proceed_with_project(new_project)
                            else
                                vim.schedule(function()
                                    vim.notify("Project name cannot be empty", vim.log.levels.WARN)
                                end)
                            end
                        end)
                    else
                        proceed_with_project(selection)
                    end
                end)
                return true
            end,
        }):find()
    end)
end

return M
