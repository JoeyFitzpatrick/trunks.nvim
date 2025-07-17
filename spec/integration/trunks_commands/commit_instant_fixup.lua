local harness = require("spec.integration.harness")
local commit_instant_fixup = function(commit_hash)
    require("trunks._ui.trunks_commands").run_trunks_cmd({ args = "commit-instant-fixup " .. commit_hash })
end

describe("commit-instant-fixup command", function()
    local context
    before_each(function()
        context = harness.setup_repo()
    end)

    after_each(function()
        harness.teardown_repo(context)
    end)

    it("should fixup a given commit", function()
        -- Create an initial commit
        harness.create_new_file(context, "first.txt", "first")
        harness.stage_all()
        local first_commit_hash = harness.commit("first commit")

        harness.create_new_file(context, "second.txt", "second")
        harness.stage_all()
        local commit_hash = harness.commit("second commit")
        local second_commit_hash = harness.get_commit().short_hash

        assert.are.equal(commit_hash, second_commit_hash)

        harness.create_new_file(context, "fixup.txt", "fixed up!")
        harness.stage_all()

        commit_instant_fixup(first_commit_hash)

        local commit_diff = vim.fn.system("git log -n 1 --skip 1 -p")
        local content_found = commit_diff:find("fixed up!", 1, true)
        assert.is_not_nil(content_found)
    end)
end)
