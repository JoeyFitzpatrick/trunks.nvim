---@class Trunks.BrowseParams
---@field remote_url? string
---@field hash? string
---@field filepath? string
---@field start_line? integer
---@field end_line? integer

local run_cmd = require("trunks._core.run_cmd")

local M = {}

-- setup adapters for common git sources
-- github uses {remote}/blob/{hash}/{filepath}
-- github also allows line numbers, with {remote}/blob/{hash}/{filepath}#L{integer}

---@param params Trunks.BrowseParams
---@return string
function M._get_github_url(params)
    local url = string.format("%s/blob/%s/%s", params.remote_url, params.hash, params.filepath)
    if params.start_line and params.end_line and params.end_line > params.start_line then
        return url .. string.format("#L%d-L%d", params.start_line, params.end_line)
    end
    if params.start_line then
        return url .. string.format("#L%d", params.start_line)
    end
    return url
end

---@return Trunks.BrowseParams, (string | nil) -- generated params or error
function M._generate_browse_params()
    local remote_url, remote_url_exit_code = run_cmd.run_cmd("config --get remote.origin.url")
    local hash, hash_exit_code = run_cmd.run_cmd("rev-parse HEAD")
    local filepath = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")

    if remote_url_exit_code ~= 0 then
        return {}, "Trunks: couldn't get remote URL for browse command"
    end

    if hash_exit_code ~= 0 then
        return {}, "Trunks: couldn't get hash for HEAD for browse command"
    end

    if not filepath or filepath == "" then
        return {}, "Trunks: couldn't get filename for browse command"
    end

    return {
        remote_url = remote_url[1],
        hash = hash[1],
        filepath = filepath,
    }
end

---@param input_args vim.api.keyset.create_user_command.command_args
---@return string | nil -- The generated URL
function M._generate_url(input_args)
    local params, err = M._generate_browse_params()
    if err then
        vim.notify(err, vim.log.levels.ERROR)
        return
    end

    local is_visual = input_args.range == 2

    if is_visual then
        params.start_line = input_args.line1
        params.end_line = input_args.line2
    end

    local url
    if params.remote_url:find("https://github.com", 1, true) then
        url = M._get_github_url(params)
    else
        vim.notify("Trunks: browse doesn't support " .. params.remote_url, vim.log.levels.ERROR)
    end
    return url
end

---@param _ string
---@param input_args? vim.api.keyset.create_user_command.command_args
function M.browse(_, input_args)
    if not input_args then
        error("Trunks: unable to generate browse URL due to missing input_args param")
    end

    local url = M._generate_url(input_args)
    vim.print(url)
end

return M
