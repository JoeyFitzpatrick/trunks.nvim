local M = {}

M.FILENAME_PREFIX = "trunks://"

M.FORMATS = {
    SHOW = "commit %H%n"
        .. "tree   %T%n"
        .. "parent %P%n"
        .. "Author: %an <%ae>%n"
        .. "Date:   %ad%n%n"
        .. "%w(0,4,4)%B",
}

M.WORKING_TREE = "working_tree"

return M
