-- lua/pm_agent/ui.lua
local Popup = require("nui.popup")
local Input = require("nui.input")
local Layout = require("nui.layout")

local M = {}

--- Variáveis de estado para controlar a janela atual
local current_layout = nil
local chat_popup = nil
local prompt_input = nil

--- Formata o buffer do popup para uma experiência de leitura ideal
---@param bufnr number ID do buffer
local function setup_buffer_options(bufnr)
        -- Configura o filetype para Markdown para ativar o syntax highlighting nativo
        vim.api.nvim_buf_set_option(bufnr, "filetype", "markdown")
        -- Quebra de linha automática para evitar scroll horizontal
        vim.api.nvim_buf_set_option(bufnr, "wrap", true)
        -- Habilita a formatação correta de indentação no Markdown
        vim.api.nvim_buf_set_option(bufnr, "breakindent", true)
end

--- Monta a interface de usuário e engatilha o callback de submissão
---@param on_submit function(string) Callback chamado quando o usuário aperta Enter
function M.mount_chat_ui(on_submit)
        -- Se a janela já estiver aberta, não recria
        if current_layout then
                current_layout:mount()
                return
        end

        -- 1. Criação da Janela de Chat (Output)
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

        -- 2. Criação da Caixa de Entrada (Input)
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
                on_submit = function(value)
                        -- Impede envio de strings vazias
                        if value == nil or value == "" then
                                return
                        end

                        -- Limpa a caixa de entrada após o envio
                        -- Um pequeno atraso garante que o UI não trave durante a re-renderização
                        vim.schedule(function()
                                vim.api.nvim_buf_set_lines(prompt_input.bufnr, 0, -1, false, { "" })
                        end)

                        -- Passa o texto para a função orquestradora no init.lua
                        on_submit(value)
                end,
        })

        -- Adiciona atalho prático para fechar a interface com <Esc> no modo Normal
        prompt_input:map("n", "<Esc>", function()
                M.unmount()
        end, { noremap = true })

        -- Fecha a interface se apertar <C-c> no modo de Inserção
        prompt_input:map("i", "<C-c>", function()
                M.unmount()
        end, { noremap = true })

        -- 3. Composição do Layout
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

        -- Monta a UI na tela
        current_layout:mount()

        -- Configura o highlight de Markdown no buffer que acabou de ser montado
        setup_buffer_options(chat_popup.bufnr)
end

--- Esconde a interface atual
function M.unmount()
        if current_layout then
                current_layout:unmount()
        end
end

--- Injeta um fragmento de texto (chunk) no final da janela de chat e faz o scroll
---@param chunk string O fragmento de texto recebido do Ollama
function M.append_to_chat(chunk)
        if not chat_popup or not vim.api.nvim_buf_is_valid(chat_popup.bufnr) then
                return
        end

        local bufnr = chat_popup.bufnr
        local winid = chat_popup.winid

        -- Divide a string em linhas para o Neovim processar corretamente
        local lines = vim.split(chunk, "\n", { plain = true })
        local line_count = vim.api.nvim_buf_line_count(bufnr)

        -- Resgata a última linha atual para concatenar o início do novo chunk
        local last_line = vim.api.nvim_buf_get_lines(bufnr, line_count - 1, line_count, false)[1] or ""

        -- Concatena
        lines[1] = last_line .. lines[1]

        -- Substitui a última linha e adiciona novas (caso o chunk possua '\n')
        vim.api.nvim_buf_set_lines(bufnr, line_count - 1, line_count, false, lines)

        -- Move o cursor para o final da janela simulando um auto-scroll suave
        if winid and vim.api.nvim_win_is_valid(winid) then
                local new_line_count = vim.api.nvim_buf_line_count(bufnr)
                vim.api.nvim_win_set_cursor(winid, { new_line_count, 0 })
        end
end

--- Adiciona uma quebra de linha visual para separar interações no buffer
function M.append_separator()
        M.append_to_chat("\n\n---\n\n")
end

return M
