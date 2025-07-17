---@class trunks.IntegrationTestContext
---@field dir string
---@field original_dir string
---@field original_package_path string

---@class trunks.TestCommit
---@field long_hash string
---@field short_hash string
---@field message string

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

    vim.fn.system("git commit --allow-empty -m 'Initial commit'")

    local context = {
        dir = test_repo,
        original_dir = original_dir,
        original_package_path = original_package_path,
    }

    return context
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

function M.stage_all()
    return vim.fn.system("git stage -A")
end

---@param message string
---@return string -- Commit hash of new commit
function M.commit(message)
    local cmd = "git commit -m " .. vim.fn.shellescape(message)
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        error("Failed to commit: " .. result)
    end

    -- Extract the commit hash from the output
    local hash = result:match("%x%x%x%x%x%x%x")
    return hash or ""
end

---@param index? integer
---@return trunks.TestCommit
function M.get_commit(index)
    local most_recent_commit
    if index then
        most_recent_commit = vim.fn.systemlist("git log -n 1 --skip " .. index)
    else
        most_recent_commit = vim.fn.systemlist("git log -n 1")
    end
    local most_recent_hash = most_recent_commit[1]:match("^commit%s+(%w+)")
    local message = most_recent_commit[5]:match("%S.+")
    return { long_hash = most_recent_hash, short_hash = most_recent_hash:sub(1, 7), message = message }
end

return M
