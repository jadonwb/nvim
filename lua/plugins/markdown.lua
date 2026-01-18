return {
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters = {
                ["markdownlint-cli2"] = {
                    args = { "--config", vim.fn.expand("$HOME/.markdownlint-cli2.yaml"), "--" },
                },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters = {
                ["markdownlint-cli2"] = {
                    args = { "--config", vim.fn.expand("$HOME/.markdownlint-cli2.yaml"), "--fix", "$FILENAME" },
                },
            },
        },
    },
    {
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
            heading = {
                width = 'block',
                min_width = 70,
                border = true,
                border_virtual = true,
                icons = {
                    "█" .. " " .. "󰉫" .. " ",
                    "██" .. " " .. "󰉬" .. " ",
                    "███" .. " " .. "󰉭" .. " ",
                    "████" .. " " .. "󰉮" .. " ",
                    "█████" .. " " .. "󰉯" .. " ",
                    "██████" .. " " .. "󰉰" .. " ",
                },
            },
            pipe_table = {
                preset = 'heavy',
            },
            code = {
                border = 'thick',
                position = 'right',
                language_right = '',
                left_pad = 1,
            },
        },
    },
    {
        'jghauser/follow-md-links.nvim'
    },
}
