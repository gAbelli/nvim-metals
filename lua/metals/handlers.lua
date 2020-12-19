local api = vim.api
local decoration = require'metals.decoration'
local lsp = vim.lsp
local util = require'metals.util'

local M = {}

local decoration_namespace = api.nvim_create_namespace('metals_decoration');

M["metals/quickPick"] = function(_, _, resp)
  local ids = {}
  local labels = {}
  for i, item in pairs(resp.items) do
    table.insert(ids, item.id)
    table.insert(labels, i .. ' - ' .. item.label )
  end

  local choice = util.input_list(labels)
  if (choice == 0) then
    print("\nmetals: operation cancelled")
    return { cancelled = true; }
  else
    return { itemId = ids[choice] }
  end
end

M['metals/inputBox'] = function(_, _, resp)
    local name = util.input_box(resp.prompt .. ': ')

    if (name == '') then
      print("\nmetals: operation cancelled")
      return { cancelled = true; }
    else
      return { value = name; }
    end
end

M['metals/executeClientCommand'] = function(_, _, cmd_request)
  if cmd_request.command == 'metals-goto-location' then
    lsp.util.jump_to_location(cmd_request.arguments[1])
  end
end

M['textDocument/hover'] = function(_, method, result)
    local opts = {
      pad_left = 1;
      pad_right = 1;
    }
    lsp.util.focusable_float(method, function()
        if not (result and result.contents) then
            return
        end
        local markdown_lines = lsp.util.convert_input_to_markdown_lines(result.contents)
        markdown_lines = lsp.util.trim_empty_lines(markdown_lines)
        if vim.tbl_isempty(markdown_lines) then
            return
        end
        local bufnr, winnr = lsp.util.fancy_floating_markdown(markdown_lines, opts)
        lsp.util.close_preview_autocmd({"CursorMoved", "BufHidden", "InsertCharPre"}, winnr)
        util.wrap_hover(bufnr, winnr)
        return bufnr, winnr
    end)
end

-- Callback function to handle `metals/status`
-- This simply sets a global variable `metals_status` which can be easily
-- picked up and used in a statusline.
-- Command and Tooltip are not covered from the spec.
-- https://scalameta.org/metals/docs/editors/new-editor.html#metalsstatus
M['metals/status'] = function(_, _, params)
  if params.hide then
    api.nvim_set_var('metals_status', '')
  else
    api.nvim_set_var('metals_status', params.text)
  end
end

M['metals/publishDecorations'] = function(err, _, decorations)
  if err then
    print("metals.publishDecorations: Server error")
  end
  if not decorations then
    return
  end

  local uri = decorations.uri
  local bufnr = vim.uri_to_bufnr(uri)
  if not bufnr then
    print("metals.publishDecorations: Couldn't find buffer for ", uri)
    return
  end

  -- Unloaded buffers should not handle diagnostics.
  -- When the buffer is loaded, we'll call on_attach, which sends textDocument/didOpen.
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local decoration_color = vim.g.metals_decoration_color

  api.nvim_buf_clear_namespace(bufnr, decoration_namespace, 0, -1)
  decoration.clear_hover_messages()

  for _, deco in ipairs(decorations.options) do
    decoration.set_decoration(bufnr, decoration_namespace, deco, decoration_color)
    decoration.store_hover_message(deco)
  end
end
return M
