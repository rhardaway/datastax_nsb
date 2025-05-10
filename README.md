# datastax_nsb
## Extensions for the no-sql-bench utility

This package allows the user to create and deploy a single node implementation of NOSQLBench
and its associated apps for testing of DSE (or OSS) clusters.

The script can be executed directly from a target instance, or locally from a mac

This script will install and configure a self contained single node benchmarking environment containing: 
  - local no-sql-bench install
  - Docker Containers for:
      - A single-node DSE 6.9.6 instance
      - Victoria Metrics database for Prometheus
      - Grafana Metrics Dashboard

The instance can be used as is to get acclimated to nosqlbench. You can also change the config to point to any DSE/OSS cluster to perform more invasive testing

## 0. WARNING - Pre-requisites

Before executing the scripts, you need to provision an EC2 (or other vm) instance and
clone this repo onto the machine (or your local mac). The script assumes you add 2 nvme (Non-Volatile Memory Express) 
volumes, one for docker and the other for /home. This ensures adequate i/o performance of the solution.

From the vm, type this command to determine what volumes are available

```
lsblk
```

Look for something like this, indicating 2, high iops volumes are available:

    nvme1n1      259:3    0    200G  0 disk
    nvme2n1      259:4    0    100G  0 disk

## 1. EC2 Provisioning

### Choose an ubuntu flavor - tested with version 22.04

![Ubuntu version](./img/Ubuntu2204.png)

### Choose an instance type - tested with i4, must support nvme devices

![Instance Type](./img/EC2_i4.png)

### Create 2 addtional volumes - use io1 for optimal iops performance

![io1 Volumes](./img/AWSConfigureStorage.png)

## 2. Deploy the instance

Access the instance from the AWS console

![Connection URL](./img/EC2Instance.png)

Click the connect tab to see the syntax for an ssh connection. NOTE: need to download the apporpriate key pair (pem file)

![Connection URL](./img/EC2Connect.png)

## 3. use ssh to login to the ubuntu vm. Skip this step if installing from mac

```
ssh -i nameOfPEMFile.pem ubuntu@ec2-54-183-159-106.us-west-1.compute.amazonaws.com
```

## 4. Clone the git repo

```
git clone https://github.com/rhardaway/datastax_nsb.git
cd datastax_nsb
```

The tool can be used one of two ways:

### If running from ubuntu:

```
./nsb_install_ubuntu.sh
```

### Or, if running from your local mac and run:

```
./nsb_install_from_mac.sh
```

For the local MAC run, you will need the following info:

```
PEM_FILE='/Users/bob.hardaway/work/install/myec2key.pem'
EC2_Host='ec2-52-53-171-73.us-west-1.compute.amazonaws.com'
USER=ubuntu
```
NOTE: when you first ssh to a node, there is a key check that asks do you want to continue, don't panic, this is natural. It's also pretty natural to get an error, the
most popular one is that the key file permissions are lax.

```
chmod 600 myec2key.pem
```

## 5. Verify things went well:

```
./scripts/verify_install.sh
```

## 6. The script will prompt for:

 - The public dns name of your instance, you can get this in the EC2 console
 - The Grafana API key to allow data to be published to the dashboard. 
   - Leave this session open at the prompt
   - Continue with steps outlined in section 7 to generate the key
   - Then return to this session to paste the generated key and finalize setup
   - **NOTE:** you will need to open another connection to your ec2 instance if running on AWS

## 7. Steps required to generate a Grafana API Key

 - Process overview:
   - Open ports to provide access from outside VM
   - Access Grafana portal
   - Create a Prometheus datasource
   - Create a Service Account and API Token
   - Import included dashboard
   - Go back to previous step to supply API Token

### Access AWS Console, navigate to your vm, click the security tab and add 3 new rules
- Open ports 8428, 3000, 9042 on the AWS security group

![Instance Type](./img/AWSSecurityGroup.png)
![Instance Type](./img/Add3Rules.png)

### Save the Public IP Address of your ec2 Instance
![Instance Type](./img/PublicIP.png)

### Login to Grafana
- Connect to Grafana at http://<ec2-public-ip-address>:3000 
- Default login: admin/admin

![Instance Type](./img/GrafanaLogin.png)

### Create a new Prometheus Connection

![Instance Type](./img/AddPrometheusConnection.png)

### Create a new Prometheus Data Source
- You need the local IP the Docker container is running on.  This can be retrieved by logging another terminal session for your ec2 instance and typing in:
   
   ```
   ifconfig
   ```

- Look for the IP under the section ``` docker0 ``` (It should be something like: 172.17.0.1)

![Instance Type](./img/LocalIP.png)

- **NOTE: Leave the default name 'prometheus'.  If you change this nb5 config must be changed!**
- The vm port for Prometheus/Victoria Metrics DB is 8428 by default

![Instance Type](./img/AddPrometheusData.png)


### Test and Save the string

![Save and Test](./img/ProSaveandTest.png)


### Create a Service Account.
- **NOTE: Make sure to select the Admin role for the account. Without this the publisher will NOT have the necessary permissions.**

![Save and Test](./img/SAAdd.png)

![Save and Test](./img/ServiceAccountADMIN.png)

### Create an API Token for the account. 
- Paste this value into the terminal you left above. 
- *NOTE:* you can run the set_grafana_apikey.sh script to set this value in the VM if you didn't supply the key above.

![Save and Test](./img/TokenCopy.png)

### Import the sample Dashboard. 
- Import button is at the top-right in Grafana UI.
- ``` dashboard.json ``` is in the root of this repo.
- **TIP: You may encounter a bug with import, if you do just copy/paste the json.**

![Save and Test](./img/DashUpload.png)
![Save and Test](./img/DashImportRight.png)
![Save and Test](./img/AwSnap.png)
![Save and Test](./img/DashImport.png)


## 8. Run the Nosqlbench smoke tests:
- This will execute the builtin cql_starter test as well as the test included in the test.yaml file
- Visit the grafana UI Dashboard to see stats. NOTE: It takes 30sec or more for the dashboard to update once a test is run.
- Check the nosqlbench doc for more on test execution: https://docs.nosqlbench.io/introduction/

```
./scripts/run_nsb_tests.sh
