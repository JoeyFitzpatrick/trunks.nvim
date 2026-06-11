local create_uri = require("trunks._core.virtual_buffers").create_uri
local create_diff_uri = require("trunks._core.virtual_buffers").create_diff_uri

describe("create_uri", function()
    it("creates a valid uri", function()
        local result = create_uri("dir/", "test", "file.txt")
        local expected = "trunks://dir/.git//commit/test/file.txt"
        assert.are.equal(expected, result)
    end)
end)

describe("create_diff_uri", function()
    it("creates a valid diff uri", function()
        local result = create_diff_uri("dir/", "file.txt", "2")
        local expected = "trunks://dir/.git//2/file.txt"
        assert.are.equal(expected, result)
    end)
end)
