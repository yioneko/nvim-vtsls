local o = require("vtsls.config")
local compat = require("vtsls.compat")

local M = {}

local function make_formatting_options(bufnr)
	return {
		tabSize = vim.lsp.util.get_effective_tabstop(bufnr),
		insertSpaces = vim.bo[bufnr].expandtab,
	}
end

local function is_formatting_options_eql(a, b)
	return a.tabSize == b.tabSize and a.insertSpaces == b.insertSpaces
end

---@type table<number, table<number, { options: table, cancel: function }>>
local tracked = compat.defaulttable()

-- Send request to notify formatting options
local function notify_options(client, bufnr)
	local cur_options = tracked[bufnr][client.id].options
	local next_options = make_formatting_options(bufnr)
	if is_formatting_options_eql(next_options, cur_options) then
		return
	end

	tracked[bufnr][client.id].options = next_options
	if type(tracked[bufnr][client.id].cancel) == "function" then
		tracked[bufnr][client.id].cancel()
	end

	local ok, request_id = client.request("textDocument/rangeFormatting", {
		textDocument = { uri = vim.uri_from_bufnr(bufnr) },
		options = next_options,
		range = {
			start = { line = 0, character = 0 },
			["end"] = { line = 0, character = 0 },
		},
	}, function()
		tracked[bufnr][client.id].cancel = nil
	end, bufnr)

	if ok then
		tracked[bufnr][client.id].cancel = function()
			client.cancel_request(request_id)
			tracked[bufnr][client.id].cancel = nil
		end
	end
end

local augroup = vim.api.nvim_create_augroup("nvim-vtsls-format-listen", {})
---@type function
local try_init_option_listening
do
	local option_au_id
	try_init_option_listening = function()
		if option_au_id then
			return
		end
		-- NOTE: we cannot set buffer local autocmd for OptionSet event
		option_au_id = vim.api.nvim_create_autocmd("OptionSet", {
			group = augroup,
			pattern = { "tabstop", "shiftwidth", "expandtab" },
			callback = function()
				if o.get().active_format_opts_notify then
					local clients = compat.get_clients({ name = o.get().name })
					for _, client in pairs(clients) do
						for buf, _ in pairs(client.attached_buffers) do
							notify_options(client, buf)
						end
					end
				end
			end,
		})
	end
end

function M.attach(client, bufnr)
	if o.get().active_format_opts_notify then
		try_init_option_listening()
		notify_options(client, bufnr)
	end
end

function M.detach(client, bufnr)
	tracked[bufnr][client.id] = nil
	if next(tracked[bufnr]) == nil then
		tracked[bufnr] = nil
	end
end

return M
