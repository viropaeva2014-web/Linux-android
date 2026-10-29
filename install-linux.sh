#!/data/data/com.termux/files/usr/bin/bash
#
# Termux Linux Installer
# A simple interactive script to install Linux distributions
# inside Termux using proot-distro, with optional XFCE4 GUI via Termux-X11.
#

set -e

# ---------- Colors ----------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---------- 1. Termux check ----------
if [ ! -d "/data/data/com.termux/files/usr" ]; then
    error "This script is intended to run only inside Termux."
    exit 1
fi

# ---------- 2. Base packages ----------
log "Updating package lists..."
pkg update -y && pkg upgrade -y

log "Installing proot-distro..."
pkg install proot-distro -y

# ---------- 3. Distribution menu ----------
echo ""
log "Available distributions:"
echo "  1) Ubuntu (default)"
echo "  2) Debian"
echo "  3) Arch Linux"
echo "  4) OpenSUSE"
echo "  5) Alpine Linux"
echo "  6) Fedora"
echo "  7) Void Linux"
echo "  8) Manjaro"
echo ""

read -p "Select a distribution [1-8, Enter for Ubuntu]: " choice

case $choice in
    1|"") DISTRO="ubuntu" ;;
    2)    DISTRO="debian" ;;
    3)    DISTRO="archlinux" ;;
    4)    DISTRO="opensuse" ;;
    5)    DISTRO="alpine" ;;
    6)    DISTRO="fedora" ;;
    7)    DISTRO="void" ;;
    8)    DISTRO="manjaro" ;;
    *)    warn "Invalid choice. Defaulting to Ubuntu."; DISTRO="ubuntu" ;;
esac

log "Selected distribution: $DISTRO"

# ---------- 4. Boot mode menu ----------
echo ""
log "Select a boot mode:"
echo "  1) Terminal only (plain Linux console)"
echo "  2) Graphical desktop (XFCE4 + Termux-X11)"
echo ""

read -p "Select a mode [1-2, Enter for terminal]: " mode_choice

# ---------- 5. Install distribution ----------
log "Installing $DISTRO. This may take a while..."
if ! proot-distro install "$DISTRO"; then
    error "Failed to install $DISTRO. Check your internet connection and try again."
    exit 1
fi
log "$DISTRO installed successfully."

# ---------- 6. Optional GUI setup ----------
if [ "$mode_choice" = "2" ]; then
    log "Setting up the graphical environment..."

    log "Installing Termux-X11 and audio dependencies..."
    pkg install x11-repo -y
    pkg install termux-x11-nightly -y
    pkg install pulseaudio -y

    log "Installing XFCE4 inside $DISTRO..."
    proot-distro login "$DISTRO" --shared-tmp -- /bin/bash -c "
        apt update && apt upgrade -y
        apt install -y xfce4 xfce4-goodies xfce4-terminal dbus-x11
    "

    # Create a launcher script
    cat > ~/start-gui.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Launch Termux-X11 and start XFCE4 inside the selected proot-distro.
DISTRO="${1:-ubuntu}"

termux-x11 :1 &
sleep 1

proot-distro login "$DISTRO" --shared-tmp -- /bin/bash -c "
    export DISPLAY=:1
    export PULSE_SERVER=127.0.0.1
    startxfce4
"
EOF
    chmod +x ~/start-gui.sh

    log "GUI setup complete."
    echo -e "${YELLOW}  Launch it later with: ~/start-gui.sh $DISTRO${NC}"
    echo -e "${YELLOW}  Don't forget to install the Termux-X11 app on your device.${NC}"
else
    log "Boot mode: terminal only. GUI packages were not installed."
fi

# ---------- 7. Enter the system ----------
echo ""
read -p "Enter $DISTRO now? (y/n): " login_choice
if [[ "$login_choice" =~ ^[Yy]$ ]]; then
    if [ "$mode_choice" = "2" ]; then
        log "Starting $DISTRO with the graphical desktop..."
        ~/start-gui.sh "$DISTRO"
    else
        log "Starting $DISTRO (terminal)..."
        proot-distro login "$DISTRO"
    fi
else
    log "Done. To enter later, run:"
    if [ "$mode_choice" = "2" ]; then
        echo -e "${YELLOW}  ~/start-gui.sh $DISTRO${NC}"
    else
        echo -e "${YELLOW}  proot-distro login $DISTRO${NC}"
    fi
fi