# helium-validator-deb
A build script and associated files to make a debian package for Helium validators as well as a hosted, pre-compiled deb package.

A deb package provides the easiest way to install and run a Helium validator on Debian or Ubuntu. Get the performance of source with the convenience of a container.

This software is provided as-is without warranty of any kind. If you do find an issue or have questions, open an issue or reach out to me on Helium Discord @PaulM and I will do my best to respond.

Note, the hosted package was built on an AMD Zen2 machine. Please log an issue against this repo if you find compatibility issues with other processors.

# Install the hosted deb package
Process for install the deb package on Debian or Ubuntu GNU/Linux.

### 1. Add the repo to your system
Add the deb package repository as an Apt source on your system.
```
echo "deb [trusted=yes] https://apt.fury.io/myheliumvalidator/ /" | sudo tee -a /etc/apt/sources.list.d/fury.list
```

### 2. Install `validator` package
Refresh the package list from the repository and install the validator package
```
sudo apt update && sudo apt install validator
```

### 3. Add your user to `helium` group
To allow your user to call miner commands and access log files, you user needs to be added to the `helium` user group which owns the validator files. 
The following adds your current user to the group and refreshes you user's group so you can begin using immediately.
```
sudo usermod -aG helium $USER && su - $USER
```

That's it. You are now running a Helium validator. See the below and the [Helium Docs](https://docs.helium.com/mine-hnt/validators) for more detail on running the validator.


# Migrating from Docker
Switching from docker to this package requires a few additional steps due to the different file locations. The following assumes the docker install instructions from the [Helium Docs](https://docs.helium.com/mine-hnt/validators) using $HOME/validator_data as the data directory location.

1. Remove the docker container `docker stop validator && docker rm validator`
2. Install the deb package per the steps above
3. Stop the validator service `sudo systemctl stop validator`
4. Remove the new data directory created by the validator package `rm -rf /var/data/miner`
5. Move the old validator data dir `sudo mv $HOME/validator_data /var/data/miner`
6. Delete the old logs out of the data directory `sudo rm /var/data/miner/log`
7. Change ownership of the data direcotry to the helium user `sudo chown -R helium:helium /var/data/miner`
8. Restart validator service `sudo systemctl start validator`


# Upgrading the package
Upgrade is easy. Once a new version has been published, refresh apt package list and run the install again validator
```
sudo apt update && sudo apt install validator
```

If you would like to install a specific version, you can specify it in the install command
```
sudo apt update && sudo apt install validator=1.7.0
```


# Additional details

## Running validator command
The package links the miner executable to your /usr/local/bin directory so it is immediately usable at the command line by just running `miner`.

For example,
```
miner info summary
```

## Stopping and Starting the Validator
The validator is run as a systemd service. It is started by default after install and upon any reboot. Use `systemctl` for further control of the service.

- Stop Validator: `sudo systemctl stop validator`
- Start Validator: `sudo systemctl start validator`
- Restart Validator: `sudo systemctl restart validator`
- Check Validator service status: `sudo systemctl status validator`


## Validator files
The deb package (mostly) follows typical Linux conventions for file locations.

### Code - /opt/miner
For example, the miner executable is located at `/opt/miner/bin/miner`. Running `miner` executes this file. Addiitonal the Erlang config files for the validator is located here. You should not need to edit these in a typical deployment.

### Logs - /var/log/miner
You will find you find the console and error logs here.

For example, to look at absorb and commit times:
```
cat /var/log/miner/console.log | grep absorb_and_commit
```

### Blockchain Data - /var/data/miner
The blockchain and ledger databases are located here. This is also the location of the swarm_key. 

If you would like to reuse your swarm_key from another validator, stop the validator and replace the swarm_key at `/var/data/miner/miner`
