local o = require("vtsls.config")
local async = require("vtsls.async")
local rename = require("vtsls.rename")
local compat = require("vtsls.compat")

local M = {}

local function get_client(bufnr)
	local clients = compat.get_clients({ bufnr = bufnr, name = o.get().name })
	if clients and clients[1] then
		return clients[1]
	end
end

local function exec_command(bufnr, client, command, args)
	return async.request(client, "workspace/executeCommand", {
		command = command,
		arguments = args,
	}, bufnr)
end

local function gen_buf_command(name, params, handler)
	handler = handler or function() end
	return function(bufnr, res, rej)
		bufnr = bufnr or vim.api.nvim_get_current_buf()
		res = res or o.get().default_resolve
		rej = rej or o.get().default_reject

		local client = get_client(bufnr)
		if not client then
			return rej("No client found")
		end
		async.exec(function()
			handler(exec_command(bufnr, client, name, params and params(bufnr, client)))
		end, res, rej)
	end
end

local function gen_win_command(name, params, handler)
	handler = handler or function() end
	return function(winnr, res, rej)
		winnr = winnr or vim.api.nvim_get_current_win()
		local bufnr = vim.api.nvim_win_get_buf(winnr)
		res = res or o.get().default_resolve
		rej = rej or o.get().default_reject

		local client = get_client(bufnr)
		if not client then
			return rej("No client found")
		end
		async.exec(function()
			handler(exec_command(bufnr, client, name, params and params(winnr, client)))
		end, res, rej)
	end
end

local source_action_kinds = {
	organize_imports = "source.organizeImports",
	sort_imports = "source.sortImports",
	remove_unused_imports = "source.removeUnusedImports",
	fix_all = "source.fixAll.ts",
	remove_unused = "source.removeUnused.ts",
	add_missing_imports = "source.addMissingImports.ts",
}

local function code_action(bufnr, client, kinds)
	if type(kinds) == "string" then
		kinds = { kinds }
	end
	local params = vim.lsp.util.make_text_document_params(bufnr)
	local diagnostics = vim.diagnostic.get(bufnr, {
		namespace = vim.lsp.diagnostic.get_namespace(client.id),
	})
	local lsp_diagnostics = vim.tbl_map(function(d)
		return {
			range = {
				start = {
					line = d.lnum,
					character = d.col,
				},
				["end"] = {
					line = d.end_lnum,
					character = d.end_col,
				},
			},
			severity = d.severity,
			message = d.message,
			source = d.source,
			code = d.code,
			data = d.user_data and (d.user_data.lsp or {}),
		}
	end, diagnostics)

	return async.request(client, "textDocument/codeAction", {
		textDocument = params,
		range = {
			start = {
				line = 0,
				character = 0,
			},
			["end"] = {
				line = vim.api.nvim_buf_line_count(bufnr),
				character = 0,
			},
		},
		context = {
			only = kinds,
			triggerKind = 1,
			diagnostics = lsp_diagnostics,
		},
	}, bufnr)
end

local function gen_code_action(kinds)
	return function(bufnr, res, rej)
		bufnr = bufnr or vim.api.nvim_get_current_buf()
		res = res or o.get().default_resolve
		rej = rej or o.get().default_reject

		local client = get_client(bufnr)
		if not client then
			return rej("No client found")
		end

		async.exec(function()
			local handler = o.get().handlers.code_action
			handler(code_action(bufnr, client, kinds))
		end, res, rej)
	end
end

function M.rename_file(bufnr, res, rej)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	res = res or o.get().default_resolve
	rej = rej or o.get().default_reject

	local old_name = vim.api.nvim_buf_get_name(bufnr)
	async.exec(function()
		local new_name = async.call(vim.ui.input, { default = old_name })
		if not new_name then
			return
		end
		async.async_call_err(rename, old_name, new_name)
	end, res, rej)
end

M.restart_tsserver = gen_buf_command("typescript.restartTsServer")
M.open_tsserver_log = gen_buf_command("typescript.openTsServerLog")
M.reload_projects = gen_buf_command("typescript.reloadProjects")
M.select_ts_version = gen_buf_command("typescript.selectTypeScriptVersion")

M.goto_project_config = gen_buf_command("typescript.goToProjectConfig", function(bufnr)
	local params = vim.lsp.util.make_text_document_params(bufnr)
	return { params.uri }
end)

M.goto_source_definition = gen_win_command("typescript.goToSourceDefinition", function(winnr, client)
	local params = vim.lsp.util.make_position_params(winnr, client.offset_encoding)
	return { params.textDocument.uri, params.position }
end, o.get().handlers.source_definition)

M.file_references = gen_buf_command("typescript.findAllFileReferences", function(bufnr)
	local params = vim.lsp.util.make_text_document_params(bufnr)
	return { params.uri }
end, o.get().handlers.file_references)

M.organize_imports = gen_code_action(source_action_kinds.organize_imports)
M.sort_imports = gen_code_action(source_action_kinds.sort_imports)
M.remove_unused_imports = gen_code_action(source_action_kinds.remove_unused_imports)
M.fix_all = gen_code_action(source_action_kinds.fix_all)
M.remove_unused = gen_code_action(source_action_kinds.remove_unused)
M.add_missing_imports = gen_code_action(source_action_kinds.add_missing_imports)

M.source_actions = gen_code_action(vim.tbl_values(source_action_kinds))

return M
