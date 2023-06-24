local M = {}

function M.defaulttable(create)
	if vim.defaulttable then
		return vim.defaulttable(create)
	end
	create = create or function(_)
		return M.defaulttable()
	end
	return setmetatable({}, {
		__index = function(tbl, key)
			rawset(tbl, key, create(key))
			return rawget(tbl, key)
		end,
	})
end

local function buf_get_clients(bufnr)
	if vim.lsp.buf_get_clients then
		return vim.lsp.buf_get_clients(bufnr)
	end
	--TODO: will be deprecated at nvim 0.10
	return vim.lsp.get_active_clients({ bufnr = bufnr })
end

local function resolve_bufnr(bufnr)
	if bufnr == nil or bufnr == 0 then
		return vim.api.nvim_get_current_buf()
	end
	return bufnr
end

---analogous to `vim.lsp.get_clients` from nvim 0.10+
function M.get_clients(filter)
	if vim.lsp.get_clients then
		return vim.lsp.get_clients(filter)
	end

	filter = filter or {}

	local clients = {} --- @type lsp.Client[]

	local active_clients = vim.lsp.get_active_clients()
	local t = filter.bufnr and buf_get_clients(resolve_bufnr(filter.bufnr)) or active_clients
	for client_id in pairs(t) do
		local client = active_clients[client_id]
		if
			client
			and (filter.id == nil or client.id == filter.id)
			and (filter.name == nil or client.name == filter.name)
		then
			clients[#clients + 1] = client
		end
	end
	return clients
end

return M
