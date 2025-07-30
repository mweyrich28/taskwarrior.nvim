local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local taskwarrior = require("taskwarrior_nvim.taskwarrior")

local M = {}

M.project_picker = function()
    local function fetch_projects(callback)
        -- Taskwarrior supports listing unique projects like this:
        taskwarrior.cmd({ "_unique", "project" }, {
            on_exit = function(j, _code, _signal)
                local results = j:result()
                -- Add a fake entry to allow creating new projects
                table.insert(results, 1, "[New Project]")
                vim.schedule(function()
                    callback(results)
                end)
            end,
        }):start()
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
                        vim.schedule(function()
                            local description = vim.fn.input("Task description: ")
                            if description == "" then
                                vim.schedule(function()
                                    vim.notify("Task description cannot be empty", vim.log.levels.WARN)
                                end)
                                return
                            end

                            taskwarrior
                                .cmd({ "add", description, "project:" .. project_name }, {
                                    on_exit = function(j, _code, _signal)
                                        vim.schedule(function()
                                            vim.notify(table.concat(j:result(), " "), vim.log.levels.INFO)
                                        end)
                                    end,
                                })
                                :start()
                        end)
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
