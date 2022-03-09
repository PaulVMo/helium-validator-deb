#!/bin/bash
#
# Script to build the Helium Validator 
# as a debian package

set -e

# BUILD FLAGS
export CFLAGS="-O3 -march=x86-64-v3"
export CXXFLAGS="-O3"
export ERL_COMPILER_OPTIONS="[deterministic]"

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
git tag -a ${VERSION_TAG}+mhv -m "MyHeliumValidator version ${VERSION_TAG}" ${COMMIT}^{}


# Build the validator miner
VERSION="$(echo $VERSION_TAG | sed -e 's,validator,,')"
./rebar3 as validator release -n miner -v ${VERSION}+mhv


# Get the genesis block
wget -O /tmp/genesis https://snapshots.helium.wtf/genesis.mainnet


cd ../

# Update the sys.config.src file with the deb package version
cp deb/deb-val.config.src miner/_build/validator/rel/miner/releases/${VERSION}+mhv/sys.config.src

# Grab OTP version for package description
OTP_VERSION=$(erl -eval '{ok, Version} = file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])), io:fwrite(Version), halt().' -noshell)

fpm -n validator \
    -v "${VERSION}" \
    -s dir \
    -t deb \
    --depends libssl1.1 \
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
    --description "Debian package for Helium Network Validator. Build with OTP ${OTP_VERSION}" \
    miner/_build/validator/rel/=/opt \
    /tmp/genesis=/opt/miner/update/genesis

# Upload to Gemfury
curl -F package=@validator_${VERSION}_amd64.deb https://${FURY_TOKEN}@push.fury.io/myheliumvalidator/
