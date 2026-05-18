-- lua/pm_agent/init.lua

local config = require("pm_agent.config")
local ui = require("pm_agent.ui")
local backend = require("pm_agent.backend")
local basket = require("pm_agent.basket")
local workspace = require("pm_agent.workspace")

local M = {}

--- Inicializa o plugin e registra todos os comandos nativos
---@param user_opts table Configurações injetadas via lazy.nvim
function M.setup(user_opts)
    -- Mescla as configurações padrão com as opções fornecidas pelo usuário
    config.setup(user_opts)

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

    -- Comando 5: Escanear e revisar o projeto/workspace inteiro
    vim.api.nvim_create_user_command("PMProject", function()
        M.review_entire_project()
    end, {})
end

--- Fluxo 1: Chat Genérico (Sem contexto de código injetado)
function M.open_agent()
    ui.mount_chat_ui(function(prompt)
        ui.append_to_chat("## 🧑‍💻 Requisito\n" .. prompt .. "\n\n")
        ui.append_to_chat("---\n*Analisando e gerando plano de ação...*\n\n")
        
        local messages = {
            { role = "system", content = config.options.system_prompt },
            { role = "user", content = prompt }
        }
        
        M._dispatch_to_backend(messages)
    end)
end

--- Fluxo 2: Revisar o arquivo atual em foco
function M.review_current_buffer()
    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.fn.expand("%:t")
    local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
    
    if filename == "" then
        print("[PM Agent] Erro: Salve o arquivo primeiro para poder revisá-lo.")
        return
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local code_content = table.concat(lines, "\n")

    -- Uso de colchetes duplos [[ ]] para strings multilinhas seguras em Lua
    local context_prompt = string.format([[
Estou trabalhando no arquivo `%s`.
Aqui está o código atual:
```%s
%s```
]], filename, filetype, code_content)

ui.mount_chat_ui(function(user_prompt)
    local full_prompt = context_prompt .. "\n\nMeu requisito/dúvida: " .. user_prompt
    
    ui.append_to_chat("## 🧑‍💻 Revisando: `" .. filename .. "`\n**Sua demanda:** " .. user_prompt .. "\n\n")
    ui.append_to_chat("---\n*Lendo o arquivo e arquitetando melhorias...*\n\n")
    
    local messages = {
        { role = "system", content = config.options.system_prompt },
        { role = "user", content = full_prompt }
    }
    
    M._dispatch_to_backend(messages)
end)
end

--- Fluxo 3: Gerenciamento e Análise da Cesta de Contexto
function M.manage_basket()
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
        
        local messages = {
            { role = "system", content = config.options.system_prompt },
            { role = "user", content = full_prompt }
        }
        
        M._dispatch_to_backend(messages)
    end)
end)
end

--- Fluxo 4: Revisão do Projeto Inteiro (Workspace Scan)
function M.review_entire_project()
print("[PM Agent] Escaneando a pasta do projeto... Aguarde.")
local project_context = workspace.build_project_context()

ui.mount_chat_ui(function(user_prompt)
    local full_prompt = project_context .. "Meu requisito sobre o projeto: " .. user_prompt
    
    ui.append_to_chat("## 🗂️ Revisão Global do Projeto\n**Sua demanda:** " .. user_prompt .. "\n\n")
    ui.append_to_chat("---\n*Mapeando a árvore de arquivos e dependências...*\n\n")
    
    local messages = {
        { role = "system", content = config.options.system_prompt },
        { role = "user", content = full_prompt }
    }
    
    M._dispatch_to_backend(messages)
end)
end

--- Wrapper interno para executar a chamada de rede mantendo o código DRY (Don't Repeat Yourself)
---@param messages table Array de mensagens do chat estruturadas para a API do Ollama
function M._dispatch_to_backend(messages)
backend.chat_stream(
messages,
{ url = config.options.ollama_url, model = config.options.model },
function(chunk)
-- Callback disparado a cada token recebido do stream
ui.append_to_chat(chunk)
end,
function()
-- Callback disparado ao concluir a resposta
ui.append_separator()
end,
function(err_msg)
-- Callback disparado em caso de falha de conexão (ex: Ollama offline)
ui.append_to_chat("\n\n[ERRO DE REDE] " .. err_msg .. "\n")
ui.append_separator()
end
)
end

return M
