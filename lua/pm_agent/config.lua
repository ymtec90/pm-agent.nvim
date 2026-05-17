local M = {}

M.defaults = {
        -- Endereço padrão do Ollama
        ollama_url = "http://localhost:11434/api/chat",
        -- Modelos recomendados para tarefas locais rápidas e lógicas
        model = "qwen2.5-coder:3b", -- ou "codegemma"

        -- Configuração do comportamento do Agente
        system_prompt = [[
Você é um Tech Lead e Engenheiro de Software Sênior.
Sua saída deve ser estritamente em formato Markdown (.md).
Seu objetivo é gerar planos de ação arquiteturais detalhados, checklists de tarefas de implementação e esqueletos completos de testes automatizados (preferencialmente TDD com Python/pytest).
Ao invés de entregar a solução do código final de imediato, atue guiando o design de software, pipelines de dados, integrações de IA local (RAG) e as melhores práticas de Clean Code.
Estruture suas respostas com cabeçalhos claros, listas e blocos de código para a arquitetura inicial.
]],
}

M.options = {}

function M.setup(user_opts)
        M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
