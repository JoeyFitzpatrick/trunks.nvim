local get_visual_restore_cmds = require("trunks._ui.home_options.status")._get_visual_restore_cmds

local function make_file(opts)
    return {
        filename = opts.filename,
        safe_filename = opts.safe_filename or opts.filename,
        status = opts.status,
        staged = opts.staged,
    }
end

describe("_get_visual_restore_cmds", function()
    it("returns empty list for no files", function()
        local cmds = get_visual_restore_cmds({})
        assert.are.same({}, cmds)
    end)

    it("resets and cleans a single staged file", function()
        local files = {
            make_file({ filename = "foo.lua", status = "M", staged = true }),
        }
        local cmds = get_visual_restore_cmds(files)
        assert.are.same({
            "git reset -- foo.lua",
            "git clean -f -- foo.lua",
        }, cmds)
    end)

    it("restores a single unstaged file", function()
        local files = {
            make_file({ filename = "bar.lua", status = "M", staged = false }),
        }
        local cmds = get_visual_restore_cmds(files)
        assert.are.same({
            "git restore -- bar.lua",
        }, cmds)
    end)

    it("cleans a single untracked file", function()
        local files = {
            make_file({ filename = "baz.lua", status = "?", staged = false }),
        }
        local cmds = get_visual_restore_cmds(files)
        assert.are.same({
            "git clean -f -- baz.lua",
        }, cmds)
    end)

    it("concatenates multiple staged files into one pair of commands", function()
        local files = {
            make_file({ filename = "a.lua", status = "M", staged = true }),
            make_file({ filename = "b.lua", status = "A", staged = true }),
        }
        local cmds = get_visual_restore_cmds(files)
        assert.are.same({
            "git reset -- a.lua b.lua",
            "git clean -f -- a.lua b.lua",
        }, cmds)
    end)

    it("concatenates multiple unstaged files into one restore command", function()
        local files = {
            make_file({ filename = "c.lua", status = "M", staged = false }),
            make_file({ filename = "d.lua", status = "D", staged = false }),
        }
        local cmds = get_visual_restore_cmds(files)
        assert.are.same({
            "git restore -- c.lua d.lua",
        }, cmds)
    end)

    it("concatenates multiple untracked files into one clean command", function()
        local files = {
            make_file({ filename = "e.lua", status = "?", staged = false }),
            make_file({ filename = "f.lua", status = "?", staged = false }),
        }
        local cmds = get_visual_restore_cmds(files)
        assert.are.same({
            "git clean -f -- e.lua f.lua",
        }, cmds)
    end)

    it("produces all three command groups for a mixed selection", function()
        local files = {
            make_file({ filename = "staged.lua", status = "M", staged = true }),
            make_file({ filename = "unstaged.lua", status = "M", staged = false }),
            make_file({ filename = "untracked.lua", status = "?", staged = false }),
        }
        local cmds = get_visual_restore_cmds(files)
        assert.are.same({
            "git reset -- staged.lua",
            "git clean -f -- staged.lua",
            "git restore -- unstaged.lua",
            "git clean -f -- untracked.lua",
        }, cmds)
    end)

    it("treats deleted unstaged files as unstaged, not untracked", function()
        local files = {
            make_file({ filename = "gone.lua", status = "D", staged = false }),
        }
        local cmds = get_visual_restore_cmds(files)
        assert.are.same({
            "git restore -- gone.lua",
        }, cmds)
    end)
end)
