describe("status stage single file", function()
    local stage_single_file = require("trunks._ui.home_options.status")._stage_single_file

    local unstaged_statuses = { "M", "?", "D" }
    for _, status in ipairs(unstaged_statuses) do
        it("stages an unstaged file with status " .. status, function()
            local ran_cmd = stage_single_file({
                filename = "file.txt",
                safe_filename = " 'file.txt'",
                status = status,
                staged = false,
            })
            assert.are.same("git add -- file.txt", ran_cmd)
        end)
    end

    local staged_statuses = { "M", "A", "D" }
    for _, status in ipairs(staged_statuses) do
        it("unstages an staged file with status " .. status, function()
            local ran_cmd = stage_single_file({
                filename = "file.txt",
                safe_filename = " 'file.txt'",
                status = status,
                staged = true,
            })
            assert.are.same("git reset HEAD -- file.txt", ran_cmd)
        end)
    end
end)
