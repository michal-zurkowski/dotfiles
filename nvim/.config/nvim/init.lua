-- Set space as the leader key (must be defined first)
vim.g.mapleader = " "

-- Basic UI and text editing settings
vim.opt.number = true             -- Show absolute line numbers
vim.opt.relativenumber = true     -- Relative numbers for easy jumping
vim.opt.mouse = 'a'               -- Enable mouse support
vim.opt.ignorecase = true         -- Case-insensitive searching...
vim.opt.smartcase = true          -- ...unless you type a capital letter
vim.opt.clipboard = "unnamedplus" -- Sync with system clipboard

-- Tab and indentation settings
vim.opt.tabstop = 4               -- Number of spaces tabs count for
vim.opt.shiftwidth = 4            -- Size of an indent
vim.opt.expandtab = true          -- Convert tabs to spaces
