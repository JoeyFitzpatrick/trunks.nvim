local delete_trunks_buffers_for_win = require("trunks._core.register")._delete_trunks_buffers_for_win

describe("delete_trunks_buffers_for_win", function()
    it("should delete all trunks buffers for a given window", function()
        local buffer_1 = vim.api.nvim_create_buf(false, true)
        vim.b[buffer_1].trunks_buffer_window_id = 1
        local buffer_2 = vim.api.nvim_create_buf(false, true)
        vim.b[buffer_2].trunks_buffer_window_id = 1

        delete_trunks_buffers_for_win(1)
        assert.are.equal(false, vim.api.nvim_buf_is_loaded(buffer_1))
        assert.are.equal(false, vim.api.nvim_buf_is_valid(buffer_1))
        assert.are.equal(false, vim.api.nvim_buf_is_loaded(buffer_2))
        assert.are.equal(false, vim.api.nvim_buf_is_valid(buffer_2))
    end)

    it("should not delete trunks buffers for a different window", function()
        local buffer_1 = vim.api.nvim_create_buf(false, true)
        vim.b[buffer_1].trunks_buffer_window_id = 1
        local buffer_2 = vim.api.nvim_create_buf(false, true)
        vim.b[buffer_2].trunks_buffer_window_id = 2

        delete_trunks_buffers_for_win(1)
        assert.are.equal(false, vim.api.nvim_buf_is_valid(buffer_1))
        assert.are.equal(true, vim.api.nvim_buf_is_valid(buffer_2))
    end)

    it("should handle an invalid window", function()
        local buffer_1 = vim.api.nvim_create_buf(false, true)
        vim.b[buffer_1].trunks_buffer_window_id = 1
        local buffer_2 = vim.api.nvim_create_buf(false, true)
        vim.b[buffer_2].trunks_buffer_window_id = 2

        delete_trunks_buffers_for_win(-1)
        assert.are.equal(true, vim.api.nvim_buf_is_valid(buffer_1))
        assert.are.equal(true, vim.api.nvim_buf_is_valid(buffer_2))
    end)
end)
