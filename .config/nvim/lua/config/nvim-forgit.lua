require'forgit'.setup({
  diff = 'delta', -- you can use `diff`, `diff-so-fancy`
  ls_file = 'fd', -- also git ls_file
  exact = false, -- exact match
  vsplit = true, -- split forgit window the screen vertically, when set to number
  -- it is a threadhold when window is larger than the threshold forgit will split vertically,
  height_ratio = 0.6, -- height ratio of forgit window when split horizontally
  width_ratio = 0.6, -- height ratio of forgit window when split vertically
  git_alias = true,  -- git commands alias (see readme)
  fugitive = false, -- -- git fugitive installed
})
