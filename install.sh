#!/bin/bash
# =============================================================================
# dots-hyprland on Fedora Asahi Remix — M2 MacBook Pro 13" (2022)
# end-4/dots-hyprland install script
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
#
# Do NOT run as root or with sudo.
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Colours and helpers
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERR ]${NC} $1"; exit 1; }
header()  { echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n  $1\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
ask()     { echo -e "${YELLOW}[ASK ]${NC} $1"; }

# -----------------------------------------------------------------------------
# Sanity checks
# -----------------------------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
    error "Do not run this script as root or with sudo. Run as your normal user."
fi

if ! grep -qi "fedora" /etc/os-release 2>/dev/null; then
    warn "This script is written for Fedora Asahi Remix. Proceed at your own risk."
fi

ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    warn "This script targets aarch64 (Apple Silicon). Your arch is: $ARCH"
fi

# -----------------------------------------------------------------------------
# Step selection
# -----------------------------------------------------------------------------
header "dots-hyprland installer — Fedora Asahi / M2 MacBook"
echo ""
echo "This script will:"
echo "  1.  Configure DNF for faster downloads"
echo "  2.  Enable required COPR repositories"
echo "  3.  Install Hyprland and core dependencies"
echo "  4.  Install all dots-hyprland dependencies"
echo "  5.  Build cpptrace from source (required for Quickshell)"
echo "  6.  Build Quickshell from source"
echo "  7.  Clone dots-hyprland and deploy config files"
echo "  8.  Run the dots-hyprland setup script"
echo "  9.  Install fonts (including Nerd Fonts)"
echo "  10. Apply wallpaper fix (disable Quickshell wallpaper layer)"
echo "  11. Enable SDDM"
echo ""
warn "This will overwrite files in ~/.config/. Back up anything important first."
echo ""
ask "Continue? [y/N]"
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# -----------------------------------------------------------------------------
# 1. DNF config
# -----------------------------------------------------------------------------
header "Step 1 — Configure DNF"

if ! grep -q "max_parallel_downloads" /etc/dnf/dnf.conf; then
    info "Adding fastestmirror and parallel downloads to dnf.conf..."
    echo -e "fastestmirror=True\nmax_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf > /dev/null
    success "DNF configured"
else
    info "DNF already configured, skipping"
fi

# -----------------------------------------------------------------------------
# 2. COPR repositories
# -----------------------------------------------------------------------------
header "Step 2 — Enable COPR repositories"

COPRS=(
    "sdegler/hyprland"
    "ririko66z/dots-hyprland"
    "alternateved/eza"
    "atim/starship"
)

for copr in "${COPRS[@]}"; do
    info "Enabling COPR: $copr"
    sudo dnf copr enable "$copr" -y 2>/dev/null && success "$copr enabled" || warn "$copr failed (may already be enabled or no aarch64 build)"
done

warn "Skipping deltacopy/darkly — no aarch64 build available"

info "Refreshing package metadata..."
sudo dnf makecache -q

# -----------------------------------------------------------------------------
# 3. Hyprland and core dependencies
# -----------------------------------------------------------------------------
header "Step 3 — Install Hyprland and core dependencies"

# Note: hyprland-guiutils is the correct package name on Fedora (not hyprland-qtutils)
sudo dnf install -y \
    hyprland \
    hyprland-guiutils \
    hyprsunset \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-kde \
    xdg-desktop-portal-hyprland \
    pipewire \
    pipewire-pulseaudio \
    wireplumber \
    polkit-kde \
    qt6-qtwayland \
    qt5-qtwayland \
    sddm \
    fish

success "Hyprland and core deps installed"

# -----------------------------------------------------------------------------
# 4. dots-hyprland dependencies
# -----------------------------------------------------------------------------
header "Step 4 — Install dots-hyprland dependencies"

info "Core utilities..."
sudo dnf install -y \
    bc coreutils cliphist cmake curl wget2 \
    ripgrep jq xdg-utils rsync yq

info "Audio..."
sudo dnf install -y \
    cava pavucontrol wireplumber playerctl \
    libdbusmenu-gtk3-devel

info "Backlight and location..."
sudo dnf install -y --setopt=install_weak_deps=False \
    brightnessctl ddcutil geoclue2

info "Fonts and themes (skipping darkly — no aarch64)..."
# Note: rubik-fonts doesn't exist; use google-rubik-vf-fonts
sudo dnf install -y \
    eza \
    starship \
    jetbrains-mono-fonts \
    google-noto-emoji-fonts \
    google-rubik-vf-fonts \
    bibata-cursor-themes 2>/dev/null || \
sudo dnf install -y \
    eza \
    starship \
    jetbrains-mono-fonts \
    google-noto-emoji-fonts \
    google-rubik-vf-fonts

info "Screen capture..."
sudo dnf install -y \
    slurp tesseract wf-recorder \
    tesseract-langpack-eng \
    imagemagick

info "KDE and system integration..."
sudo dnf install -y \
    bluedevil gnome-keyring NetworkManager \
    plasma-nm polkit-kde dolphin \
    plasma-systemsettings kde-gtk-config \
    qt5ct qt6ct \
    adw-gtk3-theme \
    breeze-icon-theme \
    kf6-breeze-icons

info "Python environment..."
sudo dnf install -y --setopt=install_weak_deps=False \
    python3 python3.12 python3-devel python3.12-devel \
    clang uv \
    gtk4-devel libadwaita-devel libsoup3-devel \
    libportal-gtk4 gobject-introspection-devel

info "Miscellaneous tools..."
sudo dnf install -y \
    foot kitty fuzzel wlogout hyprlock hypridle \
    swww imagemagick ffmpeg \
    glib2-devel fd-find socat \
    wtype upower

info "DNF version lock plugin..."
sudo dnf install -y python3-dnf-plugin-versionlock

success "All dots-hyprland dependencies installed"

# -----------------------------------------------------------------------------
# 5. Build cpptrace from source
# -----------------------------------------------------------------------------
header "Step 5 — Build cpptrace from source"

info "Installing cpptrace build dependencies..."
sudo dnf install -y libunwind-devel cmake ninja-build git

if [ -d "$HOME/cpptrace" ]; then
    warn "~/cpptrace already exists, skipping clone"
else
    info "Cloning cpptrace..."
    git clone https://github.com/jeremy-rifkin/cpptrace.git ~/cpptrace
fi

info "Building cpptrace with libunwind support..."
cd ~/cpptrace
rm -rf build
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCPPTRACE_UNWIND_WITH_LIBUNWIND=ON
cmake --build build
sudo cmake --install build
cd ~

success "cpptrace built and installed"

# -----------------------------------------------------------------------------
# 6. Build Quickshell from source
# -----------------------------------------------------------------------------
header "Step 6 — Build Quickshell from source"

info "Installing Quickshell build dependencies..."
sudo dnf install -y \
    rpm-build rpmdevtools \
    qt6-qtbase-devel qt6-qtbase-private-devel \
    qt6-qtdeclarative-devel \
    qt6-qt5compat-devel qt6-qtwayland-devel \
    qt6-qtsvg-devel qt6-qtshadertools-devel \
    kf6-kirigami-devel \
    wayland-devel wayland-protocols-devel \
    pipewire-devel pulseaudio-libs-devel \
    pam-devel hyprlang-devel \
    breakpad-static breakpad-devel \
    mesa-libgbm-devel libdrm-devel \
    jemalloc-devel polkit-devel \
    CLI11-devel spirv-tools spirv-tools-devel

info "Setting up RPM build tree..."
rpmdev-setuptree

info "Installing spectool..."
sudo dnf install -y rpmdevtools

# Clone dots repo if not already present
if [ ! -d "$HOME/.cache/dots-hyprland" ]; then
    info "Cloning dots-hyprland repo..."
    git clone https://github.com/end-4/dots-hyprland.git \
        ~/.cache/dots-hyprland \
        --filter=blob:none --recurse-submodules
else
    info "dots-hyprland repo already exists at ~/.cache/dots-hyprland"
fi

info "Copying spec files..."
cp ~/.cache/dots-hyprland/sdata/dist-fedora/SPECS/hyprland-qt-support.spec ~/rpmbuild/SPECS/
cp ~/.cache/dots-hyprland/sdata/dist-fedora/SPECS/quickshell-git.spec ~/rpmbuild/SPECS/

info "Downloading sources..."
spectool -g -R ~/rpmbuild/SPECS/hyprland-qt-support.spec
spectool -g -R ~/rpmbuild/SPECS/quickshell-git.spec

info "Building hyprland-qt-support..."
sudo dnf builddep -y ~/rpmbuild/SPECS/hyprland-qt-support.spec
rpmbuild -bb ~/rpmbuild/SPECS/hyprland-qt-support.spec
sudo dnf install -y ~/rpmbuild/RPMS/aarch64/hyprland-qt-support*.rpm

info "Building quickshell-git (this will take several minutes)..."
sudo dnf builddep -y ~/rpmbuild/SPECS/quickshell-git.spec
rpmbuild -bb ~/rpmbuild/SPECS/quickshell-git.spec
sudo dnf install -y ~/rpmbuild/RPMS/aarch64/quickshell-git*.rpm

info "Locking quickshell version..."
sudo dnf versionlock add quickshell-git

success "Quickshell built and installed"

# -----------------------------------------------------------------------------
# 7. Deploy config files
# -----------------------------------------------------------------------------
header "Step 7 — Deploy config files"

warn "This will overwrite files in ~/.config/. Press Ctrl+C now to abort, or Enter to continue."
read -r

info "Syncing dotfiles..."
cd ~/.cache/dots-hyprland
rsync -av --exclude='.git' dots/ ~/
rsync -av dots-extra/fedora/ ~/

success "Config files deployed"

# -----------------------------------------------------------------------------
# 8. Run setup script
# -----------------------------------------------------------------------------
header "Step 8 — Run dots-hyprland setup script"

echo ""
info "The setup script will now run interactively."
echo ""
echo "When prompted, here is what to do:"
echo ""
echo "  aarch64 warning          → press Enter to proceed"
echo "  Fedora community notice  → press Enter to proceed"
echo "  ydotool service fails    → type 'i' to ignore"
echo "  darkly config fails      → type 'i' to ignore"
echo "  OUTDATED warning         → press Enter to proceed"
echo "  Package install prompts  → type 'y'"
echo "  Replace existing venv?   → type 'no'"
echo "  Backup clashing files?   → type 'y'"
echo "  All other prompts        → type 'y'"
echo ""
ask "Press Enter when ready to start the setup script..."
read -r

cd ~/.cache/dots-hyprland
./setup install-setups
./setup install

success "Setup script completed"

# -----------------------------------------------------------------------------
# 9. Fonts
# -----------------------------------------------------------------------------
header "Step 9 — Install fonts"

info "Installing Material Symbols Rounded (required for UI icons)..."
sudo dnf install -y google-material-symbols-vf-rounded-fonts

info "Installing JetBrains Mono Nerd Font (required for cheatsheet key symbols)..."
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
if [ ! -d "JetBrainsMono" ]; then
    curl -LO "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    unzip -q JetBrainsMono.zip -d JetBrainsMono
    rm JetBrainsMono.zip
fi
cd ~

info "Rebuilding font cache..."
fc-cache -fv

success "Fonts installed"

# -----------------------------------------------------------------------------
# 10. Fix wallpaper double-rendering
# -----------------------------------------------------------------------------
header "Step 10 — Fix wallpaper rendering"

BACKGROUND_QML="$HOME/.config/quickshell/ii/modules/ii/background/Background.qml"

if [ -f "$BACKGROUND_QML" ]; then
    info "Disabling Quickshell's wallpaper layer (prevents double wallpaper with swww)..."
    # Replace the visible line for the StyledImage wallpaper element
    sed -i 's/visible: opacity > 0 && !blurLoader\.active/visible: false/' "$BACKGROUND_QML"
    success "Background.qml patched"
else
    warn "Background.qml not found at expected path, skipping"
fi

info "Adding swww-daemon to autostart..."
mkdir -p ~/.config/hypr/custom
if ! grep -q "swww-daemon" ~/.config/hypr/custom/execs.conf 2>/dev/null; then
    echo "exec-once = swww-daemon" >> ~/.config/hypr/custom/execs.conf
    success "swww-daemon added to autostart"
else
    info "swww-daemon already in autostart"
fi

# -----------------------------------------------------------------------------
# 11. Post-install fixes
# -----------------------------------------------------------------------------
header "Step 11 — Post-install fixes"

info "Creating missing translation file..."
mkdir -p ~/.config/quickshell/ii/translations
if [ ! -f ~/.config/quickshell/ii/translations/en_AU.json ]; then
    echo '{}' > ~/.config/quickshell/ii/translations/en_AU.json
    success "Translation file created"
fi

info "Removing conflicting notification daemons..."
sudo dnf remove -y dunst mako 2>/dev/null || true

info "Enabling SDDM..."
sudo systemctl enable sddm
success "SDDM enabled"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
header "Installation complete!"

echo ""
success "Everything is installed. Reboot to start Hyprland."
echo ""
echo "  sudo reboot"
echo ""
echo "At the SDDM login screen:"
echo "  → Click the gear icon ⚙"
echo "  → Select 'Hyprland (non-uwsm)'"
echo ""
echo "Essential keybinds:"
echo "  Super + /          Show all keybinds"
echo "  Super + Enter      Terminal"
echo "  Super + Space      App launcher"
echo "  Super + I          Settings"
echo "  Ctrl + Super + T   Wallpaper picker"
echo ""
echo "Set your wallpaper with swww:"
echo "  swww img /path/to/wallpaper.jpg --resize crop"
echo ""
echo "Theme colours to wallpaper:"
echo "  matugen image /path/to/wallpaper.jpg"
echo ""
warn "On first login, the theme switcher may not work."
echo "Fix it by running:"
echo "  cd ~/.cache/dots-hyprland && ./setup install"
echo "  → Select option 6: Update config files with exclusions"
echo ""
