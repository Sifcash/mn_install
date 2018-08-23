#!/bin/bash
#
# Copyright (C) 2018 Sifcash Team
#
# mn_install.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# mn_install.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with mn_install.sh. If not, see <http://www.gnu.org/licenses/>
#

# Only Ubuntu 16.04 supported at this moment.

set -o errexit

# OS_VERSION_ID=`gawk -F= '/^VERSION_ID/{print $2}' /etc/os-release | tr -d '"'`

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
sudo apt install curl wget git python3 python3-pip virtualenv -y

SIF_DAEMON_USER_PASS=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo ""`
SIF_DAEMON_RPC_PASS=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 ; echo ""`
MN_NAME_PREFIX=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6 ; echo ""`
MN_EXTERNAL_IP=`curl -s -4 ifconfig.co`

sudo useradd -U -m sifcash -s /bin/bash
echo "sifcash:${SIF_DAEMON_USER_PASS}" | sudo chpasswd
sudo wget https://github.com/Sifcash/sifcash/releases/download/v0.8.2.1/sifcash-0.8.2.1-cli-linux.tar.gz --directory-prefix /home/sifcash/
sudo tar -xzvf /home/sifcash/sifcash-0.8.2.1-cli-linux.tar.gz -C /home/sifcash/
sudo rm /home/sifcash/sifcash-0.8.2.1-cli-linux.tar.gz
sudo mkdir /home/sifcash/.sifcashcore/
sudo chown -R sifcash:sifcash /home/sifcash/sifcash*
sudo chmod 755 /home/sifcash/sifcash*
echo -e "rpcuser=sifcashrpc\nrpcpassword=${SIF_DAEMON_RPC_PASS}\nlisten=1\nserver=1\nrpcallowip=127.0.0.1\nmaxconnections=256" | sudo tee /home/sifcash/.sifcashcore/sifcash.conf
sudo chown -R sifcash:sifcash /home/sifcash/.sifcashcore/
sudo chown 500 /home/sifcash/.sifcashcore/sifcash.conf

sudo tee /etc/systemd/system/sifcash.service <<EOF
[Unit]
Description=Sifcash, distributed currency daemon
After=network.target

[Service]
User=sifcash
Group=sifcash
WorkingDirectory=/home/sifcash/
ExecStart=/home/sifcash/sifcashd

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=2s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable sifcash
sudo systemctl start sifcash
echo "Booting SIF node and creating keypool"
sleep 140

MNGENKEY=`sudo -H -u sifcash /home/sifcash/sifcash-cli masternode genkey`
echo -e "masternode=1\nmasternodeprivkey=${MNGENKEY}\nexternalip=${MN_EXTERNAL_IP}:14033" | sudo tee -a /home/sifcash/.sifcashcore/sifcash.conf
sudo systemctl restart sifcash

echo "Installing sentinel engine"
sudo git clone https://github.com/Sifcash/sentinel.git /home/sifcash/sentinel/
sudo chown -R sifcash:sifcash /home/sifcash/sentinel/
cd /home/sifcash/sentinel/
sudo -H -u sifcash virtualenv -p python3 ./venv
sudo -H -u sifcash ./venv/bin/pip install -r requirements.txt
echo "* * * * * sifcash cd /home/sifcash/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" | sudo tee /etc/cron.d/sifcash_sentinel
sudo chmod 644 /etc/cron.d/sifcash_sentinel

echo " "
echo " "
echo "==============================="
echo "Masternode installed!"
echo "==============================="
echo "Copy and keep that information in secret:"
echo "Masternode key: ${MNGENKEY}"
echo "SSH password for user \"sifcash\": ${SIF_DAEMON_USER_PASS}"
echo "Prepared masternode.conf string:"
echo "mn_${MN_NAME_PREFIX} ${MN_EXTERNAL_IP}:14033 ${MNGENKEY} INPUTTX INPUTINDEX"

exit 0
