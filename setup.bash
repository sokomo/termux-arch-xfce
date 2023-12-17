#!/bin/bash

# Unofficial Bash Strict Mode
set -euo pipefail
IFS=$'\n\t'

finish() {
  local ret=$?
  if [ ${ret} -ne 0 ] && [ ${ret} -ne 130 ]; then
    echo
    echo "ERROR: Failed to setup XFCE on Termux."
    echo "Please refer to the error message(s) above"
  fi
}

trap finish EXIT

clear

echo ""
echo "This script will install XFCE Desktop in Termux along with a ArchLinux proot"
echo ""
read -r -p "Please enter username for proot installation: " username </dev/tty
read -r -p "Please enter GID for proot installation: " user_gid </dev/tty
read -r -p "Please enter UID for proot installation: " user_uid </dev/tty

_DISTRO_NAME="archlinux"


_run_proot_cmd() {
  proot-distro login "${_DISTRO_NAME}" --shared-tmp -- env DISPLAY=:1.0 $@
}

setup_proot() {
  #Install Archlinux proot
  proot-distro install "${_DISTRO_NAME}"
  _run_proot_cmd pacman-key --init
  _run_proot_cmd pacman -Syu --needed --noconfirm sudo curl jq flameshot ttf-liberation ttf-cascadia-code

  #Create user
  _run_proot_cmd groupadd -g ${user_gid} $username
  _run_proot_cmd useradd -m -g ${user_gid} -u ${user_uid} -G wheel,users -s /bin/bash "$username"

  #Add user to sudoers
  chmod u+rw $HOME/../usr/var/lib/proot-distro/installed-rootfs/${_DISTRO_NAME}/etc/sudoers
  #echo "wheel ALL=(ALL) NOPASSWD:ALL" | tee -a $HOME/../usr/var/lib/proot-distro/installed-rootfs/${_DISTRO_NAME}/etc/sudoers > /dev/null
  #chmod u-w  $HOME/../usr/var/lib/proot-distro/installed-rootfs/${_DISTRO_NAME}/etc/sudoers

  #Set proot DISPLAY
  echo "export DISPLAY=:1.0" >> $HOME/../usr/var/lib/proot-distro/installed-rootfs/${_DISTRO_NAME}/home/$username/.bashrc

  #Set proot aliases
  echo "
  alias virgl='GALLIUM_DRIVER=virpipe '
  alias start='echo "please run from termux, not ${_DISTRO_NAME} proot."'
  " >> $HOME/../usr/var/lib/proot-distro/installed-rootfs/${_DISTRO_NAME}/home/$username/.bashrc

  #Set proot timezone
  timezone=$(getprop persist.sys.timezone)
  _run_proot_cmd rm /etc/localtime
  _run_proot_cmd ln -sfv ../usr/share/zoneinfo/$timezone /etc/localtime
}

setup_xfce() {
  #Install xfce4 desktop and additional packages
  pkg install git neofetch virglrenderer-android papirus-icon-theme xfce4 xfce4-goodies pavucontrol-qt wmctrl netcat-openbsd -y

  #Create .bashrc
  # cp $HOME/../usr/var/lib/proot-distro/installed-rootfs/debian/etc/skel/.bashrc $HOME/.bashrc

  #Enable Sound
  echo "
pulseaudio --start --exit-idle-time=-1
pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1
" > $HOME/.sound

  echo "
source .sound" >> .bashrc

  #Set aliases
  echo "
alias ${_DISTRO_NAME}='proot-distro login ${_DISTRO_NAME} --user $username --shared-tmp'
" >> $HOME/.bashrc

  cat <<'EOF' > ../usr/bin/prun
#!/bin/bash
varname=$(basename $HOME/../usr/var/lib/proot-distro/installed-rootfs/${_DISTRO_NAME}/home/*)
proot-distro login ${_DISTRO_NAME} --user $varname --shared-tmp -- env DISPLAY=:1.0 $@

EOF
  chmod +x ../usr/bin/prun

  cat <<'EOF' > ../usr/bin/cp2menu
#!/bin/bash

cd

user_dir="../usr/var/lib/proot-distro/installed-rootfs/${_DISTRO_NAME}/home/"

# Get the username from the user directory
username=$(basename "$user_dir"/*)

action=$(zenity --list --title="Choose Action" --text="Select an action:" --radiolist --column="" --column="Action" TRUE "Copy .desktop file" FALSE "Remove .desktop file")

if [[ -z $action ]]; then
  zenity --info --text="No action selected. Quitting..." --title="Operation Cancelled"
  exit 0
fi

if [[ $action == "Copy .desktop file" ]]; then
  selected_file=$(zenity --file-selection --title="Select .desktop File" --file-filter="*.desktop" --filename="../usr/var/lib/proot-distro/installed-rootfs/debian/usr/share/applications")

  if [[ -z $selected_file ]]; then
    zenity --info --text="No file selected. Quitting..." --title="Operation Cancelled"
    exit 0
  fi

  desktop_filename=$(basename "$selected_file")

  cp "$selected_file" "../usr/share/applications/"
  sed -i "s/^Exec=\(.*\)$/Exec=proot-distro login debian --user $username --shared-tmp -- env DISPLAY=:1.0 \1/" "../usr/share/applications/$desktop_filename"

  zenity --info --text="Operation completed successfully!" --title="Success"
elif [[ $action == "Remove .desktop file" ]]; then
  selected_file=$(zenity --file-selection --title="Select .desktop File to Remove" --file-filter="*.desktop" --filename="../usr/share/applications")

  if [[ -z $selected_file ]]; then
    zenity --info --text="No file selected for removal. Quitting..." --title="Operation Cancelled"
    exit 0
  fi

  desktop_filename=$(basename "$selected_file")

  rm "$selected_file"

  zenity --info --text="File '$desktop_filename' has been removed successfully!" --title="Success"
fi

EOF
  chmod +x ../usr/bin/cp2menu

  echo "[Desktop Entry]
Version=1.0
Type=Application
Name=cp2menu
Comment=
Exec=cp2menu
Icon=edit-move
Categories=System;
Path=
Terminal=false
StartupNotify=false
" > $HOME/Desktop/cp2menu.desktop 
  chmod +x $HOME/Desktop/cp2menu.desktop
  mv $HOME/Desktop/cp2menu.desktop $HOME/../usr/share/applications

  # #App Installer Utility
  # git clone https://github.com/phoenixbyrd/App-Installer.git
  # mv $HOME/App-Installer $HOME/.App-Installer
  # chmod +x $HOME/.App-Installer/*

  echo "[Desktop Entry]
Version=1.0
Type=Application
Name=App Installer
Comment=
Exec=/data/data/com.termux/files/home/.App-Installer/app-installer
Icon=package-install
Categories=System;
Path=
Terminal=false
StartupNotify=false
" > $HOME/Desktop/App-Installer.desktop
  chmod +x $HOME/Desktop/App-Installer.desktop
  cp $HOME/Desktop/App-Installer.desktop $HOME/../usr/share/applications

}

setup_termux_x11() {
  # Install Termux-X11
  # sed -i '12s/^#//' $HOME/.termux/termux.properties

  # wget https://github.com/phoenixbyrd/Termux_XFCE/raw/main/termux-x11.deb
  # dpkg -i termux-x11.deb
  # rm termux-x11.deb
  # apt-mark hold termux-x11-nightly
  pkg in x11-repo && pkg in termux-x11-nightly

  curl -Lsf "https://github.com/sokomo/termux-arch-xfce/raw/main/files/termux-x11-arm64-v8a-debug.zip" | bsdtar -x
  mv app-arm64-v8a-debug.apk $HOME/storage/downloads/termux-x11.apk
  termux-open $HOME/storage/downloads/termux-x11.apk

  #Create kill_termux_x11.desktop
  echo "[Desktop Entry]
Version=1.0
Type=Application
Name=Kill Termux X11
Comment=
Exec=kill_termux_x11
Icon=system-shutdown
Categories=System;
Path=
StartupNotify=false
" > $HOME/Desktop/kill_termux_x11.desktop
  chmod +x $HOME/Desktop/kill_termux_x11.desktop
  mv $HOME/Desktop/kill_termux_x11.desktop $HOME/../usr/share/applications

#Create XFCE Start and Shutdown
  cat <<'EOF' > start
#!/bin/bash

MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.3COMPAT MESA_GLES_VERSION_OVERRIDE=3.2 virgl_test_server_android --angle-gl & > /dev/null 2>&1
sleep 1
XDG_RUNTIME_DIR=${TMPDIR} termux-x11 :1.0 &
sleep 1
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 1
env DISPLAY=:1.0 GALLIUM_DRIVER=virpipe dbus-launch --exit-with-session xfce4-session & > /dev/null 2>&1

sleep 5
process_id=$(ps -aux | grep '[x]fce4-screensaver' | awk '{print $2}')
kill "$process_id" > /dev/null 2>&1

EOF

  chmod +x start
  mv start $HOME/../usr/bin

#Shutdown Utility
  cat <<'EOF' > $HOME/../usr/bin/kill_termux_x11
#!/bin/bash

# # Check if Apt, dpkg, or Nala is running in Termux or Proot
# if pgrep -f 'apt|apt-get|dpkg|nala'; then
#   zenity --info --text="Software is currently installing in Termux or Proot. Please wait for this processes to finish before continuing."
#   exit 1
# fi

# Get the process IDs of Termux-X11 and XFCE sessions
termux_x11_pid=$(pgrep -f "/system/bin/app_process / com.termux.x11.Loader :1.0")
xfce_pid=$(pgrep -f "xfce4-session")

# Check if the process IDs exist
if [ -n "$termux_x11_pid" ] && [ -n "$xfce_pid" ]; then
  # Kill the processes
  kill -9 "$termux_x11_pid" "$xfce_pid"
  zenity --info --text="Termux-X11 and XFCE sessions closed."
else
  zenity --info --text="Termux-X11 or XFCE session not found."
fi

info_output=$(termux-info)
pid=$(echo "$info_output" | grep -o 'TERMUX_APP_PID=[0-9]\+' | awk -F= '{print $2}')
kill "$pid"

exit 0

EOF

  chmod +x $HOME/../usr/bin/kill_termux_x11
}

setup_proot
setup_xfce
setup_termux_x11

# rm setup.sh
source .bashrc
termux-reload-settings

########
##Finish ##
########

clear -x
echo ""
echo ""
echo "Setup completed successfully!"
echo ""
echo "You can now connect to your Termux XFCE4 Desktop to open the desktop use the command start"
echo ""
echo "This will start the termux-x11 server in termux and start the XFCE Desktop and then open the installed Termux-X11 app."
echo ""
echo "To exit, double click the Kill Termux X11 icon on the desktop."
echo ""
echo "Enjoy your Termux XFCE4 Desktop experience!"
echo ""
echo ""
