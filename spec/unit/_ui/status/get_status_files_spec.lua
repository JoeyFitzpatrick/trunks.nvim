local get_status_files = require("trunks._ui.home_options.status.status_utils").get_status_files

describe("get_status_files", function()
    it("returns staged, unstaged, and untracked files", function()
        local function generate_files()
            return {
                "A  added1",
                "A  added2",
                "M  modstage1",
                "M  modstage2",
                " M modunstage1",
                " M modunstage2",
                "?? untrack1",
                "?? untrack2",
            }
        end
        local files = get_status_files(generate_files)

        assert.are.same(files.staged, {
            "A added1",
            "A added2",
            "M modstage1",
            "M modstage2",
        })

        assert.are.same(files.unstaged, {
            "M modunstage1",
            "M modunstage2",
        })

        assert.are.same(files.untracked, {
            "? untrack1",
            "? untrack2",
        })
    end)
end)
