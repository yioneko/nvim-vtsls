local async = require("vtsls.async")

local M = {}

local function default_res() end

local function default_rej(err)
	vim.schedule(function()
		vim.notify("[vtsls]: " .. tostring(err), vim.log.levels.ERROR)
	end)
end

local function make_default_locations_handler(title)
	return function(err, locations, ctx, config)
		config = config or {}
		if err then
			error(err)
		end
		local client = vim.lsp.get_client_by_id(ctx.client_id)
		if not locations or vim.tbl_isempty(locations) then
		elseif #locations == 1 then
			vim.lsp.util.show_document(
				locations[1],
				client.offset_encoding,
				{ reuse_win = config.reuse_win, focus = true }
			)
		else
			local items = vim.lsp.util.locations_to_items(locations, client.offset_encoding)

			if config.loclist then
				vim.fn.setloclist(0, {}, " ", { title = title, items = items, context = ctx })
				vim.api.nvim_command("lopen")
			elseif config.on_list then
				config.on_list({ title = title, items = items, context = ctx })
			else
				vim.fn.setqflist({}, " ", { title = title, items = items, context = ctx })
				vim.api.nvim_command("botright copen")
			end
		end
	end
end

local function default_code_action_handler(err, actions, ctx, config)
	config = config or {}
	if err then
		error(err)
	end
	if not actions or #actions == 0 then
		return
	end

	local function on_action(action, has_resolved)
		if not action then
			return
		end
		local client = vim.lsp.get_client_by_id(ctx.client_id)
		if action.edit then
			vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
		elseif action.command then
			local command = type(action.command) == "table" and action.command or action
			local params = {
				command = command.command,
				arguments = command.arguments,
				workDoneToken = command.workDoneToken,
			}
			local err = async.request(client, "workspace/executeCommand", params, ctx.bufnr)
			if err then
				error(err)
			end
		elseif not has_resolved then
			local err, resolved = async.request(client, "codeAction/resolve", action, ctx.bufnr)
			if err then
				error(err)
			end
			on_action(resolved, true)
		end
	end

	if #actions == 1 then
		on_action(actions[1], false)
	else
		local item = async.call(
			vim.ui.select,
			vim.tbl_map(function(ac)
				if vim.fn.has("nvim-0.10") == 1 then
					return { action = ac, ctx = ctx, _compat_ac = ac }
				else
					return { ctx.client_id, ac, _compat_ac = ac }
				end
			end, actions),
			{
				prompt = "Code actions:",
				kind = "codeaction",
				format_item = function(item)
					return item._compat_ac.title
				end,
			}
		)
		if item then
			on_action(item._compat_ac)
		end
	end
end

local o = {
	---@deprecated
	name = "vtsls",
	handlers = {
		source_definition = make_default_locations_handler("TS Source Definitions"),
		file_references = make_default_locations_handler("TS File References"),
		code_action = default_code_action_handler,
	},
	default_resolve = default_res,
	default_reject = default_rej,
	refactor_auto_rename = true,
	refactor_move_to_file = {
		telescope_opts = nil,
	},
}

function M.override(conf)
	o.name = conf.name or o.name
	o.default_resolve = conf.default_resolve or o.default_resolve
	o.default_reject = conf.default_reject or o.default_reject
	if conf.refactor_auto_rename ~= nil then
		o.refactor_auto_rename = conf.refactor_auto_rename
	end
	o.refactor_move_to_file = vim.tbl_extend("force", o.refactor_move_to_file, conf.refactor_move_to_file or {})
	o.handlers = vim.tbl_extend("force", o.handlers, conf.handlers or {})
end

function M.get()
	return o
end

return M
