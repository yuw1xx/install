#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

LOG_FILE="/tmp/linux_setup.log"

> "$LOG_FILE"

echo -e "${BLUE}=======================================================${NC}"
echo -e "${GREEN}    Starting Ultimate Linux Setup Script    ${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo -e "${YELLOW}Detailed logs are being saved to: $LOG_FILE${NC}\n"

trap 'echo -e "\n${RED}[ ERROR ] An unexpected error occurred. Check $LOG_FILE for details.${NC}"; exit 1' ERR
set -e

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

run_step() {
    local message="$1"
    shift
    
    printf "${BLUE}::${NC} %-50s " "$message"
    
    "$@" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    
    local spinstr='|/-\'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "[%c]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\b\b\b"
    done
    
    # Wait for the background process to finish and get its exit code
    wait $pid
    if [ $? -eq 0 ]; then
        printf "${GREEN}[ DONE ]${NC}\n"
    else
        printf "${RED}[ FAIL ]${NC}\n"
        echo -e "${RED}--> Step failed. Please check $LOG_FILE for exact errors.${NC}"
        exit 1
    fi
}

echo -e "\n${YELLOW}Phase 1: System Preparation${NC}"

if command -v apt &> /dev/null; then
    run_step "Detected Debian/Ubuntu. Updating APT" sudo apt-get update -y
    run_step "Installing Flatpak & Curl" sudo apt-get install -y flatpak curl
elif command -v dnf &> /dev/null; then
    run_step "Detected Fedora/RHEL. Installing Flatpak" sudo dnf install -y flatpak curl
elif command -v pacman &> /dev/null; then
    run_step "Detected Arch. Updating Pacman" sudo pacman -Sy --noconfirm
    run_step "Installing Flatpak & Curl" sudo pacman -S --noconfirm flatpak curl
elif command -v zypper &> /dev/null; then
    run_step "Detected openSUSE. Refreshing Zypper" sudo zypper refresh
    run_step "Installing Flatpak & Curl" sudo zypper install -y flatpak curl
else
    echo -e "${RED}[ FAIL ] Could not detect package manager. Install Flatpak manually.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Phase 2: Flatpak Application Setup${NC}"

run_step "Adding Flathub Repository" sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

FLATPAK_APPS=(
    "io.bassi.Amberol"
    "cc.arduino.IDE2"
    "io.github.kolunmi.Bazaar"
    "hu.kramo.Cartridges"
    "com.discordapp.Discord"
    "com.nextcloud.desktopclient.nextcloud"
    "net.davidotek.pupgui2"         
    "org.vinegarhq.Sober"           
    "com.valvesoftware.Steam"
    "app.zen_browser.zen"
    "com.google.AndroidStudio"      
    "org.onlyoffice.desktopeditors" 
)

for app in "${FLATPAK_APPS[@]}"; do
    # Extract just the last part of the app ID (e.g., "Discord") for a cleaner display
    app_name=$(echo "$app" | awk -F. '{print $NF}')
    run_step "Installing $app_name" sudo flatpak install -y flathub "$app"
done

echo -e "\n${YELLOW}Phase 3: Portable Applications${NC}"

run_step "Creating ~/Applications directory" mkdir -p ~/Applications

# Note: Update this URL to the official Fluxer AppImage release when available
FLUXER_URL="https://fluxer.app/download/linux-appimage"
run_step "Downloading Fluxer AppImage" curl -sL "$FLUXER_URL" -o ~/Applications/Fluxer.AppImage

run_step "Making Fluxer executable" chmod +x ~/Applications/Fluxer.AppImage

# Create a function to write the desktop file so we can pass it to run_step safely
create_desktop_file() {
cat <<EOF > ~/.local/share/applications/fluxer.desktop
[Desktop Entry]
Name=Fluxer
Exec=$HOME/Applications/Fluxer.AppImage
Type=Application
Categories=Network;Chat;
EOF
}
run_step "Creating Fluxer desktop shortcut" create_desktop_file

echo -e "\n${BLUE}=======================================================${NC}"
echo -e "${GREEN}  Installation Complete! Zero Snaps Installed.  ${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo -e "You can review the full installation log at: ${YELLOW}$LOG_FILE${NC}"
echo -e "Please ${RED}reboot your computer${NC} so all application icons appear in your menu.\n"
