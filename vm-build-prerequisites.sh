#!/bin/bash
#

install_misc_build=false
install_java=true
install_docker=true
install_nodejs=false
install_microsoft_pwsh=false
install_microsoft_dotnet=false
setup_repository=false

#
# ensure existing package list is up to date
sudo apt-get update
sudo apt-get --with-new-pkgs upgrade -y
#
# install prerequisite packages so apt can use HTTPS
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
release_num=$(lsb_release -rs)
release_codename=$(lsb_release -cs)

if [ "$install_misc_build" == "true" ]; then
    #
    # p7zip-full install
    sudo apt-get install -y p7zip-full jq

    #
    # Need sshpass for a few interactions with the server
    sudo apt-get install sshpass

    #
    # install dev tools in case needed
    sudo apt-get install -y build-essential gcc g++ make

    #
    # generate an ssh key for use during script execution
    if [ ! -d ~"/.ssh" ]; then
        mkdir --parents ~/.ssh/pwinsight
        chmod 700 ~/.ssh
        chmod 775 ~/.ssh/pwinsight
    elif [ ! -d ~"/.ssh/pwinsight" ]; then
        mkdir ~/.ssh/pwinsight
        chmod 775 ~/.ssh/pwinsight
    fi
    ssh-keygen -b 2048 -t rsa -f ~/.ssh/pwinsight/pwinsight-dev-key
    ln -s ~/.ssh/pwinsight/pwinsight-dev-key ~/.ssh/pwinsight/pwinsight-dev-key.pem

fi


if [ "$install_java" == "true" ]; then
    #
    # Install java just in case we need it
    #
    if [ "$release_num" == "16.04" ]; then
        sudo apt-get install -y openjdk-8-jdk-headless
    fi
    if [[ "$release_num" == "20.04" || "$release_num" == "22.04" ]]; then
        sudo apt-get install -y openjdk-11-jdk-headless
    fi
    echo "$(java --version)"
fi  # Java install


if [ "$install_docker" == "true" ]; then
    # Install Docker
    #
    # Add the GPG key for the Docker repository
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    #
    # Add the docker repository to APT
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    #
    # Update the package database to include docker packages
    sudo apt-get update -y
    #
    # Install docker
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    #
    # check if docker service is running
    sudo systemctl --no-pager status docker
    #
    # Add user to the docker group to avoid need for sudo
    sudo usermod -aG docker ${USER}
    #

    # Install docker-compose also
    sudo curl -L https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep "tag_name" | cut -d \" -f4)/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo ""
    echo "docker-compose version: $(docker-compose --version)"
fi  # install docker


if [ "$install_nodejs" == "true" ]; then
    #
    # Install NodeJS
    #
    # load the NodeJS install script
    cd ~
    if [[ "$release_num" == "20.04" || "$release_num" == "22.04" ]]; then
        curl -sL https://deb.nodesource.com/setup_16.x -o nodesource_setup.sh
    fi
    if [ "$release_num" == "16.04" ]; then
        curl -sL https://deb.nodesource.com/setup_10.x -o nodesource_setup.sh
    fi
    #
    # run the script
    sudo bash nodesource_setup.sh
    #
    # now run the install
    sudo apt-get install -y nodejs
    #
    # also need grunt for the build
    sudo /usr/bin/npm install grunt -g

    #
    # Ensure installed proper version
    echo ""
    echo "NodeJS version: $(nodejs --version)"
    echo "NPM version: $(npm --version)"
    echo "Grunt version: $(grunt --version)"

    # clean up from node intall
    rm nodesource_setup.sh
fi  # install NodeJS


if [ "$install_microsoft_pwsh" == "true" ] || [ "$install_microsoft_dotnet" == "true" ]; then
    #
    # Install powershell core
    # download microsoft repository GPG keys
    wget -q https://packages.microsoft.com/config/ubuntu/${release_num}/packages-microsoft-prod.deb

    # Register the Microsoft repository GPG keys
    sudo dpkg -i packages-microsoft-prod.deb

    if [[ "$release_num" == "20.04" || "$release_num" == "22.04" ]]; then
        # Enable the "universe" repositories
        sudo add-apt-repository universe
    fi

    # Update the list of products
    sudo apt-get update

    if [ "$install_microsoft_pwsh" == "true" ]; then
        # Install PowerShell
        sudo apt-get install -y powershell

        # check PowerShell version
        echo "PowerShell core version: $(pwsh --version)"
    fi  # Microsoft Powershell

    if [ "$install_microsoft_dotnet" == "true" ]; then
        #
        # Install dotnet core
        sudo apt-get install -y dotnet-sdk-6

        # check dotnet core version
        echo "dotnet core version: $(dotnet --version)"

    fi  # Microsoft dotnet core

    # clean up from powershell and dotnet install
    rm packages-microsoft-prod.deb

fi  # Microsoft packages


if [ "$setup_repository" == "true" ]; then
    git_user="ericrot"
    pwi_repo_branch="pwi-build-1.6"
    #
    # Clone the repository for vm-build
    if [ ! -d ~"/repos" ]; then
        mkdir ~/repos
    fi

    cd ~/repos

    # clean old repo
    if [ -d "pwi-vm-build" ]; then
        rm -rf pwi-vm-build
    fi

    # Note the following will prompt for a password for git_user
    git clone "https://${git_user}@bitbucket.org/emersonwireless/pwi-vm-build.git"
    # if using ssh with key loaded
    #git clone "ssh://git@bitbucket.org/emersonwireless/pwi-vm-build.git"

    #
    # to use the repo branch configured
     git checkout --track origin/$pwi_repo_branch
fi  # Setup repository
