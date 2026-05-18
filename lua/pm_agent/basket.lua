-- lua/pm_agent/basket.lua
local path = require("plenary.path")

local M = {}

-- Estado interno da cesta (lista de caminhos relativos ou absolutos)
M.files = {}

--- Adiciona o arquivo atual à cesta (evita duplicatas)
function M.add_current_buffer()
    local filepath = vim.fn.expand("%:p") -- Caminho absoluto
    if filepath == "" then
        print("[PM Agent] Erro: O buffer atual não é um arquivo salvo.")
        return false
    end

    for _, f in ipairs(M.files) do
        if f == filepath then
            print("[PM Agent] Arquivo já está na cesta!")
            return false
        end
    end

    table.insert(M.files, filepath)
    print("[PM Agent] Adicionado à cesta: " .. vim.fn.expand("%:t"))
    return true
end

--- Substitui a cesta inteira (usado quando deletamos itens pela UI)
function M.set_files(new_files)
    M.files = new_files
end

--- Retorna a lista atual
function M.get_all()
    return M.files
end

--- Lê os arquivos da cesta e constrói o pacote de contexto em Markdown
function M.build_context_prompt()
    if #M.files == 0 then return "" end

    local context = "## Contexto do Projeto (Arquivos Selecionados):\n\n"
    
    for _, filepath in ipairs(M.files) do
        local p = path:new(filepath)
        if p:exists() and p:is_file() then
            local filename = vim.fn.fnamemodify(filepath, ":t")
            local ext = vim.fn.fnamemodify(filepath, ":e")
            local content = p:read()
            
            context = context .. string.format("### Arquivo: `%s`\n```%s\n%s\n
```\n\n", filename, ext, content)
        end
    end

    return context
end

--- Captura de forma segura a quantidade de linhas e tamanho do arquivo
---@param filepath string Caminho do arquivo
---@return number, string Linhas e string formatada do tamanho
function M.get_file_stats(filepath)
    local size_bytes = vim.fn.getfsize(filepath)
    -- Se getfsize retornar -1, o arquivo não existe ou não pôde ser lido
    if size_bytes < 0 then return 0, "0 B" end

    -- Formatação amigável do tamanho
    local size_str = size_bytes >= 1024 
        and string.format("%.1f KB", size_bytes / 1024) 
        or size_bytes .. " B"

    local lines = 0
    -- pcall (protected call) evita que o Neovim quebre se tentarmos ler um binário
    local ok, _ = pcall(function()
        for _ in io.lines(filepath) do
            lines = lines + 1
        end
    end)
    
    if not ok then lines = 0 end

    return lines, size_str
end

return M
