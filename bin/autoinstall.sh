#!/bin/bash
# Semi-auto installation of Archlinux. Assume this script and Dropbox directory is already in /tmp directory
# Steps to be done manually:
#   - restore the ssl certificate (server)
#   - install additional non-free softwares
#   - ssh key and related

#--------------------------------------------------
# helper functions
#--------------------------------------------------
function helper_command(){
    echo -e "DESCRIPTION: Archlinux installation script. Most functionalities requires root permissions"
    echo -e "USAGE: autoinstall.sh FUNCTION-NAME"
    echo -e ""
    echo -e "\tconfigure_base   - configure system after chroot"
    echo -e "\tconfigure_post   - configure system after reboot"
}

function helper_install(){
    args=("$@")
    
    # if not install, return
    if [ "${args[0]}" != "-S" ];then
        yaourt --noconfirm $@ 1> /dev/null
        return
    fi

    # check if install
    for ((i=1; i<=$#-1; i++));do  
        string=`pacman -Qi ${args[i]} 2> /dev/null`
        if [ -z "$string" ];then
            echo "Installing: ${args[i]}"
            yaourt --noconfirm $1 ${args[i]} 1> /dev/null # install
        fi
    done
}

function helper_symlink(){
    args=("$@")
    
    if [ -z $3 ];then
        regex="/.*/p"
    else
        regex=$3
    fi

    # find all files
    files=(`find -L $1 -mindepth 1 -maxdepth 1 | sed -rn "$regex"`)

    # target dir
    $RUNASUSR mkdir -p $2

    for file in ${files[*]}; do
        # strip file name
        file=${file##*/}

        # delete existing
        if [ ! -h $2/$file ];then
            rm -rf $2/$file
        fi

        # make symbol link
        $RUNASUSR ln -sf $1/$file $2/
    done
}

#--------------------------------------------------
# functions in configure_post
#--------------------------------------------------
function setup_package(){
    #--------------------------------------------------
    # Xorg and drivers
    #--------------------------------------------------
    $BUILDCMD -S xorg-server xorg-xinit xorg-server-utils mesa
    $BUILDCMD -S xf86-video-$VIDEODRI xf86-input-synaptics

    #--------------------------------------------------
    # desktop environment
    #--------------------------------------------------
    # gnome-shell essentials
    $BUILDCMD -S gdm gnome-shell gnome-control-center nautilus xdg-user-dirs 

    # look and feel
    $BUILDCMD -Rdd freetype2 fontconfig cairo 2>/dev/null
    $BUILDCMD -S freetype2-ubuntu fontconfig-ubuntu cairo-ubuntu 
    $BUILDCMD -S faenza-icon-theme wqy-microhei

    #--------------------------------------------------
    # others
    #--------------------------------------------------
    $BUILDCMD -S ntfs-3g dosfstools ntp ufw openssh bash-completion nautilus-open-terminal # utils
    $BUILDCMD -S fcitx fcitx-gtk2 fcitx-gtk3 fcitx-configtool # IME
    $BUILDCMD -S gvim ctags # text editor
    $BUILDCMD -S evince poppler-data # pdf
    $BUILDCMD -S file-roller p7zip archive-mounter # archiver
    $BUILDCMD -S pidgin pidgin-lwqq-git irssi skype # IM
    $BUILDCMD -S mpd mpc mplayer-vaapi gnome-mplayer # video and audio
    $BUILDCMD -S eog gimp inkscape # image
    $BUILDCMD -S firefox flashplugin icedtea-web-java7 aliedit # browser
    $BUILDCMD -S texlive-latexextra latex-beamer-ctan rubber-bzr # latex
    $BUILDCMD -S conky-lua lm_sensors hddtemp # conky
    $BUILDCMD -S dropbox nautilus-dropbox #dropbox
    $BUILDCMD -S mendeleydesktop git screen xterm virtualbox # misc
    $BUILDCMD -S scrot xsel setconf # script

    if [ "$SYSTARCH" == "x86_64" ];then # skype on 64bit
        $BUILDCMD -S lib32-libpulse
    fi
}

function setup_sysconf(){
    # fonts
    cp -r $USERHOME/Dropbox/home/sysconf/fontconfig/* /etc/fonts/conf.avail
    cp -r $USERHOME/Dropbox/home/sysconf/fontconfig/* /etc/fonts/conf.d

    # other
    cp $USERHOME/Dropbox/home/sysconf/virtualbox/virtualbox.conf /etc/modules-load.d/virtualbox.conf
    cp $USERHOME/Dropbox/home/sysconf/common/blacklist.conf /etc/modprobe.d/blacklist.conf
    (while :; do echo ""; done ) | sensors-detect

    # ufw
    ufw enable
    ufw default deny

    # systemd services
    systemctl enable gdm
    systemctl enable NetworkManager
    systemctl enable NetworkManager-dispatcher
    systemctl enable hddtemp
    systemctl enable lm_sensors
    systemctl enable ntpd
    systemctl enable ufw
}

function setup_usrconf(){
    # update user directory
    $RUNASUSR xdg-user-dirs-update

    # symbol link   
    helper_symlink $USERHOME/Dropbox/home $USERHOME "/(\.config$|\.local$|\.git$|\.gitignore$|sysconf$)/d;p"
    helper_symlink $USERHOME/Dropbox/home/.config $USERHOME/.config
    helper_symlink $USERHOME/Dropbox/home/.local/share/gnome-shell $USERHOME/.local/share/gnome-shell
    
    # avatar
    cp $USERHOME/Dropbox/home/sysconf/account/avatar-gnome.png /var/lib/AccountsService/icons/$USERNAME
    cp $USERHOME/Dropbox/home/sysconf/account/gnome-account.conf /var/lib/AccountsService/users/$USERNAME
}

function setup_notebook(){
    # power management
    $BUILDCMD -S tlp tlp-rdw 

    # systemd services
    systemctl enable tlp
    systemctl enable tlp-sleep
}

function setup_thinkpad(){
    $BUILDCMD -S thinkfan dkms-acpi_call-git tp_smapi

    # thinkfan configuration
    cp $USERHOME/Dropbox/home/sysconf/thinkfan/modprobe.conf /etc/modprobe.d/thinkfan.conf
    cp $USERHOME/Dropbox/home/sysconf/thinkfan/thinkfan.conf /etc/

    # systemd services
    systemctl enable thinkfan
}

function setup_homeserv(){
    $BUILDCMD -S sage-mathematics
    $BUILDCMD -S lighttpd php-cgi php-gd

    # sage server
    mkdir -p /srv/sage
    chown sagemath:sagemath /srv/sage
    usermod -d /srv/sage sagemath
    cp $USERHOME/Dropbox/home/sysconf/sage/sage-notebook.service /etc/systemd/system/sage-notebook.service

    # web server
    cp $USERHOME/Dropbox/home/sysconf/lighttpd/lighttpd.conf /etc/lighttpd/lighttpd.conf

    # ssh server
    cp $USERHOME/Dropbox/home/sysconf/sshd/sshd_config /etc/ssh/sshd_config

    # systemd services
    systemctl enable sage-notebook
    systemctl enable lighttpd
    systemctl enable sshd

    # ufw port
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
}

#--------------------------------------------------
# main functions
#--------------------------------------------------
function configure_base(){
    #--------------------------------------------------
    # configure pacman
    #--------------------------------------------------
    # configuration files
    cp /tmp/Dropbox/home/sysconf/pacman/mirrorlist  /etc/pacman.d/mirrorlist
    cp /tmp/Dropbox/home/sysconf/pacman/pacman.conf /etc/pacman.conf

    # architecture change
    if [ "$SYSTARCH" != "x86_64" ];then
        sed -i -r "N;N;s|(^\[multilib\].*\n.*\n.*)||" /etc/pacman.conf
    fi

    # install necessary packages
    pacman -Syu --noconfirm linux-headers sudo yajl yaourt

    #--------------------------------------------------
    # configure user
    #--------------------------------------------------
    # add user
    groupadd $USERNAME
    useradd -m -g $USERNAME -G wheel -s /bin/bash $USERNAME

    # setup password
    echo ">>>>>>set password for $USERNAME:"
    passwd $USERNAME

    # configure sudo
    echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers
    
    #--------------------------------------------------
    # set root passwd
    #--------------------------------------------------
    echo ">>>>>>set password for ROOT:"
    passwd

    #--------------------------------------------------
    # system base configuration
    #--------------------------------------------------
    # hostname
    echo "$HOSTNAME" > /etc/hostname

    # locale
    for locale in ${OSLOCALE[*]}; do
        sed -i "s/^#\($locale.*\)/\1/" /etc/locale.gen
    done
    locale-gen
    echo "LANG=${OSLOCALE[0]}" > /etc/locale.conf
    
    # timezone
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

    # hardware clock
    hwclock --systohc --utc

    #--------------------------------------------------
    # ramdisk
    #--------------------------------------------------
    for hook in ${CPIOHOOK[*]}; do
        sed -n "s|\(^HOOKS.* \w\+\)|\1 $hook|p" /etc/mkinitcpio.conf
    done
    mkinitcpio -p linux

    #--------------------------------------------------
    # grub
    #--------------------------------------------------
    # install
    pacman -S --noconfirm grub-bios os-prober
    grub-install --target=i386-pc --recheck $GRUBDEVI

    # configure
    cp /tmp/Dropbox/home/sysconf/common/grub.conf /etc/default/grub 
    grub-mkconfig -o /boot/grub/grub.cfg

    #--------------------------------------------------
    # prepare Dropbox directory
    #--------------------------------------------------
    $RUNASUSR cp -r /tmp/Dropbox $USERHOME/Dropbox
    $RUNASUSR cp /tmp/autoinstall.sh $USERHOME/
}

function configure_post(){
    setup_package
    setup_sysconf
    setup_usrconf

    if [ "$NOTEBOOK" == "1" ];then
        setup_notebook
    fi

    if [ "$THINKPAD" == "1" ];then
        setup_thinkpad
    fi

    if [ "$HOMESERV" == "1" ];then
        setup_homeserv
    fi
}

#--------------------------------------------------
# main
#--------------------------------------------------
# main configuration
USERNAME=lainme 
USERHOME=/home/$USERNAME
HOSTNAME=$USERNAME
SYSTARCH=x86_64
OSLOCALE=("en_US.UTF-8")
TIMEZONE="Asia/Hong_Kong"
CPIOHOOK=()
GRUBDEVI=/dev/sda 
VIDEODRI=intel

# switching configuration
NOTEBOOK=1
THINKPAD=1
HOMESERV=0

# installation commands
BUILDCMD="helper_install"
RUNASUSR="sudo -u $USERNAME" 

if [ -z $1 ];then
    helper_command 
else
    $@
fi
