return {
  'olimorris/persisted.nvim',
  lazy = false,
  opts = {
    ignored_dirs = {
      { '~', exact = true },
      '~/Downloads',
      '/tmp',
      '/media',
      '/mnt',
    },
  },
}
