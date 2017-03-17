# Databox Container Manager

Databox OS container manager and dashboard user interface.

## Installation

All Databox components, including the container manager, run in Docker containers. So first, install and run Docker: https://www.docker.com/products/docker

### Known issues:

In some cases, the time in docker containers on mac can get out of sync with the system clock. This causes the HTTPS certs generated by the CM from being valid. See https://github.com/docker/for-mac/issues/17.
Fix: restart docker for mac.

## Running

Once docker is installed, just run the flowing to get your databox up and running.

	./startDatabox.sh

Once Its started point a web browser at 127.0.0.1:8989 and have fun. This is databoxes normal mode of operation an will use an external app store and image repository for apps.

## Development

To develop for the Databox platform, it may be necessary to run the platform in dev mode. This will enable a local app store and image repository to be run in containers on your machine. In this mode it is possible to build and replace any part of the platform.@

First get the clone this repository:

	git clone https://github.com/me-box/databox-container-manager.git
	cd databox-container-manager
	npm install

Then launch in dev mode by executing `sudo ./platformDevMode.sh`. A new container will be launched, and additional instructions will be presented.

NB: Mount ./certs and ./slaStore as volumes if you want ssl certs and launched apps to save between restarts.

To test a Databox app, follow app dev documentation to build it, then push the app image to the local registry that is launched automatically in platform dev mode (localhost:5000). The app can then be launched normally through the dashboard.

### ENV VARS

- `DATABOX_DEV=1` enables platform dev mode
- `DATABOX_SDK=1` enable cloud sdk mode
- `PORT=8081` overrides default port (8989)
