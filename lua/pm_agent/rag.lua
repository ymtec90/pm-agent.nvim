-- lua/pm_agent/rag.lua
local curl = require("plenary.curl")
local config = require("pm_agent.config")

local M = {}

-- Banco de dados vetorial em memória para a sessão atual
-- Formato: { { filepath = "...", chunk = "...", vector = {...} } }
M.vector_db = {}

-- 1. Matemática Vetorial: Similaridade de Cossenos
local function cosine_similarity(vec_a, vec_b)
	local dot_product, norm_a, norm_b = 0, 0, 0
	for i = 1, #vec_a do
		dot_product = dot_product + (vec_a[i] * vec_b[i])
		norm_a = norm_a + (vec_a[i] * vec_a[i])
		norm_b = norm_b + (vec_b[i] * vec_b[i])
	end

	if norm_a == 0 or norm_b == 0 then
		return 0
	end
	return dot_product / (math.sqrt(norm_a) * math.sqrt(norm_b))
end

-- 2. Cliente do Ollama para Embeddings
-- Recomendo fortemente baixar o modelo `nomic-embed-text` ou `mxbai-embed-large` no seu Ollama local
function M.get_embedding(text, model_name)
	local embed_model = model_name or "nomic-embed-text"
	-- Transforma a URL de chat padrão na URL de embeddings
	local embed_url = config.options.ollama_url:gsub("/chat$", "/embeddings")

	local res = curl.post(embed_url, {
		body = vim.fn.json_encode({
			model = embed_model,
			prompt = text,
		}),
		headers = { ["Content-Type"] = "application/json" },
	})

	if res.status == 200 then
		local data = vim.fn.json_decode(res.body)
		return data.embedding
	else
		print("[PM Agent] Erro ao gerar embedding. Verifique se o modelo " .. embed_model .. " está instalado.")
		return nil
	end
end

-- 3. Função Simples de Chunking (Fatiamento por linhas)
-- Lê um arquivo e devolve pedaços de ~50 linhas
function M.chunk_file(filepath, chunk_size)
	chunk_size = chunk_size or 50
	local chunks = {}
	local current_chunk = {}
	local line_count = 0

	local ok, _ = pcall(function()
		for line in io.lines(filepath) do
			table.insert(current_chunk, line)
			line_count = line_count + 1

			if line_count >= chunk_size then
				table.insert(chunks, table.concat(current_chunk, "\n"))
				current_chunk = {}
				line_count = 0
			end
		end
	end)

	-- Pega o que sobrou no final do arquivo
	if #current_chunk > 0 then
		table.insert(chunks, table.concat(current_chunk, "\n"))
	end

	return chunks
end

-- 4. Motor de Indexação (Alimenta o vector_db)
function M.index_files(files_list)
	print("[PM Agent] Indexando " .. #files_list .. " arquivos para busca semântica...")
	M.vector_db = {} -- Limpa o banco atual

	for _, filepath in ipairs(files_list) do
		local chunks = M.chunk_file(filepath)
		for i, chunk_text in ipairs(chunks) do
			-- Gera o vetor para cada pedaço de código
			local vector = M.get_embedding(chunk_text)
			if vector then
				table.insert(M.vector_db, {
					filepath = filepath,
					chunk_index = i,
					content = chunk_text,
					vector = vector,
				})
			end
		end
	end
	print("[PM Agent] Indexação concluída! " .. #M.vector_db .. " blocos vetorizados.")
end

-- 5. Busca Semântica Retornando Contexto
function M.search(query, top_k)
	top_k = top_k or 3
	local query_vector = M.get_embedding(query)
	if not query_vector then
		return ""
	end

	local results = {}
	-- Compara o vetor da pergunta com todo o banco
	for _, item in ipairs(M.vector_db) do
		local score = cosine_similarity(query_vector, item.vector)
		table.insert(results, { score = score, item = item })
	end

	-- Ordena do maior (mais similar) para o menor
	table.sort(results, function(a, b)
		return a.score > b.score
	end)

	-- Constrói a string de contexto com os top_k resultados
	local context_str = "## Fragmentos Relevantes da Arquitetura:\n\n"
	for i = 1, math.min(top_k, #results) do
		local result = results[i]
		context_str = context_str
			.. string.format(
				"### Arquivo: `%s` (Trecho %d)\n```\n%s\n```\n\n",
				result.item.filepath,
				result.item.chunk_index,
				result.item.content
			)
	end

	return context_str
end

return M
