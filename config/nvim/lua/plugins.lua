local conf = {
  profile = {
    enable = true,
    threshold = 0, -- the amount in ms that a plugins load time must be over for it to be included in the profile
  },  display = {
    open_fn = function()
     return require("packer.util").float { border = "rounded" }
    end,
  },
}
