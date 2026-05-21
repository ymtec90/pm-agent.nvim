local config = require("pm_agent.config")
local ui = require("pm_agent.ui")
local backend = require("pm_agent.backend")
local basket = require("pm_agent.basket")
local Path = require("plenary.path")
local rag = require("pm_agent.rag") -- Integração com o novo módulo RAG

local M = {}

-- ==========================================
-- 🧠 SISTEMA DE MEMÓRIA E ESTADO DO AGENTE
-- ==========================================

local chat_history = {}
local MAX_HISTORY_MESSAGES = 10 -- Passo 1: Janela Deslizante (máximo de mensagens)
local TOKEN_LIMIT_APPROX = 15000 -- Passo 3: Limite de caracteres para compressão preventiva
local is_rag_active = false

--- Retorna o caminho do ficheiro de histórico persistente no projeto atual
local function get_history_file()
	return Path:new(vim.fn.getcwd() .. "/.pm-agent-history.json")
end

--- Carrega o histórico salvo em disco ao inicializar o projeto (Passo 2)
local function load_history()
	local history_file = get_history_file()
	if history_file:exists() then
		local content = history_file:read()
		local ok, parsed = pcall(vim.fn.json_decode, content)
		if ok and type(parsed) == "table" then
			chat_history = parsed
			print("[PM Agent] Histórico de projeto carregado (" .. #chat_history .. " mensagens).")
		end
	end
end

--- Salva o histórico atual em disco (Passo 2)
local function save_history()
	local history_file = get_history_file()
	local ok, encoded = pcall(vim.fn.json_encode, chat_history)
	if ok then
		history_file:write(encoded, "w")
	end
end

--- Adiciona uma nova interação ao histórico e gerencia o tamanho do contexto (Passo 1 e 3)
local function append_to_history(role, content)
	table.insert(chat_history, { role = role, content = content })

	-- Passo 3: Compressão/Otimização de contexto quando muito longo
	local total_chars = 0
	for _, msg in ipairs(chat_history) do
		total_chars = total_chars + #msg.content
	end

	if total_chars > TOKEN_LIMIT_APPROX then
		-- Mantém apenas os turnos mais recentes essenciais para não estourar a janela local
		while #chat_history > 4 do
			table.remove(chat_history, 1)
		end
		print("[PM Agent] Contexto longo otimizado para preservar a janela de tokens.")
	end

	-- Passo 1: Janela Deslizante Padrão
	if #chat_history > MAX_HISTORY_MESSAGES then
		table.remove(chat_history, 1)
	end

	save_history()
end

-- ==========================================
-- 🚀 INICIALIZAÇÃO E COMANDOS NATIVOS
-- ==========================================

--- Inicializa o plugin e registra todos os comandos nativos
---@param user_opts table Configurações injetadas via lazy.nvim
function M.setup(user_opts)
	config.setup(user_opts)
	load_history() -- Carrega a memória persistente do projeto se existir

	-- Comando 1: Chat livre com o Tech Lead
	vim.api.nvim_create_user_command("PMAgent", function()
		M.open_agent()
	end, {})

	-- Comando 2: Revisar apenas o arquivo atual aberto no buffer
	vim.api.nvim_create_user_command("PMReview", function()
		M.review_current_buffer()
	end, {})

	-- Comando 3: Adicionar o buffer atual à Cesta de Contexto
	vim.api.nvim_create_user_command("PMAdd", function()
		basket.add_current_buffer()
	end, {})

	-- Comando 4: Abrir e gerenciar a Cesta de Contexto
	vim.api.nvim_create_user_command("PMBasket", function()
		M.manage_basket()
	end, {})

	-- Comando 5: Escanear e revisar o projeto/workspace inteiro via RAG
	vim.api.nvim_create_user_command("PMProject", function()
		M.review_entire_project()
	end, {})

  -- Comando 6: Menu interativo de ações especializadas
  vim.api.nvim_create_user_command("PMAction", function())
    M.select_specialized_action()
  end, {})

end

-- ==========================================
-- 🛠️ FLUXOS DE TRABALHO DE INTERAÇÃO
-- ==========================================

--- Fluxo 1: Chat Genérico (Utilizando Histórico Conversacional)
function M.open_agent()
	is_rag_active = false
	ui.mount_chat_ui(function(prompt)
		ui.append_to_chat("## 🧑‍💻 Requisito\n" .. prompt .. "\n\n")
		ui.append_to_chat("---\n*Analisando o histórico e gerando plano de ação...*\n\n")

		append_to_history("user", prompt)
		M._dispatch_to_backend()
	end)
end

--- Fluxo 2: Revisar o arquivo atual em foco
function M.review_current_buffer()
	is_rag_active = false
	local bufnr = vim.api.nvim_get_current_buf()
	local filename = vim.fn.expand("%:t")
	local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

	if filename == "" then
		print("[PM Agent] Erro: Salve o arquivo primeiro para poder revisá-lo.")
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local code_content = table.concat(lines, "\n")

	local context_prompt = string.format(
		[[Estou trabalhando no arquivo `%s`.
Aqui está o código atual:
```%s
%s```]],
		filename,
		filetype,
		code_content
	)

	ui.mount_chat_ui(function(user_prompt)
		local full_prompt = context_prompt .. "\n\nMeu requisito/dúvida: " .. user_prompt

		ui.append_to_chat("## 🧑‍💻 Revisando: `" .. filename .. "`\n**Sua demanda:** " .. user_prompt .. "\n\n")
		ui.append_to_chat("---\n*Lendo o arquivo e arquitetando melhorias...*\n\n")

		append_to_history("user", full_prompt)
		M._dispatch_to_backend()
	end)
end

--- Fluxo 3: Gerenciamento e Análise da Cesta de Contexto
function M.manage_basket()
	is_rag_active = false
	local current_files = basket.get_all()

	if #current_files == 0 then
		print("[PM Agent] A cesta está vazia! Use :PMAdd em seus arquivos primeiro.")
		return
	end

	ui.mount_basket_manager(current_files, function(updated_files)
		basket.set_files(updated_files)
		local context_prompt = basket.build_context_prompt()

		ui.mount_chat_ui(function(user_prompt)
			local full_prompt = context_prompt .. "\n\nMeu requisito sobre estes arquivos:\n" .. user_prompt

			ui.append_to_chat("## 🗂️ Revisão da Cesta de Contexto\n**Sua demanda:** " .. user_prompt .. "\n\n")
			ui.append_to_chat("---\n*Avaliando a integração arquitetural...*\n\n")

			append_to_history("user", full_prompt)
			M._dispatch_to_backend()
		end)
	end)
end

--- Fluxo 4: Indexação Vetorial e Revisão do Projeto Inteiro via RAG
function M.review_entire_project()
	print("[PM Agent] A iniciar indexação do projeto... Isto pode demorar dependendo do tamanho.")

	local cwd = vim.fn.getcwd()
	local scandir = require("plenary.scandir")
	local files_to_index = {}

	scandir.scan_dir(cwd, {
		hidden = false,
		add_dirs = false,
		on_insert = function(entry)
			-- Filtros estruturais para pular diretórios redundantes ou binários
			if
				not entry:match("%.git/")
				and not entry:match("node_modules/")
				and not entry:match("__pycache__/")
				and not entry:match("%.venv/")
				and not entry:match("build/")
				and not entry:match("dist/")
			then
				if
					entry:match("%.lua$")
					or entry:match("%.py$")
					or entry:match("%.md$")
					or entry:match("%.json$")
					or entry:match("%.toml$")
					or entry:match("%.sql$")
				then
					table.insert(files_to_index, entry)
				end
			end
		end,
	})

	if #files_to_index == 0 then
		print("[PM Agent] Nenhum arquivo válido encontrado para indexar.")
		return
	end

	-- Executa a vetorização local através do módulo rag.lua
	rag.index_files(files_to_index)
	is_rag_active = true

	-- Monta a UI injetando o tratador específico para buscas semânticas
	ui.mount_chat_ui(function(user_prompt)
		M._handle_rag_prompt(user_prompt)
	end)
end

--- Intercepta o prompt no modo RAG, realiza a busca vetorial e despacha o contexto refinado
function M._handle_rag_prompt(user_prompt)
	ui.append_to_chat("## 🔎 Busca Semântica (Projeto)\n**A sua demanda:** " .. user_prompt .. "\n\n")
	ui.append_to_chat("---\n*A procurar fragmentos relevantes na arquitetura...*\n\n")

	-- Busca local pelo Top 3 trechos de códigos estatisticamente mais semelhantes
	local relevant_context = rag.search(user_prompt, 3)

	local full_prompt = string.format(
		[[%s

Com base EXCLUSIVAMENTE nos fragmentos de código acima, responda ao seguinte requisito ou dúvida:
%s]],
		relevant_context,
		user_prompt
	)

	append_to_history("user", full_prompt)
	M._dispatch_to_backend()
end

-- ==========================================
-- 🔌 DESPACHANTE E COMUNICAÇÃO ASSÍNCRONA
-- ==========================================

--- Wrapper interno unificado para despachar chamadas mantendo a consistência estrutural das mensagens
function M._dispatch_to_backend()
	local messages = {
		{ role = "system", content = config.options.system_prompt },
	}

	-- Alimenta a requisição com a totalidade da memória da sessão/projeto
	for _, msg in ipairs(chat_history) do
		table.insert(messages, msg)
	end

	local assistant_response = ""

	backend.chat_stream(messages, { url = config.options.ollama_url, model = config.options.model }, function(chunk)
		assistant_response = assistant_response .. chunk
		ui.append_to_chat(chunk)
	end, function()
		-- Callback concluído com sucesso: grava o retorno do assistente na memória
		append_to_history("assistant", assistant_response)
		ui.append_separator()

		-- Mantém a escuta do prompt apontada para o RAG se ele estiver ativo
		if is_rag_active then
			ui.mount_chat_ui(function(next_prompt)
				M._handle_rag_prompt(next_prompt)
			end)
		end
	end, function(err_msg)
		ui.append_to_chat("\n\n[ERRO DE REDE] " .. err_msg .. "\n")
		ui.append_separator()
	end)
end

-- ==========================================
-- 🎯 MENU DE ATIVIDADES ESPECIALIZADAS
-- ==========================================

--- Fluxo 5: Menu interativo para funções específicas de Tech Lead/PM
function M.select_specialized_action()
	is_rag_active = false

	-- 1. Abre a interface do Menu
	ui.mount_action_menu(function(action_id, action_title)
		-- 2. Dicionário de prompts especializados para cada atividade
		local action_prompts = {
			code_review = "Atue como um Revisor de Código Sênior. Foque em apontar violações de Clean Code, sugerir otimizações de performance e identificar potenciais bugs. Responda em Markdown.",
			architecture = "Atue como um Arquiteto de Software Sênior. Crie um design de software estruturado, sugerindo padrões de projeto (Design Patterns), separação de responsabilidades e fluxo de dados.",
			task_breakdown = "Atue como um Technical Project Manager (PM). Quebre o requisito fornecido em histórias de usuário (User Stories) detalhadas, critérios de aceite e proponha uma ordem de execução.",
			tdd_planning = "Atue como um Engenheiro de Qualidade (QA/TDD). Esboce os cenários de testes e o esqueleto de uma suíte de testes (ex: pytest) para garantir a cobertura do requisito solicitado.",
			tech_debt = "Atue como um Tech Lead focado em refatoração. Analise o contexto, identifique débitos técnicos e crie um plano de ação seguro para refatorar o código sem quebrar a lógica de negócios."
		}

		local system_instruction = action_prompts[action_id]

		-- 3. Abre a caixa de input para o usuário fornecer o contexto específico
		ui.mount_chat_ui(function(user_prompt)
			-- Combinamos a instrução especializada com a demanda do usuário
			local full_prompt = string.format(
				"INSTRUÇÃO DE PERSONA: %s\n\nREQUISITO DO USUÁRIO:\n%s",
				system_instruction,
				user_prompt
			)

			ui.append_to_chat("## " .. action_title .. "\n**Sua demanda:** " .. user_prompt .. "\n\n")
			ui.append_to_chat("---\n*Iniciando análise especializada...*\n\n")

			-- Utiliza o sistema de histórico e backend já consolidados no projeto
			append_to_history("user", full_prompt)
			M._dispatch_to_backend()
		end)
	end)
end

return M
