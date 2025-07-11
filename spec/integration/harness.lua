---@class trunks.IntegrationTestContext
---@field dir string
---@field original_dir string
---@field original_package_path string

local M = {}

---@return trunks.IntegrationTestContext
function M.setup_repo()
    local test_repo = "test_repo"
    os.execute("mkdir " .. test_repo)

    local original_dir = os.getenv("PWD")
    local original_package_path = package.path

    os.execute(
        "cd "
            .. test_repo
            .. " && "
            .. "git init --quiet && "
            .. "git config user.name 'Test User' && "
            .. "git config user.email 'test@example.com'"
    )

    vim.api.nvim_set_current_dir(test_repo)

    -- Set up package.path to include the original plugin directory
    package.path = original_dir .. "/lua/?.lua;" .. original_dir .. "/lua/?/init.lua;" .. package.path

    return {
        dir = test_repo,
        original_dir = original_dir,
        original_package_path = original_package_path,
    }
end

---@param context trunks.IntegrationTestContext
function M.teardown_repo(context)
    vim.api.nvim_set_current_dir(context.original_dir)
    package.path = context.original_package_path
    os.execute("rm -rf " .. context.dir)
end

---@param context trunks.IntegrationTestContext
---@param filename string
---@param content? string
---@return string | nil
function M.create_new_file(context, filename, content)
    local file = io.open(filename, "w")
    if not file then
        return nil
    end
    if content then
        file:write(content)
    end
    file:close()
    vim.api.nvim_command("edit " .. filename)
    return filename
end

return M
