-- lua/pm_agent/ui.lua
local Popup = require("nui.popup")
local Input = require("nui.input")
local Layout = require("nui.layout")

local M = {}

--- Variáveis de estado
local current_layout = nil
local chat_popup = nil
local prompt_input = nil

local function setup_buffer_options(bufnr)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "markdown")
    vim.api.nvim_buf_set_option(bufnr, "wrap", true)
    vim.api.nvim_buf_set_option(bufnr, "breakindent", true)
end

function M.mount_chat_ui(on_submit)
    if current_layout then
        current_layout:mount()
        return
    end

    -- 1. Criação da Janela de Chat
    chat_popup = Popup({
        enter = false,
        focusable = true,
        border = {
            style = "rounded",
            text = {
                top = " Tech Lead PM Agent ",
                top_align = "center",
            },
        },
        buf_options = {
            modifiable = true,
            readonly = false,
        },
    })

    -- 2. Criação da Caixa de Entrada (Sem o on_submit nativo)
    prompt_input = Input({
        enter = true,
        border = {
            style = "rounded",
            text = {
                top = " Descreva a demanda ou requisito ",
                top_align = "left",
            },
        },
    }, {
        prompt = " ❯ ",
        default_value = "",
    })

    -- 3. Lógica customizada para enviar o prompt sem desmontar o layout
    local function handle_submit()
        -- Lê a linha digitada
        local lines = vim.api.nvim_buf_get_lines(prompt_input.bufnr, 0, 1, false)
        local value = lines[1] or ""

        if value == "" then return end

        -- Limpa a caixa de entrada para a próxima interação
        vim.api.nvim_buf_set_lines(prompt_input.bufnr, 0, -1, false, { "" })
        
        -- Garante que continuamos no modo de inserção
        vim.cmd("startinsert")

        -- Dispara a chamada para a API do Ollama
        on_submit(value)
    end

    -- Mapeamento manual da tecla Enter no modo Inserção e Normal
    prompt_input:map("i", "<CR>", handle_submit, { noremap = true })
    prompt_input:map("n", "<CR>", handle_submit, { noremap = true })

    -- Atalhos para sair do plugin
    prompt_input:map("n", "<Esc>", function() M.unmount() end, { noremap = true })
    prompt_input:map("i", "<C-c>", function() M.unmount() end, { noremap = true })

    -- 4. Composição do Layout
    current_layout = Layout(
        {
            position = "50%",
            size = {
                width = "85%",
                height = "85%",
            },
        },
        Layout.Box({
            Layout.Box(chat_popup, { size = "80%" }),
            Layout.Box(prompt_input, { size = "20%" }),
        }, { dir = "col" })
    )

    current_layout:mount()
    setup_buffer_options(chat_popup.bufnr)
end

function M.unmount()
    if current_layout then
        current_layout:unmount()
    end
end

function M.append_to_chat(chunk)
    -- Correção de Segurança: Checagem rigorosa do bufnr para evitar Lua crashes
    if not chat_popup or not chat_popup.bufnr or not vim.api.nvim_buf_is_valid(chat_popup.bufnr) then
        return
    end

    local bufnr = chat_popup.bufnr
    local winid = chat_popup.winid

    local lines = vim.split(chunk, "\n", { plain = true })
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    
    local last_line = vim.api.nvim_buf_get_lines(bufnr, line_count - 1, line_count, false)[1] or ""
    lines[1] = last_line .. lines[1]

    vim.api.nvim_buf_set_lines(bufnr, line_count - 1, line_count, false, lines)

    if winid and vim.api.nvim_win_is_valid(winid) then
        local new_line_count = vim.api.nvim_buf_line_count(bufnr)
        vim.api.nvim_win_set_cursor(winid, { new_line_count, 0 })
    end
end

function M.append_separator()
    M.append_to_chat("\n\n---\n\n")
end

return M
