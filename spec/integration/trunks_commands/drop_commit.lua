local harness = require("spec.integration.harness")
local drop_commit = function(commit_hash)
    require("trunks._ui.trunks_commands").run_trunks_cmd({ args = "drop-commit " .. commit_hash })
end

describe("drop-commit command", function()
    local context
    before_each(function()
        context = harness.setup_repo()
    end)

    after_each(function()
        harness.teardown_repo(context)
    end)

    it("should drop the most recent commit", function()
        -- Create an initial commit
        harness.create_new_file(context, "first.txt", "first")
        harness.stage_all()
        local first_commit_hash = harness.commit("Initial commit")

        harness.create_new_file(context, "second.txt", "second")
        harness.stage_all()
        local commit_hash = harness.commit("test commit")
        local second_commit_hash = harness.get_commit().short_hash

        assert.are.equal(commit_hash, second_commit_hash)

        drop_commit(commit_hash)
        commit_hash = harness.get_commit().short_hash
        assert.are.equal(commit_hash, first_commit_hash)
    end)

    it("should drop a commit that is not the most recent commit", function()
        harness.create_new_file(context, "first.txt", "first")
        harness.stage_all()
        local first_commit_hash = harness.commit("first commit")

        harness.create_new_file(context, "second.txt", "second")
        harness.stage_all()
        local second_commit_hash = harness.commit("test commit")

        local most_recent_commit = harness.get_commit()
        assert.are.equal(most_recent_commit.short_hash, second_commit_hash)

        drop_commit(first_commit_hash)

        most_recent_commit = harness.get_commit()
        assert.are.equal(most_recent_commit.message, "test commit")

        local all_commits = vim.fn.system("git log")
        local deleted_commit = all_commits:find("first commit", 1, true)
        assert.are.equal(nil, deleted_commit)
    end)

    it("should drop a commit when given the full hash", function()
        harness.create_new_file(context, "first.txt", "first")
        harness.stage_all()
        harness.commit("first commit")
        local full_first_hash = harness.get_commit().long_hash

        harness.create_new_file(context, "second.txt", "second")
        harness.stage_all()
        local second_commit_hash = harness.commit("test commit")

        local most_recent_commit = harness.get_commit()
        assert.are.equal(most_recent_commit.short_hash, second_commit_hash)

        drop_commit(full_first_hash)

        most_recent_commit = harness.get_commit()
        assert.are.equal(most_recent_commit.message, "test commit")

        local all_commits = vim.fn.system("git log")
        local deleted_commit = all_commits:find("first commit", 1, true)
        assert.are.equal(nil, deleted_commit)
    end)

    it("should not drop a commit when the hash is too short", function()
        harness.create_new_file(context, "first.txt", "first")
        harness.stage_all()
        harness.commit("first commit")
        -- Hashes should be at least 7 chars long
        local too_short_hash = harness.get_commit().short_hash:sub(1, 6)

        harness.create_new_file(context, "second.txt", "second")
        harness.stage_all()
        local second_commit_hash = harness.commit("test commit")

        local most_recent_commit = harness.get_commit()
        assert.are.equal(most_recent_commit.short_hash, second_commit_hash)

        drop_commit(too_short_hash)

        most_recent_commit = harness.get_commit()
        assert.are.equal(most_recent_commit.message, "test commit")

        local all_commits = vim.fn.system("git log")
        local deleted_commit = all_commits:find("first commit", 1, true)

        -- We should find the commit, it should not have been deleted
        assert.is_not_nil(deleted_commit)
    end)
end)
