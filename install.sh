#!/bin/bash
#
# XDG-Strict Dotfiles Setup Script (Customized for your dir.txt structure)
# Role: Senior Linux DevOps Engineer
#

# ==========================================
# 0. 全局配置与安全检查
# ==========================================
set -e              # 遇到错误立即停止
set -u              # 使用未定义变量报错
set -o pipefail     # 管道命令报错传递

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 1. 定义核心路径 (XDG Base Directory)
# 你的 dir.txt 显示 OMZ 在 .local/share，Cache 在 .cache
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# 脚本所在目录 (假设脚本在 dotfiles 根目录)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 需要 Stow 的包列表 (根据 dir.txt 分析得出)
# fonts: 你的字体在 dotfiles/fonts/.local/share/fonts，需要被 stow
# zsh, bash, git, tmux: 你的配置文件包
STOW_PACKAGES=("zsh" "bash" "git" "tmux" "fonts")

# OMZ 安装目标路径 (XDG Data)
OMZ_DIR="$XDG_DATA_HOME/oh-my-zsh"

# ==========================================
# 辅助函数
# ==========================================
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

# 备份冲突文件
backup_if_exists() {
    local target="$1"
    # 如果目标存在，且不是一个符号链接，则说明是原生文件，需要备份
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        log_warn "发现冲突文件: $target，正在备份..."
        mv "$target" "${target}.backup.$(date +%s)"
    fi
}

# ==========================================
# 1. 基础设施初始化
# ==========================================
init_xdg_dirs() {
    log_info "正在初始化 XDG 目录结构..."
    mkdir -p "$XDG_CONFIG_HOME"
    mkdir -p "$XDG_DATA_HOME"
    mkdir -p "$XDG_STATE_HOME"
    mkdir -p "$XDG_CACHE_HOME"
    
    # 预创建 fonts 目录，确保 stow 能够正确链接文件而不是目录本身
    # (如果目标父目录不存在，Stow 有时会链接整个父目录，这可能不是我们想要的)
    mkdir -p "$XDG_DATA_HOME/fonts"
    
    # 预创建 OMZ 缓存目录 (根据 dir.txt)
    mkdir -p "$XDG_CACHE_HOME/oh-my-zsh"
}

install_dependencies() {
    log_info "正在检测操作系统并安装基础软件..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    fi

    local pkgs="zsh tmux stow git curl fontconfig"
    
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt-get update && sudo apt-get install -y $pkgs
    elif [[ "$OS" == "arch" ]]; then
        sudo pacman -Syu --noconfirm $pkgs
    elif [[ "$OS" == "almalinux" || "$OS" == "centos" || "$OS" == "fedora" ]]; then
        sudo dnf install -y $pkgs util-linux-user
    else
        log_warn "未识别的发行版，请手动确认安装了: $pkgs"
    fi
}

# ==========================================
# 2. 数据层安装 (OMZ & Plugins)
# ==========================================
install_omz_and_plugins() {
    # A. 安装 Oh My Zsh 核心代码到 .local/share
    if [ -d "$OMZ_DIR" ]; then
        log_success "Oh My Zsh 已存在于 $OMZ_DIR"
    else
        log_info "正在克隆 Oh My Zsh 到 $OMZ_DIR ..."
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR"
    fi

    # B. 安装 Powerlevel10k 主题
    local p10k_dir="${OMZ_DIR}/custom/themes/powerlevel10k"
    if [ ! -d "$p10k_dir" ]; then
        log_info "正在安装 Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
    fi

    # C. 安装常用插件 (根据生产环境习惯推荐)
    local plugins_dir="${OMZ_DIR}/custom/plugins"
    
    if [ ! -d "$plugins_dir/zsh-syntax-highlighting" ]; then
        log_info "安装插件: zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"
    fi
    
    if [ ! -d "$plugins_dir/zsh-autosuggestions" ]; then
        log_info "安装插件: zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions"
    fi
}

# ==========================================
# 3. 配置层链接 (Stow)
# ==========================================
link_dotfiles() {
    log_info "开始执行 Stow 链接配置..."
    
    # 冲突检测与备份
    # 1. Zsh 配置 (stow zsh -> ~/.config/zsh, ~/.zshenv)
    backup_if_exists "$HOME/.zshenv"
    backup_if_exists "$XDG_CONFIG_HOME/zsh"
    
    # 2. Bash 配置 (stow bash -> ~/.config/bash)
    backup_if_exists "$XDG_CONFIG_HOME/bash"
    
    # 3. Git 配置 (stow git -> ~/.config/git)
    backup_if_exists "$XDG_CONFIG_HOME/git"
    
    # 4. Tmux 配置 (stow tmux -> ~/.config/tmux)
    backup_if_exists "$XDG_CONFIG_HOME/tmux"
    
    # 5. Fonts (stow fonts -> ~/.local/share/fonts)
    # 注意：如果 ~/.local/share/fonts 已经是一个非链接的普通目录且有文件，stow 可能会报错
    # 这里我们不做暴力删除，而是交给 stow 处理，如果失败请手动检查
    
    cd "$DOTFILES_DIR"
    for pkg in "${STOW_PACKAGES[@]}"; do
        # 检查包是否存在
        if [ -d "$pkg" ]; then
            log_info "Linking package: $pkg"
            # -R: Restow (更新链接)
            # -v: 详细模式
            stow -R -v "$pkg"
        else
            log_warn "包 $pkg 不存在于仓库中，跳过。"
        fi
    done
    
    # 刷新字体缓存 (因为我们刚刚链接了字体)
    log_info "刷新字体缓存..."
    if has_cmd fc-cache; then
        fc-cache -fv "$XDG_DATA_HOME/fonts"
    fi
}

# ==========================================
# 4. 收尾工作
# ==========================================
setup_shell() {
    local zsh_path
    zsh_path="$(which zsh)"
    
    if [ "$SHELL" != "$zsh_path" ]; then
        log_info "正在将默认 Shell 切换为 Zsh..."
        if has_cmd chsh; then
            # 尝试切换，如果失败提示用户手动切换
            chsh -s "$zsh_path" || log_warn "自动切换失败，请稍后运行: chsh -s $zsh_path"
        fi
    else
        log_success "默认 Shell 已经是 Zsh。"
    fi
}

# ==========================================
# 主流程
# ==========================================
main() {
    log_info "=== 开始初始化环境 (Mode: XDG-Strict from dir.txt) ==="
    
    init_xdg_dirs
    install_dependencies
    install_omz_and_plugins
    link_dotfiles
    setup_shell
    
    echo ""
    log_success "=========================================="
    log_success "  Setup Complete! "
    log_success "  1. Restart your terminal."
    log_success "  2. If fonts don't verify, ensure your terminal uses MesloLGS NF."
    log_success "=========================================="
}

main "$@"
