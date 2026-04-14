# ~/.zshenv

# === XDG Base Directory Specification ===
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# === Zsh Initialization ===
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# === Other XDG Enforcements ===
export DOTNET_CLI_HOME="$XDG_DATA_HOME/dotnet"
export _Z_DATA="$XDG_DATA_HOME/z" 
export HISTFILE="$XDG_STATE_HOME/zsh/history"

# Proxy
# export http_proxy="http://127.0.0.1:7890"
# export https_proxy="http://127.0.0.1:7890"
# export all_proxy="socks5://127.0.0.1:7890"
