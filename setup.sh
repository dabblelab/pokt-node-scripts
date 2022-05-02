#!/bin/bash

# NOTE: before running this script update the system packages with the following command:
# apt update & apt dist-upgrade -y

echo -e "
\e[32m#############################
#   Starting Full Upgrade   #
#############################\e[0m
"
apt-get update | tee /tmp/update-output.txt

apt-get upgrade -y | tee -a /tmp/update-output.txt

echo -e "
\e[32m#############################
#  Full Upgrade Completed  #
#############################\e[0m
"

apt-get clean | tee -a /tmp/update-output.txt
echo -e "
\e[32m#############################
#     Apt Clean Complete    #
#############################\e[0m
"

# Also, set the value for /etc/hostname to the hosts fully qualified DNS name for example:
# echo "node1.pokt.run" > /etc/hostname
# After setting the hostname, reboot and ssh back into the node before running the following.

#=================Checking root environment================================================

#======================== Make sure only root can run our script============================
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

#==========================================check system type and version================================

os_type="$(lsb_release -si 2>/dev/null)"
if [ "$os_type" != "Ubuntu" ]; then
  echo "This script Only supports Ubuntu"
  exit 1
fi

if [ "$os_type" = "Ubuntu" ]; then
  os_ver="$(lsb_release -sr)"
  if [ "$os_ver" != "20.04" ]; then
    echo "Only supports Ubuntu 20.04"
    exit 1
  fi
fi

#================checking ram requirement====================================================

phymem="$(free | awk '/^Mem:/{print $2}')"
[ -z "$phymem" ] && phymem=0
if [ "$phymem" -lt 8000000 ]; then
  echoerr "A minimum of 8GB RAM is required."
  exit 1
fi


#==================== 1. install dependancies================================================
apt install git -y
apt install build-essential -y
apt install curl -y
apt install file -y
apt install jq -y
apt install bc -y
apt install nginx -y
apt install certbot -y
apt install python3-certbot-nginx -y


#================this code needs testing so am commenting it out now==========================

#===================updating dns record=======================================================
# zone=dabblelab.com

# dnsrecord=pokt.dabblelab.com

# #=========creds=============================================================================
# cloudflare_auth_email=dabblelab@cloudflare.com
# cloudflare_auth_key=--------------------------

# #================== Get the current external IP address=====================================
# ip=$(curl -s -X GET https://checkip.amazonaws.com)

# #===================check to see if record is already updated===============================
# if host $dnsrecord 1.1.1.1 | grep "has address" | grep "$ip"; then
#   echo "$dnsrecord is currently set to $ip; no changes needed"
#   exit
#   #=====script might not need to exit entirely but proceed with non exit code===============
# fi


# #==================== get the zone id for the requested zone================================
# zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
#   -H "X-Auth-Email: $cloudflare_auth_email" \
#   -H "X-Auth-Key: $cloudflare_auth_key" \
#   -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

# echo "Zoneid for $zone is $zoneid"


# #=====================get the dns record id===================================================
# dnsrecordid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$dnsrecord" \
#   -H "X-Auth-Email: $cloudflare_auth_email" \
#   -H "X-Auth-Key: $cloudflare_auth_key" \
#   -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

# echo "DNSrecordid for $dnsrecord is $dnsrecordid"


# #======================================= update the record======================================
# curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid" \
#   -H "X-Auth-Email: $cloudflare_auth_email" \
#   -H "X-Auth-Key: $cloudflare_auth_key" \
#   -H "Content-Type: application/json" \
#   --data "{\"type\":\"A\",\"name\":\"$dnsrecord\",\"content\":\"$ip\",\"ttl\":1,\"proxied\":false}" | jq



#==================set new hostname without reboot================================================
# NEW_HOSTNAME=node2.pokt.run
#note!!! this command does not work as we want currently
# hostnamectl set-hostname $NEW_HOSTNAME


# echo $HOSTNAME

OLD_HOSTNAME="$( hostname )"
NEW_HOSTNAME="node.bashiru1.com"
 
if [ -z "$NEW_HOSTNAME" ]; then

 echo "new hostname reading....:$NEW_HOSTNAME"

fi

echo "Changing hostname from $OLD_HOSTNAME to $NEW_HOSTNAME..."

hostname "$NEW_HOSTNAME"
 
sed -i "s/HOSTNAME=.*/HOSTNAME=$NEW_HOSTNAME/g" /etc/sysconfig/network
 
if [ -n "$( grep "$OLD_HOSTNAME" /etc/hosts )" ]; then
 sed -i "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
else
 echo -e "$( hostname -I | awk '{ print $1 }' )\t$NEW_HOSTNAME" >> /etc/hosts
fi
 
echo "Done."
echo $HOSTNAME
echo -e "
\e[32m#############################
#HOSTNAME HAS BEEN SET PLEASE REBOOT AND RUN THE SCRIPT AGAIN!!!!!!!!!!!!#
#############################\e[0m
"

# 2. add a user for pocket
USERNAME=pocket
PASSWORD=$(openssl rand -hex 7)
pass=""
if [ $(id -u) -eq 0 ]; then
	egrep "^$USERNAME" /etc/passwd >/dev/null
	if [ $? -eq 0 ]; then
		echo "$USERNAME exists!"
		exit 1
	else
		pass=$(perl -e 'print crypt($ARGV[0], "password")' $PASSWORD)
        useradd -m -g sudo -s /bin/bash -p "$pass" "$USERNAME"
		# su - $USERNAME
		[ $? -eq 0 ] && echo "User '$USERNAME' was added." || echo "Failed to add the user '$USERNAME'!"
	fi
else
	echo "Only root may add a user to the system."
	exit 2
fi

HOME_DIR=$( getent passwd "pocket" | cut -d: -f6 )
# sudo su - pocket;

echo "$pass" | sudo -S  -i -u pocket

cd $HOME_DIR

# 3. install go lang
echo "$pass" | sudo wget https://dl.google.com/go/go1.17.7.linux-amd64.tar.gz
echo "$pass" | sudo tar -xvf go1.17.7.linux-amd64.tar.gz
echo "$pass" | sudo chown -R "$USERNAME" $HOME_DIR
echo "export PATH=$PATH:$HOME_DIR/go/bin" >> $HOME_DIR/.profile
echo "export GOPATH=$HOME_DIR/go" >> $HOME_DIR/.profile
echo "export GOBIN=$HOME_DIR/go/bin" >> $HOME_DIR/.profile
source $HOME_DIR/.profile
go version

# 4. install pocket core
mkdir -p $GOPATH/src/github.com/pokt-network
cd $GOPATH/src/github.com/pokt-network
git clone https://github.com/pokt-network/pocket-core.git
cd pocket-core
git checkout tags/RC-0.8.2
go build -o $GOPATH/bin/pocket $GOPATH/src/github.com/pokt-network/pocket-core/app/cmd/pocket_core/main.go
pocket version

# 5. create config.json
mkdir -p $HOME_DIR/.pocket/config
touch $HOME_DIR/.pocket/config/config.json

echo $(pocket util print-configs) | jq '.tendermint_config.P2P.Seeds = "03b74fa3c68356bb40d58ecc10129479b159a145@seed1.mainnet.pokt.network:20656,64c91701ea98440bc3674fdb9a99311461cdfd6f@seed2.mainnet.pokt.network:21656,0057ee693f3ce332c4ffcb499ede024c586ae37b@seed3.mainnet.pokt.network:22856,9fd99b89947c6af57cd0269ad01ecb99960177cd@seed4.mainnet.pokt.network:23856,1243026603e9073507a3157bc4de99da74a078fc@seed5.mainnet.pokt.network:24856,6282b55feaff460bb35820363f1eb26237cf5ac3@seed6.mainnet.pokt.network:25856,3640ee055889befbc912dd7d3ed27d6791139395@seed7.mainnet.pokt.network:26856,1951cded4489bf51af56f3dbdd6df55c1a952b1a@seed8.mainnet.pokt.network:27856,a5f4a4cd88db9fd5def1574a0bffef3c6f354a76@seed9.mainnet.pokt.network:28856,d4039bd71d48def9f9f61f670c098b8956e52a08@seed10.mainnet.pokt.network:29856,5c133f07ed296bb9e21e3e42d5f26e0f7d2b2832@poktseed100.chainflow.io:26656"' | jq '.pocket_config.rpc_timeout = 15000' | jq '.pocket_config.rpc_port = "8082"' | jq '.pocket_config.remote_cli_url = "http://localhost:8082"' | jq '.tendermint_config.RootDir |= "/home/pocket/.pocket"' | jq '.tendermint_config.RPC.RootDir |= "/home/pocket/.pocket"' | jq '.tendermint_config.P2P.RootDir |= "/home/pocket/.pocket"' | jq '.tendermint_config.Mempool.RootDir |= "/home/pocket/.pocket"' | jq '.tendermint_config.Consensus.RootDir |= "/home/pocket/.pocket"' | jq '.pocket_config.data_dir |= "/home/pocket/.pocket"' > $HOME_DIR/.pocket/config/config.json

# 6. get genesis.json
cd $HOME_DIR/.pocket/config

wget https://raw.githubusercontent.com/pokt-network/pocket-network-genesis/master/mainnet/genesis.json

# 7. create chains.json

export CHAINS_JSON=$(cat <<EOF
[
    {
        "id": "0001",
        "url": "http://127.0.0.1:8082/",
        "basic_auth": {
            "username": "",
            "password": ""
        }
    }
]
EOF
)

cd $HOME_DIR/.pocket/config/ && envsubst <<< "$CHAINS_JSON" > "chains.json"

#================================Assign pocket permission && sudo group to files in $HOME_DIR/.pocket/config/======================
cd $HOME_DIR/.pocket && echo "$pass" | sudo chown -R pocket config/ && echo "$pass" | sudo chgrp -R sudo config/


#================================Assign pocket permission && sudo group to files in $HOME_DIR/.pocket/======================
cd $HOME_DIR/ && echo "$pass" | sudo chown -R pocket .pocket/ && echo "$pass" | sudo chgrp -R sudo .pocket/

cd $HOME_DIR/.pocket

#================================create pocket account withing pocket user > .pocket/=======================================
sudo -i -u pocket bash << EOF
cd $HOME_DIR/.pocket
ls
printf '\n\n' | pocket accounts create

echo 
# -- get account and export private key --
ACCOUNTS=$(pocket accounts list)

ACCOUNT=$(echo "${ACCOUNTS}" | head -1 | cut -d' ' -f2)

PRIVATE_KEY=$(printf '\n\n\n' | accounts export --path .  $ACCOUNT)

# -- set account as validator address --
printf '\n\n\n' | pocket accounts set-validator $ACCOUNT
EOF

echo "Acccount: $ACCOUNT"

# 9. set ulimits
ulimit -Sn 16384
echo "pocket           soft    nofile          16384" >> /etc/security/limits.conf
ulimit -n

# 10. configure firewall
yes | ufw enable
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 8081
ufw allow 26656
ufw status

# 11. create and enable systemd service
export POCKET_SERVICE=$(cat <<EOF
[Unit]
Description=Pocket service
After=network.target
Wants=network-online.target systemd-networkd-wait-online.service
[Service]
User=pocket
Group=sudo
ExecStart=/home/pocket/go/bin/pocket start
ExecStop=/home/pocket/go/bin/pocket stodp
[Install]
WantedBy=default.target
EOF
)

cd /etc/systemd/system/ && envsubst <<< "$POCKET_SERVICE" > "pocket.service"

# -- start the pocket service --
systemctl daemon-reload
systemctl enable pocket.service
systemctl start pocket.service

# 12. get an ssl cerfiticate
certbot --nginx --domain $HOSTNAME --register-unsafely-without-email --no-redirect --agree-tos

# 13. configure nginx proxy
export NGINX_CONFIG=$(cat <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    server_name _;
    location / {
        try_files $uri $uri/ =404;
    }
}
server {
    add_header Access-Control-Allow-Origin "*";
    listen 80 ;
    listen [::]:80 ;
    listen 8081 ssl;
    listen [::]:8081 ssl;
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    server_name $HOSTNAME;
    location / {
        try_files $uri $uri/ =404;
    }
    listen [::]:443 ssl ipv6only=on;
    listen 443 ssl;
    ssl_certificate /etc/letsencrypt/live/$HOSTNAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$HOSTNAME/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    access_log /var/log/nginx/reverse-access.log;
    error_log /var/log/nginx/reverse-error.log;
    location ~* ^/v1/client/(dispatch|relay|challenge|sim) {
        proxy_pass http://127.0.0.1:8082;
        add_header Access-Control-Allow-Methods "POST, OPTIONS";
        allow all;
    }
    location = /v1 {
        add_header Access-Control-Allow-Methods "GET";
        proxy_pass http://127.0.0.1:8082;
        allow all;
    }
}
EOF
)

cd /etc/nginx/sites-available/ && envsubst <<< "$NGINX_CONFIG" > "pocket"

systemctl stop nginx
rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/pocket /etc/nginx/sites-enabled/pocket
systemctl start nginx

