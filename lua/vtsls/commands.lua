local o = require("vtsls.config")
local co = coroutine

local M = {}

local function sync(func, res, rej)
	res = res or function() end
	rej = rej or vim.schedule_wrap(vim.notify)

	local thread = co.create(func)
	local step
	step = function(...)
		local args = { ... }
		local ok, nxt = co.resume(thread, unpack(args))
		if co.status(thread) ~= "dead" then
			nxt(step)
		elseif ok then
			res(unpack(args))
		else
			rej(nxt)
		end
	end

	step()
end

local function request(client, method, params, bufnr)
	return function(cb)
		client.request(method, params, cb, bufnr)
	end
end

local function get_client(bufnr)
	local clients = vim.lsp.get_active_clients({ bufnr = bufnr, name = o.get().name })
	if clients and clients[1] then
		return clients[1]
	else
		vim.schedule(function()
			vim.notify("No active client found for " .. o.get().name, vim.log.levels.ERROR)
		end)
	end
end

local function exec_command(bufnr, client, command, args)
	co.yield(request(client, "workspace/executeCommand", {
		command = command,
		arguments = args,
	}, bufnr))
end

local function gen_buf_command(name, params, default_res, default_rej)
	return function(bufnr, res, rej)
		bufnr = bufnr or vim.api.nvim_get_current_buf()
		res = res or default_res
		rej = rej or default_rej
		local client = get_client(bufnr)
		if not client then
			if rej then
				rej("No client found")
			end
			return
		end
		sync(function()
			return exec_command(bufnr, client, name, params and params(bufnr, client))
		end, res, rej)
	end
end

local function gen_win_command(name, params, default_res, default_rej)
	return function(winnr, res, rej)
		winnr = winnr or vim.api.nvim_get_current_win()
		local bufnr = vim.api.nvim_win_get_buf(winnr)
		res = res or default_res
		rej = rej or default_rej
		local client = get_client(bufnr)
		if not client then
			if rej then
				rej("No client found")
			end
			return
		end
		sync(function()
			return exec_command(bufnr, client, name, params and params(winnr, client))
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
			user_data = d.user_data and (d.user_data.lsp or {}),
		}
	end, diagnostics)

	co.yield(request(client, "textDocument/codeAction", {
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
	}, bufnr))
end

local function gen_code_action(kinds)
	return function(bufnr, res, rej)
		bufnr = bufnr or vim.api.nvim_get_current_buf()
		local client = get_client(bufnr)
		if not client then
			if rej then
				rej("No client found")
			end
			return
		end
		sync(function()
			return code_action(bufnr, client, kinds)
		end, res or o.get().handlers.code_action, rej)
	end
end

function M.rename_file(bufnr, res, rej)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	res = res or function() end
	rej = rej or vim.schedule_wrap(vim.notify)
	local client = get_client(bufnr)
	if not client then
		return rej("No client found")
	end

	local old_name = vim.api.nvim_buf_get_name(bufnr)
	vim.ui.input({ default = old_name }, function(new_name)
		if not new_name then
			return res(old_name)
		end
		if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
			return rej("Buffer is invalid")
		end

		local function do_rename()
			-- try to create dir
			local new_dir = vim.fn.fnamemodify(new_name, ":h")
			vim.fn.mkdir(new_dir, "p")

			local success = vim.loop.fs_rename(old_name, new_name)
			if not success then
				return rej("os rename failed")
			end
			vim.api.nvim_buf_set_name(bufnr, new_name)
			vim.api.nvim_buf_call(bufnr, function()
				vim.cmd("silent! write!")
			end)

			if client.is_stopped() then
				return rej("client not active")
			end
			client.notify("workspace/didRenameFiles", {
				files = {
					{
						oldUri = vim.uri_from_fname(old_name),
						newUri = vim.uri_from_fname(new_name),
					},
				},
			})
			res(new_name)
		end

		-- new path exists
		local stat = vim.loop.fs_stat(new_name)
		if stat then
			vim.ui.input({ prompt = "Overwrite '" .. vim.fn.fnamemodify(new_name, ":.") .. "'? y/n" }, function(t)
				if t == "y" then
					do_rename()
				end
			end)
		else
			do_rename()
		end
	end)
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
