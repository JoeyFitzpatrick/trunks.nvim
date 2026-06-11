local parse_file_uri = require("trunks._core.virtual_buffers").parse_file_uri

describe("parse_uri", function()
    it("parses a valid uri", function()
        local parsed_uri = parse_file_uri("trunks://dir/.git//commit/test/file.txt")
        local expected = { git_root = "dir/", commit = "test", filepath = "file.txt" }
        assert.are.same(expected, parsed_uri)
    end)
end)
