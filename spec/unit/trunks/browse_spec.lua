local browse = require("trunks._ui.trunks_commands.browse")

describe("Trunks browse URL generation", function()
    ---@param mock_params Trunks.BrowseParams
    ---@param mock_err? string
    local function mock_generate_browse_params(mock_params, mock_err)
        require("trunks._ui.trunks_commands.browse")._generate_browse_params = function()
            return mock_params, mock_err
        end
    end

    it("generates a GitHub URL", function()
        mock_generate_browse_params({
            remote_url = "https://github.com/username/repo-name",
            filepath = "test.txt",
            hash = "abc123",
        })

        local result = browse._generate_url({ range = 0, line1 = 0, line2 = 0 })
        local expected = "https://github.com/username/repo-name/blob/abc123/test.txt"
        assert.are.equal(result, expected)
    end)

    it("does not generate a URL if a required param fails to be generated", function()
        mock_generate_browse_params({}, "Trunks browse error for test")

        local result = browse._generate_url({ range = 0, line1 = 0, line2 = 0 })
        assert.is_nil(result)
    end)

    it("does not generate a URL for an unsupported git host", function()
        mock_generate_browse_params({
            remote_url = "https://fakehost.com/username/repo-name",
            filepath = "test.txt",
            hash = "abc123",
        })

        local result = browse._generate_url({ range = 0, line1 = 0, line2 = 0 })
        assert.is_nil(result)
    end)

    it("generates a GitLab URL", function()
        mock_generate_browse_params({
            remote_url = "https://gitlab.com/username/repo-name",
            filepath = "test.txt",
            hash = "abc123",
        })

        local result = browse._generate_url({ range = 0, line1 = 0, line2 = 0 })
        local expected = "https://gitlab.com/username/repo-name/-/blob/abc123/test.txt"
        assert.are.equal(result, expected)
    end)

    it("generates a Bitbucket URL", function()
        mock_generate_browse_params({
            remote_url = "https://bitbucket.org/username/repo-name",
            filepath = "test.txt",
            hash = "abc123",
        })

        local result = browse._generate_url({ range = 0, line1 = 0, line2 = 0 })
        local expected = "https://bitbucket.org/username/repo-name/src/abc123/test.txt"
        assert.are.equal(result, expected)
    end)
end)
