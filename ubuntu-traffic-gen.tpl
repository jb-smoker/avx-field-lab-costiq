#! /bin/bash
sudo hostnamectl set-hostname ${name}
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
# Add workload user
sudo adduser workload
sudo echo "workload:${password}" | sudo /usr/sbin/chpasswd
sudo sed -i'' -e 's+\%sudo.*+\%sudo  ALL=(ALL) NOPASSWD: ALL+g' /etc/sudoers
sudo usermod -aG sudo workload
sudo service sshd restart
# Set logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
# Update packages
sudo apt update -y
sudo apt -y install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update -y
sudo apt-get install sshpass -y
sudo apt-get install cron -y
# Traffic gen
cat <<SCR >>/home/workload/cron.sh
#!/bin/bash
for i in \$(echo ${internal}|tr "," "\n"); do echo -e "22" | xargs -i sudo nc -w 1 -vn \$i {}; echo "\$(date): netcat \$i" | sudo tee -a /var/log/traffic-gen.log; done
for i in \$(echo ${internal}|tr "," "\n"); do sudo curl --insecure -m 1 https://\$i; echo "\$(date): curl \$i" | sudo tee -a /var/log/traffic-gen.log; done
for i in \$(echo ${internal}|tr "," "\n"); do sudo ping -c 4 \$i; echo "\$(date): ping \$i" | sudo tee -a /var/log/traffic-gen.log; done
SCR
chmod +x /home/workload/cron.sh
crontab<<CRN
*/${interval} * * * * /home/workload/cron.sh
0 10 * * * rm -f /var/log/traffic-gen.log
CRN
systemctl restart cron
EOF
