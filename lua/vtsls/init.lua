local lazy_mod = {
	commands = function()
		return require("vtsls.commands")
	end,
	config = function()
		return require("vtsls.config").override
	end,
	lspconfig = function()
		return require("vtsls.lspconfig")
	end,
}

return setmetatable({}, {
	__index = function(_, key)
		if lazy_mod[key] then
			return lazy_mod[key]()
		end
	end,
})
