#!/usr/bin/env bash
set -euo pipefail
# Check OS
if [[ ! -r /etc/os-release ]]; then
	echo "Cannot detect operating system. /etc/os-release is missing." >&2
	exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "fedora" ]]; then
	echo "This script only supports Fedora. Detected ID=${ID:-unknown}." >&2
	exit 1
fi

# Configure repositories and install packages
sudo dnf install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" dnf5-plugins -y
sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo -y
sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release terra-gpg-keys terra-release-extras terra-release-mesa -y
sudo dnf copr enable agriffis/neovim-nightly -y
sudo dnf upgrade --refresh -y
sudo dnf makecache -y
sudo dnf distro-sync -y
sudo dnf install -y @development-tools @c-development awk python3-devel fzf lazygit moreutils git zsh gh neovim ripgrep fd-find btop wget curl eza fastfetch unzip zip 7zip python3 python3-pip deno yt-dlp ncdu oh-my-posh nodejs clang gcc-c++ ninja-build cmake gdb ccache x265 ffmpeg ffmpeg-libs gstreamer1-plugins-{bad-free,bad-freeworld,good,good-extras,ugly,ugly-free} gstreamer1-libav lame x264 openh264 libde265 crudini PackageKit-command-not-found pipx
curl -LsSf https://astral.sh/uv/install.sh | sh
npm config set prefix ~/.local
npm install -g @github/copilot
sudo systemctl enable --now systemd-resolved
virt=$(systemd-detect-virt)
if ! [[ "$virt" == "wsl" || "$virt" == "docker" ]]; then
	sudo dnf install tuned tuned-utils zram-generator -y
	sudo crudini --set /etc/systemd/zram-generator.conf zram0 compression-algorithm zstd
	sudo systemctl daemon-reload
	sudo systemctl enable --now systemd-oomd tuned
	sudo tuned-adm profile balanced
fi
if ! systemd-detect-virt -q; then
	sudo dnf install thermald -y
	sudo systemctl enable --now thermald
fi
# Setup zsh and oh-my-posh
mkdir -p ~/.local/share # Ensure the directory exists for zi and more
sudo chsh -s /usr/bin/zsh "${SUDO_USER:-$USER}"
sh -c "$(curl -fsSL get.zshell.dev)" --
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
wget https://raw.githubusercontent.com/oreactko/linux-setup/refs/heads/main/nvim/lazyvim.json -O ~/.config/nvim/lazyvim.json
wget https://raw.githubusercontent.com/oreactko/linux-setup/refs/heads/main/nvim/lua/config/options.lua -O ~/.config/nvim/lua/config/options.lua
wget https://raw.githubusercontent.com/oreactko/linux-setup/refs/heads/main/home/.theme.omp.json -O ~/.theme.omp.json
curl https://raw.githubusercontent.com/oreactko/linux-setup/refs/heads/main/home/add_zshrc | tee -a ~/.zshrc
if [[ "$virt" == "wsl" ]]; then
	cat <<EOF >>~/.zshrc
export MESA_LOADER_DRIVER_OVERRIDE=d3d12
export GALLIUM_DRIVER=d3d12 
EOF
	sudo crudini --set /etc/wsl.conf interop enabled false
	sudo crudini --set /etc/wsl.conf interop appendWindowsPath false
	sudo crudini --set /etc/wsl.conf automount enabled true
fi
exec zsh
