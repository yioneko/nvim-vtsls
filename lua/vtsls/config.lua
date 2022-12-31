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
			vim.lsp.util.jump_to_location(locations[1], client.offset_encoding, config.reuse_win)
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
		local tuple = async.call(
			vim.ui.select,
			vim.tbl_map(function(ac)
				return { ctx.client_id, ac }
			end, actions),
			{
				prompt = "Code actions:",
				kind = "codeaction",
				format_item = function(tuple)
					return tuple[2].title
				end,
			}
		)
		if tuple then
			on_action(tuple[2])
		end
	end
end

local o = {
	name = "vtsls",
	handlers = {
		source_definition = make_default_locations_handler("TS Source Definitions"),
		file_references = make_default_locations_handler("TS File References"),
		code_action = default_code_action_handler,
	},
	default_resolve = default_res,
	default_reject = default_rej,
}

function M.override(conf)
	o.name = conf.name or o.name
	o.default_resolve = conf.default_resolve or o.default_resolve
	o.default_reject = conf.default_reject or o.default_reject
	vim.tbl_extend("force", o.handlers, conf.handlers or {})
end

function M.get()
	return o
end

return M
