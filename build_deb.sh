#!/bin/bash
#
# Script to build the Helium Validator 
# as a debian package

set -e

# OPTIONS
ERL_VERSION=24.3.4
ERL_DIR=~/erl
export CFLAGS="-O3"
export CXXFLAGS="-O3"
export ERL_COMPILER_OPTIONS="[deterministic]"


# Identify architecture
arch=$(uname -i)

if [ "$arch" == 'x86_64' ]
then
    ARCH=amd64 
elif [ "$arch" == 'aarch64' ]
then
    ARCH=arm64
else
    echo "Unable to detect architecture"
    exit
fi
echo "Detected architecture ${ARCH}"


# Make sure deps are ready
rustup update
. ${ERL_DIR}/${ERL_VERSION}/activate

# Clone helium miner repo if not already exists, fetch latest
git clone https://github.com/helium/miner || true
cd miner
git fetch


# Get tag from github is not passed as parameter
if [ -z "$1" ]
then
        echo "Pulling latest tag from github..."
        VERSION_TAG=$(git describe --match "validator*" --abbrev=0 --tags $(git rev-list --tags --max-count=1))
        echo "Found version: $VERSION_TAG"
else
        VERSION_TAG=$1
fi


# Make sure there are no other tags associated to the same commit as selected tag
git checkout tags/${VERSION_TAG}
COMMIT=$(git rev-list -n 1 ${VERSION_TAG})
for tag in $(git tag --points-at ${COMMIT});
do
	git tag -d ${tag}
done
git tag -a ${VERSION_TAG}+deb.pkg -m "MyHeliumValidator version ${VERSION_TAG}" ${COMMIT}^{}


# Build the validator miner
VERSION="$(echo $VERSION_TAG | sed -e 's,validator,,')"
./rebar3 as validator release -n miner -v ${VERSION}+deb.pkg


# Get the genesis block
wget -O /tmp/genesis https://snapshots.helium.wtf/genesis.mainnet


cd ../

# Time to make the package. Clean up old ones first
rm -f *.deb

## STANDARD PACKAGE


fpm -n validator \
   -v "${VERSION}" \
   -s dir \
   -t deb \
   --depends libsodium23 \
   --depends libncurses5 \
   --depends dbus \
   --depends libstdc++6 \
   --deb-systemd deb/validator.service \
   --before-install deb/before_install.sh \
   --after-install deb/after_install.sh \
   --deb-no-default-config-files \
   --deb-systemd-enable \
   --deb-systemd-auto-start \
   --deb-systemd-restart-after-upgrade \
   --deb-user helium \
   --deb-group helium \
   --maintainer PaulVMo@github.com \
   --url https://github.com/PaulVMo/helium-validator-deb \
   --description "Debian package for Helium Network Validator. Build with OTP ${ERL_VERSION}" \
   miner/_build/validator/rel/=/opt \
   /tmp/genesis=/opt/miner/update/genesis


# Upload to Gemfury
curl -F package=@validator_${VERSION}_${ARCH}.deb https://${FURY_TOKEN}@push.fury.io/myheliumvalidator/



## MAKE THE MULTIPLE NUMBERED PACKAGES

GRPC_PORT=8080
P2P_PORT=2154
JSONRPC_PORT=4467

for i in {1..6}
do
	MINER_NUMBER=${i}
	export GRPC_PORT P2P_PORT JSONRPC_PORT MINER_NUMBER

	cat deb/validator.service.template | envsubst > /tmp/validator${i}.service
    cat deb/before_install.sh.template | envsubst > /tmp/before_install.sh
	cat deb/after_install.sh.template | envsubst > /tmp/after_install.sh
	cat deb/vm.args.template | envsubst > miner/_build/validator/rel/miner/releases/${VERSION}+deb.pkg/vm.args

	fpm -n validator${i} \
	    -v "${VERSION}" \
	    -s dir \
	    -t deb \
	    --depends libsodium23 \
	    --depends libncurses5 \
	    --depends dbus \
	    --depends libstdc++6 \
	    --deb-systemd /tmp/validator${i}.service \
	    --before-install /tmp/before_install.sh \
	    --after-install /tmp/after_install.sh \
	    --deb-no-default-config-files \
	    --deb-systemd-enable \
	    --deb-systemd-auto-start \
	    --deb-systemd-restart-after-upgrade \
	    --deb-user helium \
	    --deb-group helium \
	    --maintainer PaulVMo@github.com \
	    --url https://github.com/PaulVMo/helium-validator-deb \
	    --description "Debian package for Helium Network Validator. Build with OTP ${OTP_VERSION}" \
	    miner/_build/validator/rel/miner/=/opt/miner${i} \
	    /tmp/genesis=/opt/miner${i}/update/genesis


	# Upload to Gemfury
	echo "uploading: validator${i}_${VERSION}_${ARCH}.deb"
	curl -F package=@validator${i}_${VERSION}_${ARCH}.deb https://${FURY_TOKEN}@push.fury.io/myheliumvalidator/

	((GRPC_PORT++))
	((P2P_PORT++))
	((JSONRPC_PORT++))
done

rm -f /tmp/*.service
rm -f /tmp/*install.sh
