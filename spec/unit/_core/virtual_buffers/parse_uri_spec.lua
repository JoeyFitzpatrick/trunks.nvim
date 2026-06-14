local parse_file_uri = require("trunks._core.virtual_buffers").parse_file_uri
local parse_commit_details_uri = require("trunks._core.virtual_buffers").parse_commit_details_uri

describe("parse_file_uri", function()
    it("parses a valid uri", function()
        local parsed_uri = parse_file_uri("trunks://dir/.git//commit/test/file.txt")
        local expected = { git_root = "dir/", commit = "test", filepath = "file.txt" }
        assert.are.same(expected, parsed_uri)
    end)

    it("parses a uri with a stage (number)", function()
        local parsed_uri = parse_file_uri("trunks://dir/.git//1/file.txt")
        local expected = { git_root = "dir/", stage = "1", filepath = "file.txt" }
        assert.are.same(expected, parsed_uri)
    end)
end)

describe("parse_commit_details_uri", function()
    it("parses a valid uri", function()
        local git_root, ref = parse_commit_details_uri("trunks://dir/.git//commit-details/main")
        assert.are.same("dir/", git_root)
        assert.are.same("main", ref)
    end)
end)
