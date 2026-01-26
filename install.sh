#!/bin/bash

# ==========================================
# 全局配置与安全检查
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

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# 脚本所在目录
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 需要 Stow 的包列表
STOW_PACKAGES=("zsh" "bash" "git" "tmux" "fonts")

# 数据目录定义
OMZ_DIR="$XDG_DATA_HOME/oh-my-zsh"
TPM_DIR="$XDG_DATA_HOME/tmux/plugins/tpm"

# ==========================================
# 辅助函数
# ==========================================
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

backup_if_exists() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        log_warn "发现冲突配置目录: $target，正在备份..."
        mv "$target" "${target}.backup.$(date +%s)"
    fi
}

# ==========================================
# 初始化
# ==========================================
init_xdg_dirs() {
    log_info "正在初始化 XDG 目录结构..."
    mkdir -p "$XDG_CONFIG_HOME"
    mkdir -p "$XDG_DATA_HOME"
    mkdir -p "$XDG_STATE_HOME"
    mkdir -p "$XDG_CACHE_HOME"
    mkdir -p "$XDG_DATA_HOME/fonts"
    mkdir -p "$XDG_CACHE_HOME/oh-my-zsh"
    mkdir -p "$HOME/workspace"
    
    # 预创建 Tmux 插件目录
    mkdir -p "$XDG_DATA_HOME/tmux/plugins"
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
# 清理 Home 目录
# ==========================================
cleanup_home_clutter() {
    log_info "正在移除垃圾文件..."
    
    local garbage_files=(
        ".bashrc"
        ".profile"
        ".bash_profile"
        ".bash_logout"
        ".bash_history"
        ".lesshst"
        ".wget-hsts"
        ".sudo_as_admin_successful"
        ".zcompdump"
        ".zsh_history" 
        ".motd_legal"
    )

    for file in "${garbage_files[@]}"; do
        if [ -f "$HOME/$file" ] || [ -h "$HOME/$file" ]; then
            log_warn "正在删除遗留文件: ~/$file"
            rm -f "$HOME/$file"
        fi
    done
}

# ==========================================
# 插件安装
# ==========================================
install_omz_and_plugins() {
    # A. 安装 Oh My Zsh
    if [ -d "$OMZ_DIR" ]; then
        log_success "Oh My Zsh 已存在于 $OMZ_DIR"
    else
        log_info "正在克隆 Oh My Zsh 到 $OMZ_DIR ..."
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR"
    fi

    # B. 安装 Powerlevel10k
    local p10k_dir="${OMZ_DIR}/custom/themes/powerlevel10k"
    if [ ! -d "$p10k_dir" ]; then
        log_info "正在安装 Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
    fi

    # C. 安装 Zsh 插件
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

install_tpm() {
    if [ -d "$TPM_DIR" ]; then
        log_success "Tmux Plugin Manager (TPM) 已存在于 $TPM_DIR"
    else
        log_info "正在安装 Tmux Plugin Manager 到 $TPM_DIR ..."
        mkdir -p "$(dirname "$TPM_DIR")"
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
        log_success "TPM 安装完成。"
    fi
}

# ==========================================
# Stow
# ==========================================
link_dotfiles() {
    log_info "开始执行 Stow 链接配置..."
    
    # 这里主要处理 .config 下可能存在的默认目录
    backup_if_exists "$HOME/.zshenv"
    backup_if_exists "$XDG_CONFIG_HOME/zsh"
    backup_if_exists "$XDG_CONFIG_HOME/bash"
    backup_if_exists "$XDG_CONFIG_HOME/git"
    backup_if_exists "$XDG_CONFIG_HOME/tmux"
    
    cd "$DOTFILES_DIR"
    for pkg in "${STOW_PACKAGES[@]}"; do
        if [ -d "$pkg" ]; then
            log_info "Linking package: $pkg"
            stow -R -v "$pkg"
        else
            log_warn "包 $pkg 不存在于仓库中，跳过。"
        fi
    done
    
    log_info "刷新字体缓存..."
    if has_cmd fc-cache; then
        fc-cache -fv "$XDG_DATA_HOME/fonts"
    fi
}

# ==========================================
# 切换 Shell
# ==========================================
setup_shell() {
    local zsh_path
    zsh_path="$(which zsh)"
    
    if [ "$SHELL" != "$zsh_path" ]; then
        log_info "正在将默认 Shell 切换为 Zsh..."
        if has_cmd chsh; then
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
    log_info "=== 开始初始化环境  ==="
    
    init_xdg_dirs
    install_dependencies
    cleanup_home_clutter 
    install_omz_and_plugins
    install_tpm        
    link_dotfiles
    setup_shell
    
    echo ""
    log_success "=========================================="
    log_success "  初始化完毕 "
    log_success "  1. 重启终端"
    log_success "  2. 打开 tmux 按下前缀+I来下载文件"
    log_success "=========================================="
}

main "$@"
