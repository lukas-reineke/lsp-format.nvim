ifndef VERBOSE
.SILENT:
endif

specs: dependencies
	@echo "Running lsp-format specs..."
	timeout 300 nvim -e \
		--headless \
		-u specs/minimal_init.vim \
		-c "PlenaryBustedDirectory specs/features {minimal_init = 'specs/minimal_init.vim'}"

dependencies:
	if [ ! -d vendor ]; then \
		git clone --depth 1 \
			https://github.com/nvim-lua/plenary.nvim \
			vendor/pack/vendor/start/plenary.nvim; \
		git clone --depth 1 \
			https://github.com/neovim/nvim-lspconfig \
			vendor/pack/vendor/start/nvim-lspconfig; \
	fi
