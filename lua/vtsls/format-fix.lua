local o = require("vtsls.config")

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

local tracked_buf = vim.defaulttable()

-- Send request to notify formatting options
local function notify_options(client, bufnr, options)
	if type(tracked_buf[bufnr][client.id].cancel_last) == "function" then
		tracked_buf[bufnr][client.id].cancel_last()
	end

	local ok, request_id = client.request("textDocument/rangeFormatting", {
		textDocument = { uri = vim.uri_from_bufnr(bufnr) },
		options = options,
		range = {
			start = { line = 0, character = 0 },
			["end"] = { line = 0, character = 0 },
		},
	}, function()
		tracked_buf[bufnr][client.id].cancel_last = nil
	end, bufnr)

	if ok then
		tracked_buf[bufnr][client.id].cancel_last = function()
			client.cancel_request(request_id)
			tracked_buf[bufnr][client.id].cancel_last = nil
		end
	end
end

local option_au_id

-- We cannot set buffer local autocmd for OptionSet event
local function try_init_listen_option_set()
	if option_au_id then
		return
	end
	option_au_id = vim.api.nvim_create_autocmd("OptionSet", {
		pattern = { "tabstop", "shiftwidth", "expandtab" },
		callback = function()
			if o.get().enable_format_fix then
				for buf, clients in pairs(tracked_buf) do
					if vim.api.nvim_buf_is_valid(buf) then
						for client_id, options in pairs(clients) do
							local client = vim.lsp.get_client_by_id(client_id)
							if client then
								local next_options = make_formatting_options(buf)
								if not is_formatting_options_eql(next_options, options) then
									tracked_buf[buf][client_id].options = next_options
									notify_options(client, buf, next_options)
								end
							end
						end
					end
				end
			end
		end,
	})

	o.listen(function(conf)
		if conf.enable_format_fix == false and option_au_id then
			vim.api.nvim_del_autocmd(option_au_id)
			option_au_id = nil
		end
	end)
end

local function listen_format_change(client, bufnr)
	try_init_listen_option_set()

	local options = make_formatting_options(bufnr)
	tracked_buf[bufnr][client.id].options = options
	notify_options(client, bufnr, options)

	local lsp_detach_au_id = vim.api.nvim_create_autocmd("LspDetach", {
		buffer = bufnr,
		callback = function(args)
			if args.buf == bufnr and args.data and args.data.client_id == client.id then
				M.detach(client, bufnr)
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufDelete", {
		once = true,
		buffer = bufnr,
		callback = function()
			M.detach(client, bufnr)
			tracked_buf[bufnr] = nil
			vim.api.nvim_del_autocmd(lsp_detach_au_id)
		end,
	})
end

function M.attach(client, bufnr)
	if o.get().enable_format_fix then
		listen_format_change(client, bufnr)
	end

	o.listen(function(conf)
		if conf.enable_format_fix then
			listen_format_change(client, bufnr)
		end
	end)
end

function M.detach(client, bufnr)
	tracked_buf[bufnr][client.id] = nil
	if next(tracked_buf[bufnr]) == nil then
		tracked_buf[bufnr] = nil
	end
end

return M
