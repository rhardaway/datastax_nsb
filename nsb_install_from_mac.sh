#!/bin/bash

# Check if the operating system is macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "This script must be run on macOS."
    exit 1
fi

echo 'This script will install and configure a self-contained single-node nsb environment'
echo '  on a remote ubuntu instance'

echo 'Provide connection info for the target host'
echo ''
read -p 'Enter the path to the PEM file: ' PEM_FILE
read -p 'Enter the EC2 Host public dns name: ' EC2_Host
read -p 'Enter the user (use ubuntu): ' USER

##PEM_FILE='/Users/bob.hardaway/work/install/bobhdsedemokey.pem'
##EC2_Host='ec2-54-193-71-43.us-west-1.compute.amazonaws.com'
##USER=ubuntu

if [ ! -f ".deployed" ]; then
    echo 'push the install package to target host'
    scp -i "$PEM_FILE" datastax_nsb.tar.gz "$USER@$EC2_Host:~/"
    ssh -i "$PEM_FILE" "$USER@$EC2_Host" 'tar -xvf datastax_nsb.tar.gz'
    touch .deployed
fi

while true; do
    echo ''
    echo 'Which steps do you want to execute?'
    echo ' 1. Check prerequisites'
    echo ' 2. Install Docker - Grafana/Victoria/DSE containers'
    echo ' 3. Remount Docker home on nvme partition'
    echo ' 4. Verify Installation'
    echo ' 5. Set grafana key value'
    echo ' 6. Install NoSQLBench'
    echo ' 7. Run NoSQLBench smoke tests'
    echo ' ALL. Run steps 2, 3, 6'
    echo ' 8. Exit'
    echo ''
    read -p 'Enter the number of the step you want to execute: ' step

    case $step in
    1)
        echo 'Checking pre-requisites'
        COMMAND='./datastax_nsb/scripts/check_prereqs.sh'
        ;;
    2)
        echo 'Installing NoSQLBench and Grafana/Victoria containers'
        COMMAND='./datastax_nsb/scripts/docker_install.sh'
        ;;
    3)
        echo 'Remounting Docker home on nvme partition'
        COMMAND='./datastax_nsb/scripts/move_home.sh'
        ;;
    4)
        echo 'Verifying Installation'
        COMMAND='./datastax_nsb/scripts/verify_install.sh'
        ;;
    5)
        echo 'Set the grafana api key value'
        COMMAND='./datastax_nsb/scripts/set_grafana_apikey.sh'
        ;;
    6)
        echo 'Install NoSQLBench'
        COMMAND='./datastax_nsb/scripts/install_nsb.sh'
        ;;
    7)
        echo 'Running NoSQLBench smoke tests'
        COMMAND='./datastax_nsb/scripts/run_nsb_tests.sh'
        ;; 
    8)
        echo 'Exiting...'
        break
        ;;
    ALL)
        COMMAND='./datastax_nsb/scripts/docker_install.sh'
        ssh -i "$PEM_FILE" "$USER@$EC2_Host" "$COMMAND"
        COMMAND='./datastax_nsb/scripts/move_home.sh'
        ssh -i "$PEM_FILE" "$USER@$EC2_Host" "$COMMAND"
        COMMAND='./datastax_nsb/scripts/install_nsb.sh'
        ;;
    *)
        echo 'Invalid entry, try again'
        ;;
    esac

    ssh -i "$PEM_FILE" "$USER@$EC2_Host" "$COMMAND"
done

echo 'Done'


ec2-54-193-71-43.us-west-1.compute.amazonaws.com