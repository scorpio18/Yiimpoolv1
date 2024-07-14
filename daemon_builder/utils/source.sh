#!/bin/env bash

# This is the source file that compiles coin daemon.
#
# Author: Afiniel
#
# It uses:
#  Berkeley 4.8 with autogen.sh file.
#  Berkeley 5.1 with autogen.sh file.
#  Berkeley 5.3 with autogen.sh file.
#  Berkeley 6.2 with autogen.sh file.
#  makefile.unix file.
#  CMake file.
#  UTIL folder contains BULD.sh file.
#  precompiled coin. NEED TO BE LINUX Version!
#
# Updated: 2021-04-13

source /etc/daemonbuilder.sh
source /etc/functions.sh
source $STORAGE_ROOT/daemon_builder/.daemon_builder.my.cnf
source $STORAGE_ROOT/daemon_builder/conf/info.sh

YIIMPOLL=/etc/yiimpool.conf
if [[ -f "$YIIMPOLL" ]]; then
    source /etc/yiimpool.conf
    YIIMPCONF=true
fi

CREATECOIN=true

# Set what we need
now=$(date +"%m_%d_%Y")

# Sets the number of CPU cores to use for compiling.
MIN_CPUS_FOR_COMPILATION=3

if ! NPROC=$(nproc); then
    echo -e "\e[31mError: \e[33mnproc command not found. Failed to run.\e[0m"
    exit 1
fi

if [[ "$NPROC" -le "$MIN_CPUS_FOR_COMPILATION" ]]; then
    NPROC=1
else
    NPROC=$((NPROC - 2))
fi


# Create the temporary installation directory if it doesn't already exist.
echo
echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
echo -e "$CYAN Creating temporary installation directory if it doesn't already exist. 			${NC}"
echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"

source $STORAGE_ROOT/daemon_builder/.daemon_builder.my.cnf

if [[ ! -e "$STORAGE_ROOT/daemon_builder/temp_coin_builds" ]]; then
    sudo mkdir -p $STORAGE_ROOT/daemon_builder/temp_coin_builds
else
    sudo rm -rf $STORAGE_ROOT/daemon_builder/temp_coin_builds/*
    echo
    echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
    echo -e "$GREEN   temp_coin_builds already exists.... Skipping  								${NC}"
    echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
fi
# Just double checking folder permissions
sudo setfacl -m u:${USERSERVER}:rwx $STORAGE_ROOT/daemon_builder/temp_coin_builds
cd $STORAGE_ROOT/daemon_builder/temp_coin_builds

# Gitcoin coin information.
input_box "Coin Information" \
"Please enter the Coin Symbol. Example: BTC
\n\n*Paste press CTRL+RIGHT mouse button.
\n\nCoin Name:" \
"" \
coin

convertlistalgos=$(find ${PATH_STRATUM}/config/ -mindepth 1 -maxdepth 1 -type f -not -name '.*' -not -name '*.sh' -not -name '*.log' -not -name 'stratum.*' -not -name '*.*.*' -iname '*.conf' -execdir basename -s '.conf' {} +);
optionslistalgos=$(echo -e "${convertlistalgos}" | awk '{ printf "%s on\n", $1}' | sort | uniq | grep [[:alnum:]])

DIALOGFORLISTALGOS=${DIALOGFORLISTALGOS=dialog}
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

$DIALOGFORLISTALGOS --colors --title "\Zb\Zr\Z7| Select the algorithm for coin: \Zn\ZR\ZB\Z0${coin^^}\Zn\Zb\Zr\Z7 |" --clear --colors --no-items --nocancel --shadow \
--radiolist "\n\
	\ZB\Z1Choose the algorithm for your coin\n\
	the list scrolls so you can use the \n\
	UP/DOWN arrow keys, the first letter of the choice as \n\
	hotkey or number keys 1-9 to choose an option. \n\
	Press SPACE to select an option.\Zn\n\n\
What is your algorithm? choose from the following..." \
55 60 47 $optionslistalgos 2> $tempfile
retvalalgoselected=$?
ALGOSELECTED=`cat $tempfile`
case $retvalalgoselected in
    0)
    coinalgo="${ALGOSELECTED}";;
    1)
        echo
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Cancel pressed STOP of installation! use daemonbuilder to new start!				${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
    exit;;
    255)
        echo
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   ESC pressed STOP of installation! use daemonbuilder to new start!				${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
    exit;;
esac

if [[ ("${precompiled}" == "true") ]]; then
    input_box "precompiled Coin Information" \
    "Please enter the precompiled file format compressed! 
    \n\nExample: bitcoin-0.16.3-x86_64-linux-gnu.tar.gz
    \n\n .zip format is also supported.
    \n\n*Paste press CTRL+RIGHT mouse button.
    \n\nprecompiled Coin URL Link:" \
    "" \
    coin_precompiled
else
    input_box "Github Repo link" \
    "Please enter the Github Repo link.
    \n\nExample: https://github.com/example-repo-name/coin-wallet.git
    \n\n*Paste press CTRL+RIGHT mouse button.
    \n\nGithub Repo link:" \
    "" \
    git_hub
    
    dialog --title " Switch To development " \
    --yesno "Switch from main repo git in to develop ?
    Selecting Yes use Git developments." 6 50
    response=$?
    case $response in
        0) swithdevelop=yes;;
        1) swithdevelop=no;;
        255) echo "[ESC] key pressed.";;
    esac
    
    if [[ ("${swithdevelop}" == "no") ]]; then
        
        dialog --title " Do you want to use a specific branch ? " \
        --yesno "Do you need to use a specific github branch of the coin?
        Selecting Yes use a selected version Git." 7 60
        response=$?
        case $response in
            0) branch_git_hub=yes;;
            1) branch_git_hub=no;;
            255) echo "[ESC] key pressed.";;
        esac
        
        if [[ ("${branch_git_hub}" == "yes") ]]; then
            
            input_box "Github Repo link" \
    		"Please enter the Github Repo link.
			\n\nExample: https://github.com/example-repo-name/coin-wallet.git
    		\n\n*Paste press CTRL+RIGHT mouse button.
    		\n\nGithub Repo link:" \
    		"" \
    		git_hub
        fi
    fi
fi

set -e
clear
echo
echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
echo -e "$GREEN   Starting installation coin : ${coin^^}							${NC}"
echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"

coindir=$coin$now

# save last coin information in case coin build fails
echo '
lastcoin='"${coindir}"'
' | sudo -E tee $STORAGE_ROOT/daemon_builder/temp_coin_builds/.lastcoin.conf >/dev/null 2>&1

# Clone the coin
if [[ ! -e $coindir ]]; then
    if [[ ("$precompiled" == "true") ]]; then
        mkdir $coindir
        cd "${coindir}"
        sudo wget $coin_precompiled
    else
        git clone $git_hub $coindir
        cd "${coindir}"
		clear;
    fi
    
    if [[ ("${branch_git_hub}" == "yes") ]]; then
        git fetch
        git checkout "$branch_git_hub_ver"
    fi
    
    if [[ ("${swithdevelop}" == "yes") ]]; then
        git checkout develop
    fi
    errorexist="false"
else
    echo
    message_box " Coin already exist temp folder " \
    "${coindir} already exists.... in temp folder Skipping Installation!
    \n\nIf there was an error in the build use the build error options on the installer."
    
    errorexist="true"
    exit 0
fi

if [[("${errorexist}" == "false")]]; then
    sudo chmod -R 777 $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}
    sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
    sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
fi

# Build the coin under the proper configuration
if [[ ("$autogen" == "true") ]]; then
    
    # Build the coin under berkeley 4.8
    if [[ ("$berkeley" == "4.8") ]]; then
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting Building coin $MAGENTA ${coin^^} $MAGENTA using Berkeley 4.8	${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        basedir=$(pwd)
        
        FILEAUTOGEN=$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/autogen.sh
        if [[ ! -f "$FILEAUTOGEN" ]]; then
            echo -e "$YELLOW"
            find . -maxdepth 1 -type d \( -perm -1 -o \( -perm -10 -o -perm -100 \) \) -printf "%f\n"
            echo -e "${NC}$MAGENTA"
            read -r -e -p "Where is the folder that contains the installation ${coin^^}, example bitcoin :" ${repotherinstall}
            echo -e "${NC}"
			clear;
            echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
            echo -e "$GREEN   Moving files and Starting Building coin $MAGENTA ${coin^^} 					${NC}"
            echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
            echo
            
            sudo mv $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/${repotherinstall}/* $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}
        fi
        
        sh autogen.sh
        
        if [[ ! -e "$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/share/genbuild.sh" ]]; then
            echo "genbuild.sh not found skipping"
        else
            sudo chmod 777 $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/share/genbuild.sh
        fi
        if [[ ! -e "$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/leveldb/build_detect_platform" ]]; then
            echo "build_detect_platform not found skipping"
        else
            sudo chmod 777 $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/leveldb/build_detect_platform
        fi
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting configure coin...													${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
        ./configure CPPFLAGS="-I$STORAGE_ROOT/daemon_builder/berkeley/db4/include -O2" LDFLAGS="-L$STORAGE_ROOT/daemon_builder/berkeley/db4/lib" --with-incompatible-bdb --without-gui --disable-tests
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting make coin...															${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
        
        # make install
        TMP=$(tempfile)
        make -j${NPROC} 2>&1 | tee $TMP
        OUTPUT=$(cat $TMP)
        echo $OUTPUT
        rm $TMP
    fi
    
    # Build the coin under berkeley 5.1
    if [[ ("$berkeley" == "5.1") ]]; then
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting Building coin $MAGENTA ${coin^^} ${NC} using Berkeley 5.1	${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        basedir=$(pwd)
        
        FILEAUTOGEN=$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/autogen.sh
        if [[ ! -f "$FILEAUTOGEN" ]]; then
            echo -e "$YELLOW"
            find . -maxdepth 1 -type d \( -perm -1 -o \( -perm -10 -o -perm -100 \) \) -printf "%f\n"
            echo -e "${NC}$MAGENTA"
            read -r -e -p "Where is the folder that contains the installation ${coin^^}, example bitcoin :" repotherinstall
            echo -e "${NC}"
			clear;
            echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
            echo -e "$GREEN   Moving files and Starting Building coin $MAGENTA ${coin^^} 					${NC}"
            echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
            echo
            
            sudo mv $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/${repotherinstall}/* $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}
            
        fi
        
        sh autogen.sh
        
        if [[ ! -e "$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/share/genbuild.sh" ]]; then
            echo "genbuild.sh not found skipping"
        else
            sudo chmod 777 $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/share/genbuild.sh
        fi
        
        if [[ ! -e "$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/leveldb/build_detect_platform" ]]; then
            echo "build_detect_platform not found skipping"
        else
            sudo chmod 777 $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/leveldb/build_detect_platform
        fi
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting configure coin...													${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
        
        ./configure CPPFLAGS="-I$STORAGE_ROOT/daemon_builder/berkeley/db5/include -O2" LDFLAGS="-L$STORAGE_ROOT/daemon_builder/berkeley/db5/lib" --with-incompatible-bdb --without-gui --disable-tests
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting make coin...															${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
        
        # make install
        TMP=$(tempfile)
        make -j${NPROC} 2>&1 | tee $TMP
        OUTPUT=$(cat $TMP)
        echo $OUTPUT
        rm $TMP
    fi
    
    # Build the coin under berkeley 5.3
    if [[ ("$berkeley" == "5.3") ]]; then
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting Building coin $MAGENTA ${coin^^} ${NC} using Berkeley 5.3	${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        basedir=$(pwd)
        
        FILEAUTOGEN=$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/autogen.sh
        if [[ ! -f "$FILEAUTOGEN" ]]; then
            echo -e "$YELLOW"
            find . -maxdepth 1 -type d \( -perm -1 -o \( -perm -10 -o -perm -100 \) \) -printf "%f\n"
            echo -e "${NC}$MAGENTA"
            read -r -e -p "Where is the folder that contains the installation ${coin^^}, example bitcoin :" repotherinstall
            echo -e "${NC}"
			clear;
            echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
            echo -e "$GREEN   Moving files and Starting Building coin $MAGENTA ${coin^^} 					${NC}"
            echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
            echo
            
            sudo mv $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/${repotherinstall}/* $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}
            
        fi
        
        sh autogen.sh
        
        if [[ ! -e "$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/share/genbuild.sh" ]]; then
            echo "genbuild.sh not found skipping"
        else
            sudo chmod 777 $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/share/genbuild.sh
        fi
        
        if [[ ! -e "$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/leveldb/build_detect_platform" ]]; then
            echo "build_detect_platform not found skipping"
        else
            sudo chmod 777 $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/leveldb/build_detect_platform
        fi
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting configure coin...													${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
        
        ./configure CPPFLAGS="-I$STORAGE_ROOT/daemon_builder/berkeley/db5.3/include -O2" LDFLAGS="-L$STORAGE_ROOT/daemon_builder/berkeley/db5.3/lib" --with-incompatible-bdb --without-gui --disable-tests
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting make coin...															${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
        
        # make install
        TMP=$(tempfile)
        make -j${NPROC} 2>&1 | tee $TMP
        OUTPUT=$(cat $TMP)
        echo $OUTPUT
        rm $TMP
    fi
    
    # Build the coin under berkeley 6.2
    if [[ ("$berkeley" == "6.2") ]]; then
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting Building coin $MAGENTA ${coin^^} ${NC} using Berkeley 6.2	${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        basedir=$(pwd)
        
        FILEAUTOGEN=$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/autogen.sh
        if [[ ! -f "$FILEAUTOGEN" ]]; then
            echo -e "$YELLOW"
            find . -maxdepth 1 -type d \( -perm -1 -o \( -perm -10 -o -perm -100 \) \) -printf "%f\n"
            echo -e "${NC}$MAGENTA"
            read -r -e -p "Where is the folder that contains the installation ${coin^^}, example bitcoin :" repotherinstall
            echo -e "${NC}"
			clear;
            echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
            echo -e "$GREEN   Moving files and Starting Building coin $MAGENTA ${coin^^} 					${NC}"
            echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
            echo
            
            sudo mv $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/${repotherinstall}/* $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}
            
        fi
        
        sh autogen.sh
        
        if [[ ! -e "$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/share/genbuild.sh" ]]; then
            echo "genbuild.sh not found skipping"
        else
            sudo chmod 777 $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/share/genbuild.sh
        fi
        
        if [[ ! -e "$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/leveldb/build_detect_platform" ]]; then
            echo "build_detect_platform not found skipping"
        else
            sudo chmod 777 $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/leveldb/build_detect_platform
        fi
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting configure coin...													${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
        
        ./configure CPPFLAGS="-I$STORAGE_ROOT/daemon_builder/berkeley/db6.2/include -O2" LDFLAGS="-L$STORAGE_ROOT/daemon_builder/berkeley/db6.2/lib" --with-incompatible-bdb --without-gui --disable-tests
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting make coin...															${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
        
        # make install
        TMP=$(tempfile)
        make -j${NPROC} 2>&1 | tee $TMP
        OUTPUT=$(cat $TMP)
        echo $OUTPUT
        rm $TMP
    fi
    
    # Build the coin under UTIL directory with BUILD.SH file
    if [[ ("$buildutil" == "true") ]]; then
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting Building $MAGENTA ${coin^^} ${NC}$GREEN using UTIL directory contains BUILD.SH	${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        basedir=$(pwd)
        
        FILEAUTOGEN=$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/autogen.sh
        if [[ ! -f "$FILEAUTOGEN" ]]; then
            echo -e "$YELLOW"
            find . -maxdepth 1 -type d \( -perm -1 -o \( -perm -10 -o -perm -100 \) \) -printf "%f\n"
            echo -e "${NC}$MAGENTA"
            read -r -e -p "Where is the folder that contains the installation ${coin^^}, example bitcoin :" repotherinstall
            echo -e "${NC}"
			clear;
            echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
            echo -e "$GREEN   Moving files and Starting Building coin $MAGENTA ${coin^^} 					${NC}"
            echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
            echo
            
            sudo mv $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/${repotherinstall}/* $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}
            
        fi
        
        sh autogen.sh
        
        find . -maxdepth 1 -type d \( -perm -1 -o \( -perm -10 -o -perm -100 \) \) -printf "%f\n"
        read -r -e -p "where is the folder that contains the BUILD.SH installation file, example xxutil :" reputil
        cd $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/${reputil}
        echo $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/${reputil}
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
        
        bash build.sh -j$(nproc)
        
        if [[ ! -e "$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/${reputil}/fetch-params.sh" ]]; then
            echo "fetch-params.sh not found skipping"
        else
            sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
            sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
            sh fetch-params.sh
        fi
    fi
    
else
    
    # Build the coin under cmake
    if [[ ("$cmake" == "true") ]]; then
        clear
        DEPENDS="$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/depends"
        
        # Build the coin under depends present
        if [ -d "$DEPENDS" ]; then
            echo
            echo
            echo -e "$CYAN => Building using cmake with DEPENDS directory... ${NC}"
            echo
            
            
            echo
            echo
            read -r -e -p "Hide LOG from to Work Coin ? [y/N] :" ifhidework
            echo
            
            # Executing make on depends directory
            echo
            echo -e "$YELLOW => executing make on depends directory... ${NC}"
            echo
            
            cd $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/depends
            if [[ ("$ifhidework" == "y" || "$ifhidework" == "Y") ]]; then
                # make install
                TMP=$(tempfile)
                hide_output make -j${NPROC} 2>&1 | tee $TMP
                OUTPUT=$(cat $TMP)
                echo $OUTPUT
                rm $TMP
            else
                echo
				clear;
                echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
                echo -e "$GREEN   Starting make coin...														${NC}"
                echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
                echo
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
                
                # make install
                TMP=$(tempfile)
                make -j${NPROC} 2>&1 | tee $TMP
                OUTPUT=$(cat $TMP)
                echo $OUTPUT
                rm $TMP
            fi
            echo
            echo
            echo -e "$GREEN Done...${NC}"
            
            # Building autogen....
            echo
			clear;
            echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
            echo -e "$GREEN   Starting Building coin $MAGENTA ${coin^^} ${NC} using autogen...		${NC}"
            echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
            echo
            
            cd $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}
            if [[ ("$ifhidework" == "y" || "$ifhidework" == "Y") ]]; then
                hide_output sh autogen.sh
            else
                sh autogen.sh
            fi
            echo
            echo
            echo -e "$GREEN Done...${NC}"
            
            # Configure with your platform....
            if [ -d "$DEPENDS/i686-pc-linux-gnu" ]; then
                echo
				clear;
                echo -e "$YELLOW => Configure with i686-pc-linux-gnu... ${NC}"
                echo
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
                
                if [[ ("$ifhidework" == "y" || "$ifhidework" == "Y") ]]; then
                    hide_output ./configure --with-incompatible-bdb --prefix=`pwd`/depends/i686-pc-linux-gnu
                else
                    ./configure --with-incompatible-bdb --prefix=`pwd`/depends/i686-pc-linux-gnu
                fi
                elif [ -d "$DEPENDS/x86_64-pc-linux-gnu/" ]; then
                echo
                echo -e "$YELLOW => Configure with x86_64-pc-linux-gnu... ${NC}"
                echo
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
                
                if [[ ("$ifhidework" == "y" || "$ifhidework" == "Y") ]]; then
                    hide_output ./configure --with-incompatible-bdb --prefix=`pwd`/depends/x86_64-pc-linux-gnu
                else
                    ./configure --with-incompatible-bdb --prefix=`pwd`/depends/x86_64-pc-linux-gnu
                fi
                elif [ -d "$DEPENDS/i686-w64-mingw32/" ]; then
                echo
				clear;
                echo -e "$YELLOW => Configure with i686-w64-mingw32... ${NC}"
                echo
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
                
                if [[ ("$ifhidework" == "y" || "$ifhidework" == "Y") ]]; then
                    hide_output ./configure --with-incompatible-bdb --prefix=`pwd`/depends/i686-w64-mingw32
                else
                    ./configure --with-incompatible-bdb --prefix=`pwd`/depends/i686-w64-mingw32
                fi
                elif [ -d "$DEPENDS/x86_64-w64-mingw32/" ]; then
                echo
				clear;
                echo -e "$YELLOW => Configure with x86_64-w64-mingw32... ${NC}"
                echo
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
                
                if [[ ("$ifhidework" == "y" || "$ifhidework" == "Y") ]]; then
                    hide_output ./configure --with-incompatible-bdb --prefix=`pwd`/depends/x86_64-w64-mingw32
                else
                    ./configure --with-incompatible-bdb --prefix=`pwd`/depends/x86_64-w64-mingw32
                fi
                elif [ -d "$DEPENDS/x86_64-apple-darwin14/" ]; then
                echo
				clear;
                echo -e "$YELLOW => Configure with x86_64-apple-darwin14... ${NC}"
                echo
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
                
                if [[ ("$ifhidework" == "y" || "$ifhidework" == "Y") ]]; then
                    hide_output ./configure --with-incompatible-bdb --prefix=`pwd`/depends/x86_64-apple-darwin14
                else
                    ./configure --with-incompatible-bdb --prefix=`pwd`/depends/x86_64-apple-darwin14
                fi
                elif [ -d "$DEPENDS/arm-linux-gnueabihf/" ]; then
                echo
                echo -e "$YELLOW => Configure with arm-linux-gnueabihf... ${NC}"
                echo
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
                
                if [[ ("$ifhidework" == "y" || "$ifhidework" == "Y") ]]; then
                    hide_output ./configure --with-incompatible-bdb --prefix=`pwd`/depends/arm-linux-gnueabihf
                else
                    ./configure --with-incompatible-bdb --prefix=`pwd`/depends/arm-linux-gnueabihf
                fi
                elif [ -d "$DEPENDS/aarch64-linux-gnu/" ]; then
                echo
				clear;
                echo -e "$YELLOW => Configure with aarch64-linux-gnu... ${NC}"
                echo
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
                
                if [[ ("$ifhidework" == "y" || "$ifhidework" == "Y") ]]; then
                    hide_output ./configure --with-incompatible-bdb --prefix=`pwd`/depends/aarch64-linux-gnu
                else
                    ./configure --with-incompatible-bdb --prefix=`pwd`/depends/aarch64-linux-gnu
                fi
            fi
            echo
            echo
            echo -e "$GREEN Done...${NC}"
            
            # Executing make to finalize....
            echo
			clear;
            echo -e "$YELLOW => Executing make to finalize... ${NC}"
            echo
            sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
            sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
            
            if [[ ("$ifhidework" == "y" || "$ifhidework" == "Y") ]]; then
                # make install
                TMP=$(tempfile)
                hide_output make -j${NPROC} 2>&1 | tee $TMP
                OUTPUT=$(cat $TMP)
                echo $OUTPUT
                rm $TMP
            else
                echo
				clear;
                echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
                echo -e "$GREEN   Starting make coin...														${NC}"
                echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
                echo
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
                sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
                
                # make install
                TMP=$(tempfile)
                make -j${NPROC} 2>&1 | tee $TMP
                OUTPUT=$(cat $TMP)
                echo $OUTPUT
                rm $TMP
            fi
            echo
            echo
            echo -e "$GREEN Done...${NC}"
        else
            echo
			clear;
            echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
            echo -e "$GREEN   Starting Building coin $MAGENTA ${coin^^} ${NC} using Cmake method	${NC}"
            echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
            echo
            
            cd $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir} && git submodule init && git submodule update
            
            echo
			clear;
            echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
            echo -e "$GREEN   Starting make coin...														${NC}"
            echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
            echo
            sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
            sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
            
            # make install
            TMP=$(tempfile)
            make -j${NPROC} 2>&1 | tee $TMP
            OUTPUT=$(cat $TMP)
            echo $OUTPUT
            rm $TMP
            
        fi
    fi
    
    # Build the coin under unix
    if [[ ("$unix" == "true") ]]; then
        echo
		clear;
        echo -e "$CYAN ----------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting Building coin $MAGENTA ${coin^^} ${NC}	using makefile.unix method	${NC}"
        echo -e "$CYAN ----------------------------------------------------------------------------------- 	${NC}"
        echo
        cd $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src
        
        if [[ ! -e "$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/obj" ]]; then
            mkdir -p $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/obj
        else
            echo "Hey the developer did his job and the src/obj dir is there!"
        fi
        
        if [[ ! -e "$STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/obj/zerocoin" ]]; then
            mkdir -p $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/obj/zerocoin
        else
            echo  "Wow even the /src/obj/zerocoin is there! Good job developer!"
        fi
        
        cd $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/leveldb
        sudo chmod +x build_detect_platform
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting make clean...														${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
        
        sudo make clean
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting precompiling with make depends libs*									${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
        
        sudo make libleveldb.a libmemenv.a
        cd $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type d -exec chmod 777 {} \;
        sudo find $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/ -type f -exec chmod 777 {} \;
        
        sed -i '/USE_UPNP:=0/i BDB_LIB_PATH = '${absolutepath}'/'${installtoserver}'/berkeley/db4/lib\nBDB_INCLUDE_PATH = '${absolutepath}'/'${installtoserver}'/berkeley/db4/include\nOPENSSL_LIB_PATH = '${absolutepath}'/'${installtoserver}'/openssl/lib\nOPENSSL_INCLUDE_PATH = '${absolutepath}'/'${installtoserver}'/openssl/include' makefile.unix
        sed -i '/USE_UPNP:=1/i BDB_LIB_PATH = '${absolutepath}'/'${installtoserver}'/berkeley/db4/lib\nBDB_INCLUDE_PATH = '${absolutepath}'/'${installtoserver}'/berkeley/db4/include\nOPENSSL_LIB_PATH = '${absolutepath}'/'${installtoserver}'/openssl/lib\nOPENSSL_INCLUDE_PATH = '${absolutepath}'/'${installtoserver}'/openssl/include' makefile.unix
        echo
		clear;
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Starting compiling with makefile.unix											${NC}"
        echo -e "$CYAN ------------------------------------------------------------------------------- 	${NC}"
        
        # make install
        TMP=$(tempfile)
        make -j${NPROC} -f makefile.unix USE_UPNP=- 2>&1 | tee $TMP
        OUTPUT=$(cat $TMP)
        echo $OUTPUT
        rm $TMP
    fi
fi

if [[ "$precompiled" == "true" ]]; then
    COINTARGZ=$(find ~+ -type f -name "*.tar.gz")
    COINZIP=$(find ~+ -type f -name "*.zip")
    COIN7Z=$(find ~+ -type f -name "*.7z")

    if [[ -f "$COINZIP" ]]; then
        for i in $(ls -f *.zip); do coinzipped=${i%%}; done
        sudo unzip -q "$coinzipped" -d newcoin
        for i in $(ls -d */); do repzipcoin=${i%%/}; done
    elif [[ -f "$COINTARGZ" ]]; then
        for i in $(ls -f *.tar.gz); do coinzipped=${i%%}; done
        sudo tar xzvf "$coinzipped"
        for i in $(ls -d */); do repzipcoin=${i%%/}; done
    elif [[ -f "$COIN7Z" ]]; then
        for i in $(ls -f *.7z); do coinzipped=${i%%}; done
        sudo 7z x "$coinzipped" -o"newcoin"
        for i in $(ls -d */); do repzipcoin=${i%%/}; done
    else
        echo -e "$RED => This is not a valid zipped file.${NC}"
    fi

    # Change ownership of the newcoin directory to the current user
    sudo chown -R $USER:$USER newcoin
fi

clear

# LS the SRC dir to have user input bitcoind and bitcoin-cli names
if [[ ! ("$precompiled" == "true") ]]; then
    
    cd $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/
    echo
    echo -e "$CYAN --------------------------------------------------------------------------------------- 	${NC}"
    echo -e "$GREEN   List os avalible daemons: ${NC}"
    echo -e "$YELLOW"
    find . -maxdepth 1 -type f ! -name "*.*" \( -perm -1 -o \( -perm -10 -o -perm -100 \) \) -printf "%f\n"
    echo -e "${NC}"
    echo -e "$CYAN --------------------------------------------------------------------------------------- 	${NC}"
    echo
    echo -e "$CYAN --------------------------------------------------------------------------------------- 	${NC}"
    echo
    
    read -r -e -p "Please enter the coind name from the directory above, example bitcoind :" coind
    
    echo
    read -r -e -p "Is there a coin-cli, example bitcoin-cli [y/N] :" ifcoincli
    if [[ ("$ifcoincli" == "y" || "$ifcoincli" == "Y") ]]; then
        read -r -e -p "Please enter the coin-cli name :" coincli
    fi
    
    echo
    read -r -e -p "Is there a coin-tx, example bitcoin-tx [y/N] :" ifcointx
    if [[ ("$ifcointx" == "y" || "$ifcointx" == "Y") ]]; then
        read -r -e -p "Please enter the coin-tx name :" cointx
    fi
    
    echo
    read -r -e -p "Is there a coin-util, example bitcoin-util [y/N] :" ifcoinutil
    if [[ ("$ifcoinutil" == "y" || "$ifcoinutil" == "Y") ]]; then
        read -r -e -p "Please enter the coin-util name :" coinutil
    fi
    
    echo
    read -r -e -p "Is there a coin-hash, example bitcoin-hash [y/N] :" ifcoinhash
    if [[ ("$ifcoinhash" == "y" || "$ifcoinhash" == "Y") ]]; then
        read -r -e -p "Please enter the coin-hash name :" coinhash
    fi
    
    echo
    read -r -e -p "Is there a coin-wallet, example bitcoin-wallet [y/N] :" ifcoinwallet
    if [[ ("$ifcoinwallet" == "y" || "$ifcoinwallet" == "Y") ]]; then
        read -r -e -p "Please enter the coin-wallet name :" coinwallet
    fi
    
    if [[ ("$buildutil" == "true" || "$precompiled" == "true") ]]; then
        echo
        read -r -e -p "Is there a coin-tools, example bitcoin-wallet-tools [y/N] :" ifcointools
        if [[ ("$ifcointools" == "y" || "$ifcointools" == "Y") ]]; then
            read -r -e -p "Please enter the coin-tools name :" cointools
        fi
        
        echo
        read -r -e -p "Is there a coin-gtest, example bitcoin-gtest [y/N] :" ifcoingtest
        if [[ ("$ifcoingtest" == "y" || "$ifcoingtest" == "Y") ]]; then
            read -r -e -p "Please enter the coin-gtest name :" coingtest
        fi
    fi
    echo
    echo -e "$CYAN --------------------------------------------------------------------------------------- 	${NC}"
    echo
    
    FILECOIN=/usr/bin/${coind}
    if [[ -f "$FILECOIN" ]]; then
        DAEMOND="true"
        SERVICE="${coind}"
        if pgrep -x "$SERVICE" >/dev/null; then
            if [[ ("${YIIMPCONF}" == "true") ]]; then
                if [[ ("$ifcoincli" == "y" || "$ifcoincli" == "Y") ]]; then
                    "${coincli}" -datadir=$STORAGE_ROOT/wallets/."${coind::-1}" -conf="${coind::-1}".conf stop
                else
                    "${coind}" -datadir=$STORAGE_ROOT/wallets/."${coind::-1}" -conf="${coind::-1}".conf stop
                fi
            else
                if [[ ("$ifcoincli" == "y" || "$ifcoincli" == "Y") ]]; then
                    "${coincli}" -datadir=${absolutepath}/wallets/."${coind::-1}" -conf="${coind::-1}".conf stop
                else
                    "${coind}" -datadir=${absolutepath}/wallets/."${coind::-1}" -conf="${coind::-1}".conf stop
                fi
            fi
            echo -e "$CYAN --------------------------------------------------------------------------- ${NC}"
            secstosleep=$((1 * 20))
            while [ $secstosleep -gt 0 ]; do
                echo -ne "$GREEN	STOP THE DAEMON => $YELLOW${coind}$GREEN Sleep $CYAN$secstosleep$GREEN ...${NC}\033[0K\r"
                
                : $((secstosleep--))
            done
            echo -e "$CYAN --------------------------------------------------------------------------- ${NC} $GREEN"
            echo -e "$GREEN Done... ${NC}$"
            echo -e "${NC}$CYAN --------------------------------------------------------------------------- ${NC}"
            echo
        fi
    fi
fi

clear

# Strip and copy to /usr/bin
if [[ ("$precompiled" == "true") ]]; then
    cd $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/${repzipcoin}/
    
    COINDFIND=$(find ~+ -type f -name "*d")
    sleep 0.5
    COINCLIFIND=$(find ~+ -type f -name "*-cli")
    sleep 0.5
    COINTXFIND=$(find ~+ -type f -name "*-tx")
    sleep 0.5
    COINUTILFIND=$(find ~+ -type f -name "*-util")
    sleep 0.5
    COINHASHFIND=$(find ~+ -type f -name "*-hash")
    sleep 0.5
    COINWALLETFIND=$(find ~+ -type f -name "*-wallet")
    
    
    if [[ -f "$COINDFIND" ]]; then
        coind=$(basename $COINDFIND)
        
        if [[ -f "$COINCLIFIND" ]]; then
            coincli=$(basename $COINCLIFIND)
        fi
        
        FILECOIN=/usr/bin/${coind}
        if [[ -f "$FILECOIN" ]]; then
            DAEMOND="true"
            SERVICE="${coind}"
            if pgrep -x "$SERVICE" >/dev/null; then
                if [[ ("${YIIMPCONF}" == "true") ]]; then
                    if [[ -f "$COINCLIFIND" ]]; then
                        "${coincli}" -datadir=$STORAGE_ROOT/wallets/."${coind::-1}" -conf="${coind::-1}".conf stop
                    else
                        "${coind}" -datadir=$STORAGE_ROOT/wallets/."${coind::-1}" -conf="${coind::-1}".conf stop
                    fi
                else
                    if [[ -f "${COINCLIFIND}" ]]; then
                        "${coincli}" -datadir=${absolutepath}/wallets/."${coind::-1}" -conf="${coind::-1}".conf stop
                    else
                        "${coind}" -datadir=${absolutepath}/wallets/."${coind::-1}" -conf="${coind::-1}".conf stop
                    fi
                fi
                echo -e "$CYAN --------------------------------------------------------------------------- ${NC}"
                secstosleep=$((1 * 20))
                while [ $secstosleep -gt 0 ]; do
                    echo -ne "$GREEN	STOP THE DAEMON => $YELLOW${coind}$GREEN Sleep $CYAN$secstosleep$GREEN ...${NC}\033[0K\r"
                    
                    : $((secstosleep--))
                done
                echo -e "$CYAN --------------------------------------------------------------------------- ${NC} $GREEN"
                echo -e "$GREEN Done... ${NC}$"
                echo -e "${NC}$CYAN --------------------------------------------------------------------------- ${NC}"
                echo
            fi
        fi
        
        sudo strip $COINDFIND
        
        sudo cp $COINDFIND /usr/bin
        sudo chmod +x /usr/bin/${coind}
        coindmv=true
        
        echo
        echo -e "$CYAN ----------------------------------------------------------------------------------- ${NC}"
        echo
        echo -e "$GREEN  ${coind} moving to =>$YELLOW /usr/bin/${NC}${coind} ${NC}"
        
    else
        clear
        
        echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
        echo -e "$RED    ERROR																		${NC}"
        echo -e "$RED    your precompiled *zip OR *.tar.gz not contains coind file					${NC}"
        echo -e "$RED    Please start again with a valid file precompiled!							${NC}"
        echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
        
        sudo rm -r $STORAGE_ROOT/daemon_builder/temp_coin_builds/.lastcoin.conf
        sudo rm -r $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}
        sudo rm -r $STORAGE_ROOT/daemon_builder/.daemon_builder.my.cnf
        
        exit;
    fi
    
    if [[ -f "$COINCLIFIND" ]]; then
        sudo strip $COINCLIFIND
        
        sudo cp $COINCLIFIND /usr/bin
        sudo chmod +x /usr/bin/${coincli}
        coinclimv=true
        
        echo -e "$GREEN  Coin-cli moving to => /usr/bin/${NC}$YELLOW${coincli} ${NC}"
        
    fi
    
    if [[ -f "$COINTXFIND" ]]; then
        cointx=$(basename $COINTXFIND)
        sudo strip $COINTXFIND
        
        sudo cp $COINTXFIND /usr/bin
        sudo chmod +x /usr/bin/${cointx}
        cointxmv=true
        
        echo -e "$GREEN  Coin-tx moving to => /usr/bin/${NC}$YELLOW${cointx} ${NC}"
        
    fi
    
    if [[ -f "$COINUTILFIND" ]]; then
        coinutil=$(basename $COINUTILFIND)
        sudo strip $COINUTILFIND
        
        sudo cp $COINUTILFIND /usr/bin
        sudo chmod +x /usr/bin/${coinutil}
        coinutilmv=true
        
        echo -e "$GREEN  Coin-tx moving to => /usr/bin/${NC}$YELLOW${coinutil} ${NC}"
        
    fi
    
    if [[ -f "$COINHASHFIND" ]]; then
        coinhash=$(basename $COINHASHFIND)
        sudo strip $COINHASHFIND
        
        sudo cp $COINHASHFIND /usr/bin
        sudo chmod +x /usr/bin/${coinhash}
        coinhashmv=true
        
        echo -e "$GREEN  Coin-hash moving to => /usr/bin/${NC}$YELLOW${coinwallet} ${NC}"
        
    fi
    
    if [[ -f "$COINWALLETFIND" ]]; then
        coinwallet=$(basename $COINWALLETFIND)
        sudo strip $COINWALLETFIND
        
        sudo cp $COINWALLETFIND /usr/bin
        sudo chmod +x /usr/bin/${coinwallet}
        coinwalletmv=true
        
        echo -e "$GREEN  Moving ${coinwallet} to => /usr/bin/${NC}$YELLOW${coinwallet} ${NC}"
        
    fi
    echo
    echo -e "$CYAN --------------------------------------------------------------------------------------- ${NC}"
    echo
else
    echo
    echo -e "$CYAN --------------------------------------------------------------------------------------- ${NC}"
    echo
    echo -e "$GREEN  Coin-tx moving to => /usr/bin/${NC}$YELLOW${coind} ${NC}"
    
    sudo cp $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/${coind} /usr/bin
    sudo strip /usr/bin/${coind}
    coindmv=true
    
    if [[ ("$ifcoincli" == "y" || "$ifcoincli" == "Y") ]]; then
        echo -e "$GREEN  Coin-tx moving to => /usr/bin/${NC}$YELLOW${coincli} ${NC}"
        
        sudo cp $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/${coincli} /usr/bin
        sudo strip /usr/bin/${coincli}
        coinclimv=true
    fi
    
    if [[ ("$ifcointx" == "y" || "$ifcointx" == "Y") ]]; then
        echo -e "$GREEN  Coin-tx moving to => /usr/bin/${NC}$YELLOW${cointx} ${NC}"
        
        sudo cp $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/${cointx} /usr/bin
        sudo strip /usr/bin/${cointx}
        cointxmv=true
    fi
    
    if [[ ("$ifcoinutil" == "y" || "$ifcoinutil" == "Y") ]]; then
        echo -e "$GREEN  Coin-tx moving to => /usr/bin/${NC}$YELLOW${coinutil} ${NC}"
        
        sudo cp $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/${coinutil} /usr/bin
        sudo strip /usr/bin/${coinutil}
        coinutilmv=true
    fi
    
    if [[ ("$ifcoingtest" == "y" || "$ifcoingtest" == "Y") ]]; then
        echo -e "$GREEN  Coin-tx moving to => /usr/bin/${NC}$YELLOW${coingtest} ${NC}"
        
        sudo cp $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/${coingtest} /usr/bin
        sudo strip /usr/bin/${coingtest}
        coingtestmv=true
    fi
    
    if [[ ("$ifcointools" == "y" || "$ifcointools" == "Y") ]]; then
        echo -e "$GREEN  Coin-tx moving to => /usr/bin/${NC}$YELLOW${cointools} ${NC}"
        
        sudo cp $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/${cointools} /usr/bin
        sudo strip /usr/bin/${cointools}
        cointoolsmv=true
    fi
    
    if [[ ("$ifcoinhash" == "y" || "$ifcoinhash" == "Y") ]]; then
        echo -e "$GREEN  Coin-hash moving to => /usr/bin/${NC}$YELLOW${coinhash} ${NC}"
        
        sudo cp $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/${coinhash} /usr/bin
        sudo strip /usr/bin/${coinhash}
        coinhashmv=true
    fi
    
    if [[ ("$ifcoinwallet" == "y" || "$ifcoinwallet" == "Y") ]]; then
        echo -e "$GREEN  Coin-wallet moving to => /usr/bin/${NC}$YELLOW${coinwallet} ${NC}"
        
        sudo cp $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}/src/${coinwallet} /usr/bin
        sudo strip /usr/bin/${coinwallet}
        coinwalletmv=true
    fi
    echo
    echo -e "$CYAN --------------------------------------------------------------------------------------- ${NC}"
    echo
fi

if [[ "${YIIMPCONF}" == "true" ]]; then
    # Make the new wallet folder have user paste the coin.conf and finally start the daemon
    if [[ ! -e "$STORAGE_ROOT/wallets" ]]; then
        sudo mkdir -p $STORAGE_ROOT/wallets
    fi
    
    sudo setfacl -m u:${USERSERVER}:rwx $STORAGE_ROOT/wallets
    mkdir -p "$STORAGE_ROOT/wallets/.${coind::-1}"
    
    if [[ "$coinwalletmv" == "true" ]]; then
        echo
        clear
        echo -e "$CYAN ----------------------------------------------------------------------------------- 	${NC}"
        echo -e "$GREEN   Creating WALLET.DAT to => ${STORAGE_ROOT}/wallets/.${coind%?}/wallet.dat          ${NC}"
        echo -e "$CYAN ----------------------------------------------------------------------------------- 	${NC}"
        echo
        "${coinwallet}" -datadir="${STORAGE_ROOT}/wallets/.${coind%?}" -wallet=. create
        
    fi
    
fi

if [[("$DAEMOND" != 'true')]]; then
    echo
	clear;
    echo -e "$CYAN --------------------------------------------------------------------------------------- 	${NC}"
    echo -e "$GREEN   Adding dedicated port to ${coin^^}${NC}"
    echo -e "$CYAN --------------------------------------------------------------------------------------- 	${NC}"
    echo
    
    
    addport "CREATECOIN" "${coin^^}" "${coinalgo}"
    
    source $STORAGE_ROOT/daemon_builder/.addport.cnf
    
    ADDPORTCONF=$STORAGE_ROOT/daemon_builder/.addport.cnf
    
    if [[ -f "$ADDPORTCONF" ]]; then
        if [[ "${YIIMPCONF}" == "true" ]]; then
            echo '
			# Your coin name is = '""''"${coin^^}"''""'
			# Your coin algo is = '""''"${COINALGO}"''""'
			# Your dedicated port is = '""''"${COINPORT}"''""'
			# Please adding dedicated port in line blocknotify= replace :XXXX to '""''"${COINPORT}"''""'
            ' | sudo -E tee $STORAGE_ROOT/wallets/."${coind::-1}"/${coind::-1}.conf >/dev/null 2>&1;
        else
            echo '
			# Your coin name is = '""''"${coin^^}"''""'
			# Your coin algo is = '""''"${COINALGO}"''""'
			# Your dedicated port is = '""''"${COINPORT}"''""'
			# Please adding dedicated port in line blocknotify= replace :XXXX to '""''"${COINPORT}"''""'
            ' | sudo -E tee ${absolutepath}/wallets/."${coind::-1}"/${coind::-1}.conf >/dev/null 2>&1;
        fi
        
    fi
    
    echo
    echo
    echo -e "$CYAN --------------------------------------------------------------------------------------------- 	${NC}"
    echo -e "$YELLOW   I am now going to open nano, please copy and paste the config from yiimp in to this file.	${NC}"
    echo -e "$CYAN --------------------------------------------------------------------------------------------- 	${NC}"
    echo
    read -n 1 -s -r -p "Press any key to continue"
    echo
    
    if [[ "${YIIMPCONF}" == "true" ]]; then
        sudo nano $STORAGE_ROOT/wallets/."${coind::-1}"/${coind::-1}.conf
    else
        sudo nano ${absolutepath}/wallets/."${coind::-1}"/${coind::-1}.conf
    fi
    
    clear
    cd $STORAGE_ROOT/daemon_builder
fi

clear
echo
figlet -f slant -w 100 "    DaemonBuilder" | lolcat

echo -e "$CYAN --------------------------------------------------------------------------- 	"
echo -e "$CYAN    Starting ${coind::-1} ${NC}"

if [[("$DAEMOND" == 'true')]]; then
    echo -e "${NC}$GREEN    UPDATE of ${coind::-1} is completed and running. ${NC}"
else
    echo -e "${NC}$GREEN    Installation of ${coind::-1} is completed and running. ${NC}"
fi

if [[ "$coindmv" == "true" ]]; then
    echo
    echo -e "$GREEN    Name of COIND :${NC} $MAGENTA ${coind} ${NC}"
    echo -e "$GREEN    path in : ${NC}$YELLOW/usr/bin/${coind} ${NC}"
fi
if [[ "$coinclimv" == "true" ]]; then
    echo
    echo -e "$GREEN    Name of COIN-CLI :${NC} $MAGENTA ${coincli} ${NC}"
    echo -e "$GREEN    path in : ${NC}$YELLOW/usr/bin/${coincli} ${NC}"
fi
if [[ "$cointxmv" == "true" ]]; then
    echo
    echo -e "$GREEN    Name of COIN-TX :${NC} $MAGENTA ${cointx} ${NC}"
    echo -e "$GREEN    path in : ${NC}$YELLOW/usr/bin/${cointx} ${NC}"
fi
if [[ "$coingtestmv" == "true" ]]; then
    echo
    echo -e "$GREEN    Name of COIN-TX :${NC} $MAGENTA ${coingtest} ${NC}"
    echo -e "$GREEN    path in : ${NC}$YELLOW/usr/bin/${coingtest} ${NC}"
fi
if [[ "$coingtestmv" == "true" ]]; then
    echo
    echo -e "$GREEN    Name of COIN-TX :${NC} $MAGENTA ${coingtest} ${NC}"
    echo -e "$GREEN    path in : ${NC}$YELLOW/usr/bin/${coingtest} ${NC}"
fi
if [[ "$coinutilmv" == "true" ]]; then
    echo
    echo -e "$GREEN    Name of COIN-TX :${NC} $MAGENTA ${coinutil} ${NC}"
    echo -e "$GREEN    path in : ${NC}$YELLOW/usr/bin/${coinutil} ${NC}"
fi
if [[ "$cointoolsmv" == "true" ]]; then
    echo
    echo -e "$GREEN    Name of COIN-TX :${NC} $MAGENTA ${cointools} ${NC}"
    echo -e "$GREEN    path in : ${NC}$YELLOW/usr/bin/${cointools} ${NC}"
fi
if [[ "$coinhashmv" == "true" ]]; then
    echo
    echo -e "$GREEN    Name of COIN-HASH :${NC} $MAGENTA ${coinhash} ${NC}"
    echo -e "$GREEN    path in : ${NC}$YELLOW/usr/bin/${coinhash} ${NC}"
fi
if [[ "$coinwalletmv" == "true" ]]; then
    echo
    echo -e "$GREEN    Name of COIN-WALLET :${NC} $MAGENTA ${coinwallet} ${NC}"
    echo -e "$GREEN    path in : ${NC}$YELLOW/usr/bin/${coinwallet} ${NC}"
fi
echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
echo
echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
echo -e "$GREEN    Name of Symbol coin: ${NC}$MAGENTA ${coin^^} 						${NC}"
if [[ -f "$ADDPORTCONF" ]]; then
    echo -e "$GREEN    Algo of to Symbol ${coin^^} :${NC}$MAGENTA ${COINALGO}				${NC}"
    echo -e "$GREEN    Dedicated port of to Symbol ${coin^^} :${NC}$MAGENTA ${COINPORT} 	${NC}"
fi
echo
echo -e "$YELLOW    To use your Stratum type,$BLUE stratum.${coin,,} start|stop|restart ${coin,,} ${NC}"
echo -e "$YELLOW    To see the stratum screen type,$MAGENTA screen -r ${coin,,}			${NC}"
echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
echo
echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
echo -e "$RED    Type${NC}$MAGENTA daemonbuilder${NC}$RED at anytime to install a new coin! ${NC}"
echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
echo

# If we made it this far everything built fine removing last coin.conf and build directory
sudo rm -r $STORAGE_ROOT/daemon_builder/temp_coin_builds/.lastcoin.conf
sudo rm -r $STORAGE_ROOT/daemon_builder/temp_coin_builds/${coindir}
sudo rm -r $STORAGE_ROOT/daemon_builder/.daemon_builder.my.cnf
if [[ -f "$ADDPORTCONF" ]]; then
    sudo rm -r $STORAGE_ROOT/daemon_builder/.addport.cnf
fi
echo -e "$CYAN"
if [[ ("${YIIMPCONF}" == "true") ]]; then
    "${coind}" -datadir=$STORAGE_ROOT/wallets/."${coind::-1}" -conf="${coind::-1}".conf -daemon -shrinkdebugfile
else
    "${coind}" -datadir=${absolutepath}/wallets/."${coind::-1}" -conf="${coind::-1}".conf -daemon -shrinkdebugfile
fi
echo -e "${NC}"

exit