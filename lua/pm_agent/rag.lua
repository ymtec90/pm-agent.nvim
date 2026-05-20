local config = require("pm_agent.config")

local M = {}

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

-- 2. Cliente Otimizado do Ollama (À prova de quebras no Terminal)
function M.get_embeddings_batch(texts_array, model_name)
	local embed_model = model_name or config.options.embed_model or "nomic-embed-text"
	local embed_url = config.options.ollama_url:gsub("/api/chat$", "/api/embed")

	local json_body = vim.fn.json_encode({
		model = embed_model,
		input = texts_array,
	})

	-- CRIANDO O ARQUIVO TEMPORÁRIO: Isso evita que o JSON gigante estoure a linha de comando do SO
	local tmpfile = vim.fn.tempname()
	vim.fn.writefile({ json_body }, tmpfile)

	-- Chama o curl nativo e pede para ele ler o arquivo temporário (-d @arquivo)
	local curl_cmd = {
		"curl",
		"-s",
		embed_url,
		"-H",
		"Content-Type: application/json",
		"-d",
		"@" .. tmpfile,
	}

	-- Executa a requisição sincronamente
	local response = vim.fn.system(curl_cmd)

	-- Deleta o arquivo temporário após o uso para não acumular lixo no PC
	vim.fn.delete(tmpfile)

	if vim.v.shell_error == 0 then
		local ok, data = pcall(vim.fn.json_decode, response)
		if ok and data.embeddings then
			return data.embeddings
		end
	end

	print("[PM Agent] Erro ao gerar embedding em lote.")
	return nil
end

-- 3. Fatiamento por linhas
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

	if #current_chunk > 0 then
		table.insert(chunks, table.concat(current_chunk, "\n"))
	end

	return chunks
end

-- 4. Motor de Indexação em Lote
function M.index_files(files_list)
	M.vector_db = {}
	local all_chunks = {}
	local chunk_metadata = {}

	for _, filepath in ipairs(files_list) do
		local chunks = M.chunk_file(filepath)
		for i, chunk_text in ipairs(chunks) do
			table.insert(all_chunks, chunk_text)
			table.insert(chunk_metadata, {
				filepath = filepath,
				chunk_index = i,
				content = chunk_text,
			})
		end
	end

	print(string.format("[PM Agent] Vetorizando %d blocos em lote. Aguarde...", #all_chunks))

	local batch_size = 25
	for i = 1, #all_chunks, batch_size do
		local batch_texts = {}
		local batch_meta = {}

		for j = i, math.min(i + batch_size - 1, #all_chunks) do
			table.insert(batch_texts, all_chunks[j])
			table.insert(batch_meta, chunk_metadata[j])
		end

		local vectors = M.get_embeddings_batch(batch_texts)

		if vectors then
			for k, vector in ipairs(vectors) do
				local meta = batch_meta[k]
				meta.vector = vector
				table.insert(M.vector_db, meta)
			end
		end
	end

	print("[PM Agent] Indexação concluída! " .. #M.vector_db .. " blocos prontos.")
end

-- 5. Busca Semântica
function M.search(query, top_k)
	top_k = top_k or 3
	local query_vectors = M.get_embeddings_batch({ query })
	if not query_vectors or not query_vectors[1] then
		return ""
	end

	local query_vector = query_vectors[1]
	local results = {}

	for _, item in ipairs(M.vector_db) do
		local score = cosine_similarity(query_vector, item.vector)
		table.insert(results, { score = score, item = item })
	end

	table.sort(results, function(a, b)
		return a.score > b.score
	end)

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
