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

return M
