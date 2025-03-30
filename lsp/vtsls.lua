local cmd = { "vtsls", "--stdio" }

if vim.fn.has("win32") == 1 then
  cmd = { "cmd.exe", "/C", unpack(cmd) }
end

return {
  cmd = cmd,
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },

  root_markers = { "tsconfig.json", "jsonconfig.json", "package.json", ".git" },

  settings = {
    typescript = {
      updateImportsOnFileMove = "always",
    },
    javascript = {
      updateImportsOnFileMove = "always",
    },
    vtsls = {
      enableMoveToFileCodeAction = true,
    },
  },
}
