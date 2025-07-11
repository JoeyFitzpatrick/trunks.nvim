local render = require("trunks._ui.interceptors.staging_area").render
local harness = require("spec.integration.harness")

describe("staging area integration", function()
    local context
    before_each(function()
        context = harness.setup_repo()
    end)

    after_each(function()
        harness.teardown_repo(context)
    end)

    it("should render", function()
        harness.create_new_file(context, "test.txt", "yeah")
        local bufnr = render()
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local expected = {
            "HEAD: main",
            "No files staged",
            "?? test.txt",
        }
        assert.are.same(lines, expected)
    end)
end)
