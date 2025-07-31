local popup = require("trunks._ui.popups.popup")

describe("popup lines", function()
    it("will display columns properly", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        local lines = popup.set_popup_lines(bufnr, {
            { title = "Title 1", rows = { { keys = "r", action = "noop", description = "Do a thing" } } },
            { title = "Title 2", rows = { { keys = "n", action = "noop", description = "Do a different thing" } } },
            { title = "Short", rows = { { keys = "bbb", action = "noop", description = "Do bbb" } } },
        })

        local expected = {
            " Title 1            Title 2                      Short",
            " r Do a thing       n Do a different thing       bbb Do bbb",
        }
        assert.are.same(expected, lines)
    end)
end)
