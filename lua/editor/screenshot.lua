-- FIXME: how to make it use my color theme?
-- FIXME: how to make it attach the path of the image to pi before image is even done? aka async no blocking

--- Screenshot utility: generate syntax-highlighted code images with silicon
--- and attach them to the pi.nvim chat as VLM (vision language model) context.
---
--- Usage:
---   require('editor.screenshot').screenshot_and_attach()          -- selection → pi
---   require('editor.screenshot').screenshot_and_attach({ show_buf = true })  -- full buffer → pi
---   require('editor.screenshot').screenshot_and_attach({ visible = true })   -- visible → pi

NVScreenshot = {}

--- Generate a silicon screenshot of the current visual selection and
--- attach it to the pi chat as an image.
---
--- Waits 300ms for silicon (Rust CLI) to finish writing the PNG to disk,
--- then calls pi.attach_image() to queue it for the next message.
---
---@param opts? table Silicon options merged with defaults.
---   Common overrides:
---     show_buf = true   -- render the full buffer with selection highlighted
---     visible = true    -- render only the visible portion
---     font = "JetBrains Mono"
---     theme = "Dracula"
---     line_number = false
function NVScreenshot.screenshot_and_attach(opts)
  local silicon_ok, silicon = pcall(require, 'silicon')
  if not silicon_ok then
    vim.notify('silicon.lua not available', vim.log.levels.ERROR)
    return
  end

  local pi_ok, pi = pcall(require, 'pi')
  if not pi_ok then
    vim.notify('pi.nvim not available — image generated but not attached', vim.log.levels.WARN)
  end

  -- ensure output directory exists
  local output_dir = vim.fn.stdpath 'cache' .. '/pi-screenshots'
  vim.fn.mkdir(output_dir, 'p')

  local filename = output_dir .. '/silicon_' .. os.date '%Y-%m-%d_%H-%M-%S' .. '.png'

  -- merge user opts over defaults
  local merged = vim.tbl_extend('force', {
    output = filename,
    to_clip = false,
  }, opts or {})

  -- generate the image
  silicon.visualise_api(merged)

  -- attach to pi chat after silicon finishes writing
  if pi_ok then
    vim.defer_fn(function()
      if vim.fn.filereadable(filename) == 1 then
        pi.attach_image(filename)
        vim.notify('Screenshot attached to pi chat', vim.log.levels.INFO)
      else
        vim.notify('Screenshot file not found: ' .. filename, vim.log.levels.ERROR)
      end
    end, 300) -- 300ms delay for silicon CLI to flush to disk
  end
end

