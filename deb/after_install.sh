# make log directory
mkdir -p /var/log/miner
chown -R helium:helium /var/log/miner

# make data directory
mkdir -p /var/data/miner
chown -R helium:helium /var/data/miner

# add miner to /usr/local/bin so it appears in path
ln -s /opt/miner/bin/miner /usr/local/bin/miner
