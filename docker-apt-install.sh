#!/bin/bash
#
# helper to correctly do an 'apt-get install' inside a Dockerfile's RUN
#
# the upstream mirror seems to fail a lot so lets build some retries in
#
# todo: this is copypasta with bwstitt/library-debian/src/
#

set -e

function apt-install {
    apt-get install --no-install-recommends -y "$@"
}

function retry {
    # http://unix.stackexchange.com/questions/82598/how-do-i-write-a-retry-logic-in-script-to-keep-retrying-to-run-it-upto-5-times
    local n=1
    local max=5
    local delay=5
    while true; do
        echo "Attempt ${n}/${max}: $@"
        "$@"
        local exit_code=$?

        if [ "$exit_code" -eq 0 ]; then
            echo "Attempt ${n}/${max} was successful"
            break
        elif [[ $n -lt $max ]]; then
            echo "Attempt ${n}/${max} exited non-zero ($exit_code)"
            ((n++))
            echo "Sleeping $delay seconds..."
            sleep $delay;
        else
            echo "Attempt ${n}/${max} exited non-zero ($exit_code). Giving up"
            return $exit_code
        fi
    done
}

export DEBIAN_FRONTEND=noninteractive

# stop apt from starting processes on install
export RUNLEVEL=1

if [ -n "$HTTP_PROXY" ]; then
    echo "Configuring apt to use HTTP_PROXY..."
    echo "Acquire::http::proxy \"$HTTP_PROXY\";" >/etc/apt/apt.conf.d/proxy
fi

echo
echo "apt-get update:"
apt-get update

echo
echo "Downloading packages..."
retry apt-install --download-only "$@" || true

echo
echo "Installing packages..."
apt-install "$@"

echo
echo "Cleaning up..."
rm -rf /var/lib/apt/lists/*

if [ -e "/etc/apt/apt.conf.d/proxy" ]; then
    rm /etc/apt/apt.conf.d/proxy
fi

# docker's official debian and ubuntu images do apt-get clean for us
