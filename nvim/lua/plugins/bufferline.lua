return {
	'akinsho/bufferline.nvim', 
	version = "*",
	dependencies = 'nvim-tree/nvim-web-devicons',
	config = function()
		vim.cmd.colorscheme("tokyonight")
		vim.opt.termguicolors = true
		require('bufferline').setup {}
	end
}

