#!/bin/bash

# Ensure the script is run on Ubuntu Linux
if ! grep -q "Ubuntu" /etc/os-release; then
    echo "This script must be run on Ubuntu Linux."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_SUSPEND=1

# safety check
if [ "$1" != "INSTALL" ]; then
    printf "\n"
    printf "This is not safe unless you know what the script does. Read it first.\n\n"
    printf "For example, the script assumes you are using an AWS i4 or similar instance that support.\n"
    printf "  NVMe (Non-Volatile Memory Express) protocol. Make sure the instance has 2 EBS volumes \n"
    printf " which should appear as follows (type lsblk to show all devices): \n"
    printf "       nvme1n1      259:3    0    200G  0 disk\n"
    printf "       nvme2n1      259:4    0    100G  0 disk\n"

    printf " Check this in the AWS console before returning...\n"
    printf " When you sure you want to continue, run the script with the argument 'INSTALL'\n\n"
    exit 0
fi

echo ""
echo "This script will install and configure a self contained single node benchmarking environment"
echo " which contains: "
echo "  - local no-sql-bench install"
echo "  - single-node DSE docker container"
echo "  - Victoria Metrics docker container"
echo "  - Grafana container"
echo ''
echo "The configuration is an easy way to learn about NSB as a testing tool. The deployment can also be used "
echo " for more serious DSE testing by simply NOT using the included DSE container, but wiring nsb to connect"
echo " to any remote DSE cluster."
echo ''
echo "The process was built and tested using an Ubuntu 22.04 LTS instance type on AWS i4.xlarge instance type."
echo "  It should work fine on other ubuntu versions, but mileage may vary"

echo "If you're ready for the adventure, hit any key to continue"
read dummy

SETHOSTNAME=${SETHOSTNAME:my-nsb-node}
# Do this if you know the name
sudo hostnamectl set-hostname "${SETHOSTNAME}"

sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# put /var/lib/docker on nvme2n
sudo mke2fs /dev/nvme2n1
sudo e2label /dev/nvme2n1 docker
sudo mkdir -p /var/lib/docker
printf "LABEL=docker\t/var/lib/docker\text4\tdefaults\t0 2\n" | sudo tee -a /etc/fstab
sudo mount /var/lib/docker

# maybe missing packages
sudo DEBIAN_FRONTEND=noninteractive apt install -y jq net-tools sysstat htop curl

# remove conflicting packages for docker
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
 do sudo DEBIAN_FRONTEND=noninteractive apt-get remove $pkg
done
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
 $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
 | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y vim netdata

# verify sane docker install
sudo docker run --rm hello-world

# ubuntu user can manage docker
sudo usermod -G docker ubuntu

# make memory mapping work with large java heaps
echo "vm.max_map_count = 256000" | sudo tee -a /etc/sysctl.conf && sudo sysctl -p /etc/sysctl.conf

## get and run docker images for DSE, Victoriametrics, and Grafana
sudo docker run -e DS_LICENSE=accept --name my-dse -p 9042:9042 -d datastax/dse-server:6.9.5

sudo docker run -d -v /home/ubuntu/victoria-metrics-data:/victoria-metrics-data -p 8428:8428 --network=host victoriametrics/victoria-metrics

sudo docker run -d --name=grafana -p 3000:3000 grafana/grafana

echo ""
echo "get nosqlbench"

## rolling back nsb version
##curl -L -O https://github.com/nosqlbench/nosqlbench/releases/latest/download/nb5
curl -L -O  https://github.com/nosqlbench/nosqlbench/releases/download/5.21.3-release/nb5

chmod u+x nb5

sudo DEBIAN_FRONTEND=noninteractive add-apt-repository -y universe
sudo DEBIAN_FRONTEND=noninteractive apt install -y libfuse2

echo "Lastly lets create the argsfile for the DSE scenario"
echo "Enter the public dns name of the EC2 instance - example ec2-54-153-54-249.us-west-1.compute.amazonaws.com: "
read pub_ip

echo '--add-labels "instance:dsedocker"' > ./.nosqlbench/argsfile
echo "--annotators [{'type':'log','level':'info'},{'type':'grafana','baseurl':'http://${pub_ip}:3000'}]" >> ./.nosqlbench/argsfile
echo "--report-prompush-to http://${pub_ip}:8428/api/v1/import/prometheus/metrics/job/nosqlbench/instance/dsedocker" >> ./.nosqlbench/argsfile

echo 'Log onto the Grafana UI and create an API key for the Service Account'
echo 'then'
echo "Enter that grafana api key you created in the UI for the Service Account:"
read apikey

echo "${apikey}" > /home/ubuntu/datastax_nsb/.nosqlbench/grafana/grafana_apikey

# remount /home on nvme1n - this is done in the move_home.sh script
(. ./scripts/move_home.sh)

echo ""
echo "Setup complete!"
echo ""

echo "Next steps - aka things you can't do in the script:"
echo " - Open these ports 8428, 3000, 9042 on the AWS security group"
echo " - Connect to Victoria Metric UI at http://${pub_ip}:8428 "
echo "   - nothing needs to be set here, but you can see the metrics"
echo " - Connect to Grafana at http://${pub_ip}:3000 and: "
echo "   - Create a prometheus datasource in Grafana - NOTE determine and use the private ip for the docker process:"
echo "        - use the default datasource name: prometheus"
echo "        - to determine that ip, use ifconfig and look for the settings for the docker0 interface. will look something like"
echo "           docker0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500"
echo "           inet 172.17.0.1  netmask 255.255.0.0  broadcast 172.17.255.255"
echo "            so 172.17.0.1 is the address to use in the prometheus data source setup. when you save/test this value it should"
echo "              turn green"
echo "   - Under Admin / Users and access, create an service account and api token in the grafana UI - NOTE, make sure to give "
echo "      the SA admin rights. this token is added to a file named grafana_apikey in the ~/.nosqlbench/grafana folder"
echo "   -  create or import included dashboard - NOTE: the example dashboard assumes the default datasource name: prometheus"
echo ""
