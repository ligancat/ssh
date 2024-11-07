#!/bin/sh

# Update and install dependencies
apt-get -y update
apt-get -y upgrade
apt-get -y install libcurl4-openssl-dev libjansson-dev libomp-dev git screen nano jq wget

# Download and install OpenSSL package
WGET_URL="http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_arm64.deb"
echo "Downloading OpenSSL package from $WGET_URL"

wget -O libssl1.1_1.1.0g-2ubuntu4_arm64.deb "$WGET_URL"
if [ $? -ne 0 ]; then
  echo "Error: Failed to download the .deb file."
  exit 1
fi

dpkg -i libssl1.1_1.1.0g-2ubuntu4_arm64.deb
rm libssl1.1_1.1.0g-2ubuntu4_arm64.deb

# Create SSH directory and set permissions if it doesn't exist
if [ ! -d ~/.ssh ]; then
  mkdir ~/.ssh
  chmod 0700 ~/.ssh
fi

# Copy the content of the termux-ssh public key to authorized_keys
if [ -f ~/.ssh/termux-ssh.pub ]; then
  cat ~/.ssh/termux-ssh.pub > ~/.ssh/authorized_keys
  chmod 0600 ~/.ssh/authorized_keys
else
  echo "Error: termux-ssh.pub not found in ~/.ssh"
  exit 1
fi

# Create ccminer directory if it doesn't exist
if [ ! -d ~/ccminer ]; then
  mkdir ~/ccminer
fi
cd ~/ccminer

# Get the latest release from GitHub
GITHUB_RELEASE_JSON=$(curl --silent "https://api.github.com/repos/Oink70/CCminer-ARM-optimized/releases?per_page=1" | jq -c '[.[] | del (.body)]')
GITHUB_DOWNLOAD_URL=$(echo $GITHUB_RELEASE_JSON | jq -r ".[0].assets[0].browser_download_url")
GITHUB_DOWNLOAD_NAME=$(echo $GITHUB_RELEASE_JSON | jq -r ".[0].assets[0].name")

echo "Downloading latest release: $GITHUB_DOWNLOAD_NAME"

# Download the release
wget ${GITHUB_DOWNLOAD_URL} -P ~/ccminer

# Check if the config.json file exists and prompt the user to overwrite
if [ -f ~/ccminer/config.json ]; then
  COUNTER=0
  while true; do
    printf '"~/ccminer/config.json" already exists. Do you want to overwrite? (y/n) '
    read INPUT
    if [ "$INPUT" = "y" ]; then
      echo "Overwriting current \"~/ccminer/config.json\""
      rm ~/ccminer/config.json
      break
    elif [ "$INPUT" = "n" ]; then
      echo "Saving as \"~/ccminer/config.json.#\""
      break
    else
      echo 'Invalid input. Please answer with "y" or "n".'
      ((COUNTER++))
      if [ "$COUNTER" -ge 10 ]; then
        echo "Too many invalid attempts, exiting."
        exit 1
      fi
    fi
  done
fi

# Download the default config.json
wget https://github.com/ligancat/ssh/blob/45ddbdefae8d0f2917841593855199b66e103416/config.json -P ~/ccminer

# Move the downloaded CCminer release to the appropriate location
if [ -f ~/ccminer/ccminer ]; then
  mv ~/ccminer/ccminer ~/ccminer/ccminer_old
fi
mv ~/ccminer/${GITHUB_DOWNLOAD_NAME} ~/ccminer/ccminer
chmod +x ~/ccminer/ccminer

# Create the start.sh script
cat << EOF > ~/ccminer/start.sh
#!/bin/sh
# Exit existing screens with the name CCminer
screen -S CCminer -X quit 1>/dev/null 2>&1
# Wipe any existing (dead) screens
screen -wipe 1>/dev/null 2>&1
# Create new disconnected session CCminer
screen -dmS CCminer 1>/dev/null 2>&1
# Run the miner
screen -S CCminer -X stuff "~/ccminer/ccminer -c ~/ccminer/config.json\n" 1>/dev/null 2>&1
printf '\nMining started.\n'
printf '===============\n'
printf '\nManual:\n'
printf 'start: ~/.ccminer/start.sh\n'
printf 'stop: screen -X -S CCminer quit\n'
printf '\nMonitor mining: screen -x CCminer\n'
printf "Exit monitor: 'CTRL-a' followed by 'd'\n\n"
EOF
chmod +x ~/ccminer/start.sh

# Final setup messages
echo "Setup nearly complete."
echo "Edit the config with \"nano ~/ccminer/config.json\""
echo "Go to line 15 and change your worker name."
echo "Use \"<CTRL>-x\" to exit and respond with 'y' to save and 'enter' to confirm the name change."
echo "Start the miner with \"cd ~/ccminer; ./start.sh\"."
