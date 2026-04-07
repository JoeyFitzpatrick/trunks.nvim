local parse_uri = require("trunks._core.virtual_buffers").parse_uri

describe("parse_uri", function()
    it("parses a valid uri", function()
        local git_root, commit, filepath = parse_uri("trunks://dir/.git//commit/test/file.txt")
        local expected = { "dir/", "test", "file.txt" }
        assert.are.same(expected, { git_root, commit, filepath })
    end)
end)
