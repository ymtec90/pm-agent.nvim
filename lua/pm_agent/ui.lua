-- lua/pm_agent/ui.lua
local Popup = require("nui.popup")
local Input = require("nui.input")
local Layout = require("nui.layout")
local basket = require("pm_agent.basket")

local M = {}

-- Estado do Plugin
local chat_bufnr = nil -- O Buffer persistente (Model)
local current_layout = nil -- O Layout atual (View)
local chat_popup = nil -- Painel de Output (View)
local prompt_input = nil -- Caixa de Input (View)

--- Configura opções amigáveis para leitura no buffer
local function setup_buffer_options(bufnr)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "markdown")
	vim.api.nvim_buf_set_option(bufnr, "wrap", true)
	vim.api.nvim_buf_set_option(bufnr, "breakindent", true)
end

function M.mount_chat_ui(on_submit)
	-- Se a interface já está aberta, foca na janela de input e encerra
	if current_layout and prompt_input and prompt_input.winid then
		vim.api.nvim_set_current_win(prompt_input.winid)
		vim.cmd("startinsert")
		return
	end

	-- 1. Inicializa o Buffer Persistente (se não existir)
	-- listed = false (escondido do :ls), scratch = true (não pede pra salvar)
	if not chat_bufnr or not vim.api.nvim_buf_is_valid(chat_bufnr) then
		chat_bufnr = vim.api.nvim_create_buf(false, true)
		setup_buffer_options(chat_bufnr)
	end

	-- 2. Criação do Painel de Chat (injetando o buffer persistente)
	chat_popup = Popup({
		bufnr = chat_bufnr, -- Amarra o Model à View
		enter = false,
		focusable = true,
		border = {
			style = "rounded",
			text = { top = " Tech Lead PM Agent ", top_align = "center" },
		},
	})

	-- 3. Criação da Caixa de Entrada
	prompt_input = Input({
		enter = true,
		border = {
			style = "rounded",
			text = { top = " Descreva a demanda ou requisito ", top_align = "left" },
		},
	}, {
		prompt = " ❯ ",
		default_value = "",
	})

	-- 4. Lógica de Submissão Manual
	local function handle_submit()
		local lines = vim.api.nvim_buf_get_lines(prompt_input.bufnr, 0, 1, false)
		local value = lines[1] or ""

		if value == "" then
			return
		end

		-- Limpa a caixa de entrada
		vim.api.nvim_buf_set_lines(prompt_input.bufnr, 0, -1, false, { "" })
		vim.cmd("startinsert") -- Mantém o usuário em modo de edição

		on_submit(value)
	end

	-- Keymaps do Input
	prompt_input:map("i", "<CR>", handle_submit, { noremap = true })
	prompt_input:map("n", "<CR>", handle_submit, { noremap = true })

	-- Destruição segura da View
	prompt_input:map("n", "<Esc>", function()
		M.unmount()
	end, { noremap = true })
	prompt_input:map("i", "<C-c>", function()
		M.unmount()
	end, { noremap = true })

	-- 5. Composição e Montagem do Layout
	current_layout = Layout(
		{ position = "50%", size = { width = "85%", height = "85%" } },
		Layout.Box({
			Layout.Box(chat_popup, { size = "80%" }),
			Layout.Box(prompt_input, { size = "20%" }),
		}, { dir = "col" })
	)

	current_layout:mount()
end

--- Desmonta a interface limpidamente sem perder o histórico do buffer
function M.unmount()
	if current_layout then
		current_layout:unmount()
		-- Nulifica as referências das Views para forçar recriação na próxima abertura
		current_layout = nil
		chat_popup = nil
		prompt_input = nil
	end
end

--- Injeta o texto do Ollama diretamente no Buffer Persistente
function M.append_to_chat(chunk)
	-- Grava no buffer de forma segura, independentemente da UI estar visível
	if not chat_bufnr or not vim.api.nvim_buf_is_valid(chat_bufnr) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(chat_bufnr)
	local lines = vim.split(chunk, "\n", { plain = true })

	local last_line = vim.api.nvim_buf_get_lines(chat_bufnr, line_count - 1, line_count, false)[1] or ""
	lines[1] = last_line .. lines[1]

	vim.api.nvim_buf_set_lines(chat_bufnr, line_count - 1, line_count, false, lines)

	-- Só faz auto-scroll se a interface estiver efetivamente montada na tela
	if chat_popup and chat_popup.winid and vim.api.nvim_win_is_valid(chat_popup.winid) then
		local new_line_count = vim.api.nvim_buf_line_count(chat_bufnr)
		vim.api.nvim_win_set_cursor(chat_popup.winid, { new_line_count, 0 })
	end
end

function M.append_separator()
	M.append_to_chat("\n\n---\n\n")
end

--- Monta a interface de gerenciamento da cesta de contexto
---@param basket_files table Lista de arquivos atualmente na cesta
---@param on_confirm function(table) Callback disparado ao confirmar a cesta (Enter)
function M.mount_basket_manager(basket_files, on_confirm)
	local popup = Popup({
		enter = true,
		focusable = true,
		position = "50%",
		size = { width = "60%", height = "40%" },
		border = {
			style = "rounded",
			text = {
				top = " 🗂️ Cesta de Contexto ",
				top_align = "center",
				bottom = " [dd] Remover | [Enter] Confirmar e Revisar | [Esc] Sair ",
				bottom_align = "center",
			},
		},
		buf_options = { modifiable = true, readonly = false },
		win_options = { winhighlight = "Normal:Normal,FloatBorder:FloatBorder" },
	})

	popup:mount()

	-- Alimenta o buffer com os arquivos atuais
	vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, basket_files)

	-- Mapeamento: Confirma a cesta e prossegue para a análise
	popup:map("n", "<CR>", function()
		-- Lê o que restou no buffer
		local final_files = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
		local cleaned_files = {}
		for _, f in ipairs(final_files) do
			if f ~= "" then
				table.insert(cleaned_files, f)
			end
		end

		popup:unmount()
		on_confirm(cleaned_files)
	end, { noremap = true })

	-- Mapeamento: Sair sem fazer nada
	popup:map("n", "<Esc>", function()
		popup:unmount()
	end, { noremap = true })

	popup:map("n", "q", function()
		popup:unmount()
	end, { noremap = true })
end

--- Monta a interface interativa da cesta com métricas de arquivos
---@param basket_files table Lista de caminhos absolutos
---@param on_confirm function(table) Callback disparado ao confirmar
function M.mount_basket_manager(basket_files, on_confirm)
	local popup = Popup({
		enter = true,
		focusable = true,
		position = "50%",
		size = { width = "65%", height = "40%" },
		border = {
			style = "rounded",
			text = {
				top = " 🗂️ Cesta de Contexto da Arquitetura ",
				top_align = "center",
				bottom = " [dd] Remover | [Enter] Analisar Projeto | [Esc] Sair ",
				bottom_align = "center",
			},
		},
		buf_options = { modifiable = true, readonly = false },
		win_options = { winhighlight = "Normal:Normal,FloatBorder:FloatBorder" },
	})

	popup:mount()

	-- 1. Prepara as linhas formatadas com metadados para exibição
	local display_lines = {}
	for _, filepath in ipairs(basket_files) do
		local lines_count, size_str = basket.get_file_stats(filepath)
		-- Transforma o caminho absoluto em relativo (ex: src/database.py)
		local relative_path = vim.fn.fnamemodify(filepath, ":.")

		local formatted_line = string.format("%s │ %d linhas │ %s", relative_path, lines_count, size_str)
		table.insert(display_lines, formatted_line)
	end

	vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, display_lines)

	-- 2. Parsing Reverso na Submissão
	popup:map("n", "<CR>", function()
		local final_lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
		local cleaned_files = {}

		for _, line in ipairs(final_lines) do
			if line ~= "" then
				-- Divide a string renderizada usando o separador visual
				local parts = vim.split(line, " │ ", { plain = true })
				local relative_path = vim.trim(parts[1])

				-- Reconverte para caminho absoluto para segurança na leitura
				local absolute_path = vim.fn.fnamemodify(relative_path, ":p")
				table.insert(cleaned_files, absolute_path)
			end
		end

		popup:unmount()
		on_confirm(cleaned_files)
	end, { noremap = true })

	popup:map("n", "<Esc>", function()
		popup:unmount()
	end, { noremap = true })
	popup:map("n", "q", function()
		popup:unmount()
	end, { noremap = true })
end

return M
