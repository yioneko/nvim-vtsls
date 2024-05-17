local M = {}

M.lsp_get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients

return M
