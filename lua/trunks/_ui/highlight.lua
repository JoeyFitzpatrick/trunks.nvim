local M = {}

local function hex_to_rgb(hex)
    local r = tonumber(hex:sub(2, 3), 16)
    local g = tonumber(hex:sub(4, 5), 16)
    local b = tonumber(hex:sub(6, 7), 16)
    return r, g, b
end

local function rgb_to_hex(r, g, b)
    return string.format("#%02X%02X%02X", r, g, b)
end

-- Calculate relative luminance (WCAG formula)
local function get_luminance(r, g, b)
    local function adjust(c)
        c = c / 255.0
        if c <= 0.03928 then
            return c / 12.92
        else
            return math.pow((c + 0.055) / 1.055, 2.4)
        end
    end
    return 0.2126 * adjust(r) + 0.7152 * adjust(g) + 0.0722 * adjust(b)
end

local function ensure_readable_color(r, g, b)
    local is_dark_bg = vim.o.background == "dark"
    local luminance = get_luminance(r, g, b)

    if is_dark_bg then
        -- For dark backgrounds, ensure minimum luminance (0.3 = reasonably bright)
        local min_luminance = 0.3
        if luminance < min_luminance then
            local scale = math.sqrt(min_luminance / math.max(luminance, 0.01))
            r = math.min(255, math.floor(r * scale))
            g = math.min(255, math.floor(g * scale))
            b = math.min(255, math.floor(b * scale))
        end
    else
        -- For light backgrounds, ensure maximum luminance (0.5 = reasonably dark)
        local max_luminance = 0.5
        if luminance > max_luminance then
            local scale = math.sqrt(max_luminance / luminance)
            r = math.floor(r * scale)
            g = math.floor(g * scale)
            b = math.floor(b * scale)
        end
    end

    return r, g, b
end

local function modify_color(hex, modification_level)
    if hex == "#000000" then
        -- The hex for uncommitted changes is really dark, this brightens it up
        return "#555555"
    end
    local r, g, b = hex_to_rgb(hex)
    r = math.floor(r * modification_level)
    g = math.floor(g * modification_level)
    b = math.floor(b * modification_level)

    r, g, b = ensure_readable_color(r, g, b)

    return rgb_to_hex(r, g, b):sub(1, 7)
end

---@param hash string
---@param modification_level? number
---@return { hex: string, stripped_hash: string }
function M.commit_hash_to_hex(hash, modification_level)
    local stripped_hash = hash:gsub("%W", "")
    if #hash < 6 then
        return { hex = "", stripped_hash = stripped_hash }
    end
    local hex = "#" .. hash:match("%w+"):sub(1, 6)
    return { hex = modify_color(hex, modification_level or 0.85), stripped_hash = stripped_hash }
end

--- Make highlighting a line a little easier.
---@param bufnr integer
---@param highlight_group string
---@param line_num integer
---@param start? integer
---@param finish? integer
function M.highlight_line(bufnr, highlight_group, line_num, start, finish)
    if start and finish then
        vim.hl.range(
            bufnr,
            vim.api.nvim_create_namespace(""),
            highlight_group,
            { line_num, start - 1 },
            { line_num, finish }
        )
    end
end

return M
