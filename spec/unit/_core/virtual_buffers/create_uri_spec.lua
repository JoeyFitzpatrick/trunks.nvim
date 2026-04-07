local create_uri = require("trunks._core.virtual_buffers").create_uri

describe("create_uri", function()
    it("creates a valid uri", function()
        local result = create_uri("dir/", "test", "file.txt")
        local expected = "trunks://dir/.git//commit/test/file.txt"
        assert.are.equal(expected, result)
    end)
end)
