#!/bin/bash
    echo -e "\e[96m Do not run this script with sudo. The script will use sudo when appropiate.\e[39m"
    echo -e "\e[96m This script is meant to be run with Ubuntu 18.04. It might work with higher versions but it hasn't been tested.\e[39m"
    echo -e "\e[96m Please ensure that all servers in the cluster have full access to each other.\e[39m"
    echo -e "\e[96m Make sure that all the worker nodes have the same password. \e[39m"
    echo -e "\e[96m When complete, go to http://ipaddress_of_prime:3000 Default user: admin, password: admin.\e[39m"
    echo -e "\e[96m Press Enter to continue. \e[39m"
    read y 

#Make sure the tar file is present.
executablestest=$(ls executables.tar.gz)
                   if [[ "$executablestest" != "executables.tar.gz" ]]; then	
                        echo -e "\e[96m The file executables.tar.gz was not found in the same directory as the install script SSH. \e[39m"
                        echo -e "\e[96m Please resolve and run the script again. \e[39m"
                        exit
                    fi

#install sshpas
sudo apt-get install -y sshpass

#Get password for postgres
    echo -e "\e[96m Please enter the password for the database.  \e[39m"
    read psqlpass


#Get node IP info from end user
    echo -e "\e[96m Enter a comma seperated list of all workernode IP addresses. (This is the Prime node)"
    echo -e "Example 192.0.2.1,192.0.2.33,192.0.2.99 \e[39m"
    #read ipaddressin
    IFS=',' read -r -a ipaddresses

# Get IP address of the Prime
    echo -e "\e[96m This device is being configured as the Prime. Enter the IP address of the interface used to communicate with the worker nodes."
    echo -e "\e[96m e.g. 192.0.2.100 \e[39m"
    read masterip


#Get syslog port
    echo -e "\e[96m Enter the port that will be used to receive logs. (e.g. 514) \e[39m"
    read port

#Ask for password 
    echo -e "\e[96m The system needs to ssh into the worker nodes to complete the install. \e[39m" 
        echo -e "\e[96m Enter the password for the remote worker. \e[39m" 
        read -s sspass1
        echo -e "\e[96m Enter password again. \e[39m"
        read -s sspass2

        while [[ "$sspass1" != "$sspass2" ]]; do	
         
            echo -e "\e[96m The passwords do not match. Let's try again. \e[39m" 
            echo -e "\e[96m Enter password. \e[39m" 
            read -s sspass1
            echo -e "\e[96m Enter password again. \e[39m"
            read -s sspass2         
        done

export SSHPASS="$sspass1"

# Check for Ping reachablility
    for address in "${ipaddresses[@]}"
         do

            pingtest=$(ping -nq -w 2 -c 1 $address | grep -o "=")    

                    if [[ "$pingtest" != "=" ]]; then	
                        echo -e "\e[96m $address is not reachable via ping. \e[39m"
                        echo -e "\e[96m Please resolve and try again. \e[39m"
                        exit
                      
                    fi

         done

	 echo -e "\e[96m Success! All devices rechable via ping. Continuing. \e[39m"
     sleep 2

# Check for SSH reachablility
    for address in "${ipaddresses[@]}"
         do


            linux=$(sshpass -ev ssh -o "StrictHostKeyChecking=no" $address uname)    

                    if [[ "$linux" != "Linux" ]]; then	
                        echo -e "\e[96m $address is not reachable via SSH. \e[39m"
                        echo -e "\e[96m Please resolve and try again. \e[39m"
                        exit
                      
                    fi


         done


	echo -e "\e[96m Success! All devices rechable via SSH. Continuing. \e[39m"
    sleep 2

#Install code on remote devices

    for address in "${ipaddresses[@]}"
         do
	      echo -e "\e[96m Starting process for $address: \e[39m"
            sshpass -ev rsync -avz -e ssh --progress executables.tar.gz remoterun.sh workerstart.sh sliceworker.service $address:
            sshpass -ev ssh -t -o "StrictHostKeyChecking=no"  $address "echo $sspass1 | sudo -S ./remoterun.sh"
	    
            insed="echo $sspass1 | sudo -S sed -i 's/{MASTER_IP}/$masterip/g' /opt/sliceup/executables/flink-1.10.0/conf/flink-conf.yaml"
	        sshpass -ev ssh -t -o "StrictHostKeyChecking=no"  $address "$insed"  

            insed="echo $sspass1 | sudo -S sed -i 's/{MASTER_IP}/$masterip/g' /opt/sliceup/executables/conf.ini"
	        sshpass -ev ssh -t -o "StrictHostKeyChecking=no"  $address "$insed"  

            insed="echo $sspass1 | sudo -S sed -i 's/{WORKER_IP}/$address/g' /opt/sliceup/executables/conf.ini"
            sshpass -ev ssh -t -o "StrictHostKeyChecking=no"  $address "$insed"  

            sshpass -ev ssh -o "StrictHostKeyChecking=no" $address "echo $sspass1 | sudo -S systemctl start sliceworker.service"

            echo -e "\e[96m Process finished for $address. \e[39m"
            sleep 2
         done

    echo -e "\e[96m All worker nodes installed complete. \e[39m"
    sleep 2



#Check to see if Java working on remote node.
    for address in "${ipaddresses[@]}"
         do

            jversion=$(sshpass -ev ssh -o "StrictHostKeyChecking=no" $address java --version | grep -oh 'OpenJDK 64-Bit')    

                    if [[ "$jversion" != "OpenJDK 64-Bit" ]]; then	
                        echo -e "\e[96m $address is not Running the correct version of Java. \e[39m"
                        echo -e "\e[96m Please resolve and run script again. \e[39m"
                        exit                      
                    fi


         done



	echo -e "\e[96m Success! All devices running correct Java version. Continuing install of master node. \e[39m"
    sleep 2


##########################Begin Prime Install#####################################

	echo -e "\e[96m Starting Prime's install. \e[39m"

#update system
    sudo apt-get update
#create directory structure
    sudo mkdir /opt/sliceup
    sudo mkdir /opt/sliceup/scripts
    sudo chmod -R a+r /opt/sliceup
    sudo mkdir /opt/sliceup/dashboards
    sudo mkdir /opt/sliceup/ssl
    cuser=$(whoami)
    sudo chown -R $cuser /opt/sliceup



	sudo rm workerinstall.sh
	sudo rm workerstart.sh
	sudo rm sliceworker.service
	sudo mv masterstart.sh /opt/sliceup/scripts/masterstart.sh
	sudo mv masterinstall.sh /opt/sliceup/scripts/masterinstall.sh
	sudo chmod +x /opt/sliceup/scripts/masterstart.sh
	sudo mv slicemaster.service /etc/systemd/system/slicemaster.service
	

# begin install


#curl https://transfer.sh/wROIc/executables.tar.gz -o executables.tar.gz
    echo -e "\e[96m Extract Files and install JAVA  \e[39m"
    sudo tar -xvzf executables.tar.gz --directory /opt/sliceup/
    #sudo chmod -R a+r /opt/sliceup
    sudo apt install openjdk-11-jre-headless -y
    sudo apt install openjdk-11-jdk-headless -y

#changing curl --proto '=https' --tlsv1.2 -sSf https://sh.vector.dev | sh
    echo -e "\e[96m Install Vector and Postgres  \e[39m"
    curl --proto '=https' --tlsv1.2 -O https://packages.timber.io/vector/0.9.X/vector-amd64.deb
    sudo dpkg -i vector-amd64.deb
    sudo systemctl start vector
    sudo apt install postgresql-client -y
    sudo apt install postgresql -y
    sleep 10

#create variable requires config for sliceupdev
    echo -e "\e[96m Config Postgres.  \e[39m"
    sudo -u postgres psql -c "CREATE USER sliceup WITH PASSWORD '$psqlpass';"
    sudo -u postgres psql -c "ALTER ROLE sliceup WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN NOREPLICATION NOBYPASSRLS;"
    sudo -u postgres psql -c "CREATE DATABASE sliceup"
    sudo -u postgres psql sliceup < /opt/sliceup/executables/db_migration/sourcedb.sql

#Lock this down and standardize install

    sudo sed -i "s/#listen_addresses.*/listen_addresses = '*'/" /etc/postgresql/10/main/postgresql.conf
   

# take user entered IP addresses and create hba config
    for address in "${ipaddresses[@]}"
    do
        line="host    all             all             $address\/32            md5"
        sudo sed -i "s/# IPv4 local connections:/# IPv4 local connections:\n$line/" /etc/postgresql/10/main/pg_hba.conf
    done

    line="host    all             all             $masterip\/32            md5"
    sudo sed -i "s/# IPv4 local connections:/# IPv4 local connections:\n$line/" /etc/postgresql/10/main/pg_hba.conf


    echo -e "\e[96m Install additonal supporting files.  \e[39m"

    sudo systemctl restart postgresql
    sudo apt-get install libpq-dev -y
    sudo apt-get install python-dev -y
    sudo apt-get install python3-dev -y
    sudo apt-get install build-essential -y
    sudo apt-get install build-essential autoconf libtool pkg-config python-opengl python-pil python-pyrex python-pyside.qtopengl idle-python2.7 qt4-dev-tools qt4-designer libqtgui4 libqtcore4 libqt
4-xml libqt4-test libqt4-script libqt4-network libqt4-dbus python-qt4 python-qt4-gl libgle3 python-dev -y
    sudo apt install python3-pip -y
    python3 -m pip install psycopg2
    python3 -m pip install requests
    python3 -m pip install PrettyTable
    python3 -m pip install selenium
    python3 -m pip install kafka-python


    echo -e "\e[96m Replace variable information in configs  \e[39m"

    sudo sed -i "s/{MASTER_IP}/$masterip/" /opt/sliceup/executables/kafka_2.12-2.4.1/config/server-1.properties
    sudo sed -i "s/{MASTER_IP}/$masterip/" /opt/sliceup/executables/kafka_2.12-2.4.1/config/server-2.properties
    sudo sed -i "s/{MASTER_IP}/$masterip/" /opt/sliceup/executables/kafka_2.12-2.4.1/config/server-3.properties
    sudo sed -i "s/{MASTER_IP}/$masterip/" /opt/sliceup/executables/kafka_2.12-2.4.1/config/server-4.properties

# Ensure Permissions
                cuser=$(whoami)
                sudo chown -R $cuser /opt/sliceup

#Replace {MASTER_IP} to executables/vector/vector.toml
    sudo sed -i "s/{MASTER_IP}/$masterip/g" /opt/sliceup/executables/vector/vector.toml
    sudo sed -i "s/{RECEIVING_PORT}/$port/g" /opt/sliceup/executables/vector/vector.toml

        
#Enable vector to run on port lower than 1024
           sudo setcap 'cap_net_bind_service=+ep' /usr/bin/vector


#Replace {MASTER_IP} in executables/flink-1.10.0/conf/flink-conf.yaml
    sudo sed -i "s/{MASTER_IP}/$masterip/g" /opt/sliceup/executables/flink-1.10.0/conf/flink-conf.yaml
       

#Replace {MASTER_IP} in executables/conf.ini
    sudo sed -i "s/{MASTER_IP}/$masterip/g" /opt/sliceup/executables/conf.ini

#Replace Postgres password
    sudo sed -i "s/{PSQL_PASS}/$psqlpass/" /opt/sliceup/executables/conf.ini

    
#Replace {WORKER_IPS} in executables/flink-1.10.0/conf/slaves with list of worker ips
    # The current file is blank so adding marker
    echo "" > /opt/sliceup/executables/flink-1.10.0/conf/slaves

#Replace Grafana sed
sudo sed -i "s/{MASTER_IP}/$masterip/" san.cnf

       
#Grafana Install
    echo -e "\e[96m Installing Grafana.  \e[39m"
    sudo apt-get install -y adduser libfontconfig1
    wget https://dl.grafana.com/oss/release/grafana_7.0.4_amd64.deb
    sudo dpkg -i grafana_7.0.4_amd64.deb

#Grafana Create Cert
    openssl req -x509 -nodes -days 730 -newkey rsa:2048 -keyout /opt/sliceup/ssl/key.pem -out /opt/sliceup/ssl/cert.pem -config san.cnf
    sudo chown -R $cuser:grafana /opt/sliceup/ssl
    chmod 644 /opt/sliceup/ssl/*

#Grafana change and move files

    sudo sed -i "s/;protocol = http/protocol = https/" /etc/grafana/grafana.ini
    sudo sed -i "s/;http_addr =/http_addr = 0.0.0.0/" /etc/grafana/grafana.ini
    sudo sed -i "s/;http_port = 3000/http_port = 3000/" //etc/grafana/grafana.ini
    sudo sed -i "s/;cert_file =/cert_file = \/opt\/sliceup\/ssl\/cert.pem/" /etc/grafana/grafana.ini
    sudo sed -i "s/;cert_key =/cert_key = \/opt\/sliceup\/ssl\/key.pem/" /etc/grafana/grafana.ini


    sudo sed -i "s/psqlpass/$psqlpass/g" slicedatasource.yaml
    sudo mv sliceupdashboards/*.* /opt/sliceup/dashboards/
    sudo mv sliceprov.yaml /etc/grafana/provisioning/dashboards
    sudo mv slicedatasource.yaml /etc/grafana/provisioning/datasources

    

####Begin Prime Start#####
echo -e "\e[96m Installation is complete. Starting Prime Service.  \e[39m"
sleep 2

###################Starting the Services#######################3
#  Grafana Start
    sudo /bin/systemctl daemon-reload
    sudo /bin/systemctl enable grafana-server
    sudo /bin/systemctl start grafana-server

    sudo apt-get install -y jq
    sudo /bin/systemctl stop grafana-server
    sleep 5
    sudo /bin/systemctl start grafana-server
    sleep 5
    id=$(curl -k -X GET -H "Content-Type: application/json" https://admin:admin@127.0.0.1:3000/api/dashboards/uid/kC8AXaZMz | jq .dashboard.id)
    echo -e "\e[96m Dashboard ID is $id \e[39m"
    curl -k -X PUT -H "Content-Type: application/json" -d '{"theme": "", "homeDashboardId": '$id', "timezone": ""}' https://admin:admin@127.0.0.1:3000/api/org/preferences

    echo -e "\e[96m Grafana installed successfully. \e[39m"
    sleep 2

#Enable service at startup
echo -e "\e[96m Enable SlicePrimw service  \e[39m"
sudo systemctl enable slicemaster
echo -e "\e[96m Start SlicePrime service  \e[39m"
sudo systemctl start slicemaster
echo -e "\e[96m SlicePrime service started. \e[39m"

