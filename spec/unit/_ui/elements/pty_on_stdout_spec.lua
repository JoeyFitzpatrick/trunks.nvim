local pty_on_stdout = require("trunks._ui.elements")._pty_on_stdout

local function setup()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local chan = vim.api.nvim_open_term(bufnr, {})
    local on_stdout = pty_on_stdout(chan)
    return bufnr, on_stdout, chan
end

local function wait_for_lines(bufnr, line)
    vim.wait(200, function()
        local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1]
        if line then
            return first_line == line
        else
            return first_line ~= ""
        end
    end)
end

describe("pty_on_stdout", function()
    it("should display a line", function()
        local bufnr, on_stdout = setup()
        on_stdout(_, { "test line" }, _)
        wait_for_lines(bufnr)
        local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1]
        assert.are.equal(first_line, "test line")
    end)

    it("should display multiple lines", function()
        local bufnr, on_stdout = setup()
        on_stdout(_, { "line 1", "line 2" }, _)
        wait_for_lines(bufnr)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 2, false)
        assert.are.same(lines, { "line 1", "line 2" })
    end)

    it("should overwrite lines when run in succession", function()
        local bufnr, on_stdout, chan = setup()
        on_stdout(_, { "first" }, _)
        wait_for_lines(bufnr)

        on_stdout = pty_on_stdout(chan)
        on_stdout(_, { "second" }, _)
        vim.wait(200, function() end)

        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 2, false)
        assert.are.same(lines, { "second", "" })
    end)

    it("should overwrite lines when first run has more lines than second run", function()
        local bufnr, on_stdout, chan = setup()
        on_stdout(_, { "line 1", "line 2", "line 3" }, _)
        wait_for_lines(bufnr)

        on_stdout = pty_on_stdout(chan)
        on_stdout(_, { "" }, _)
        vim.wait(200, function() end)

        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 3, false)
        assert.are.same(lines, { "", "", "" })
    end)
end)
