#!/bin/bash
set -e

echo " ---> PREINSTALL"

display_error() {
	echo " !--> ERROR on preinstall:"
	tail -n 200 /tmp/dockerize.log
	exit 1
}

echo " ---> Setting up common dependencies. This will take a while..."
apt-get update -qq

(
	# install node + npm
	curl -s https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz | \
		tar xzf - -C /usr/local --strip-components=1

	apt-get install -y \
		apt-transport-https \
		postgresql-client \
		pandoc \
		poppler-utils \
		unrtf \
		tesseract-ocr \
		catdoc \
		postgresql

	# Set up pg defaults
	echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.6/main/pg_hba.conf
	echo "listen_addresses='*'" >> /etc/postgresql/9.6/main/postgresql.conf
	echo "data_directory='$PGDATA'" >> /etc/postgresql/9.6/main/postgresql.conf
	rm -rf "$PGDATA_LEGACY" && rm -rf "$PGDATA" && mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA"

	# Specifics for BIM edition
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
	wget -q https://packages.microsoft.com/config/debian/9/prod.list -O /etc/apt/sources.list.d/microsoft-prod.list
	apt-get update -qq
	apt-get install -y dotnet-runtime-3.1

	tmpdir=$(mktemp -d)
	cd $tmpdir

	# Install XKT converter
	npm install xeokit/xeokit-gltf-to-xkt -g

	# Install COLLADA2GLTF
	wget --quiet https://github.com/KhronosGroup/COLLADA2GLTF/releases/download/v2.1.5/COLLADA2GLTF-v2.1.5-linux.zip
	unzip -q COLLADA2GLTF-v2.1.5-linux.zip
	mv COLLADA2GLTF-bin "/usr/local/bin/COLLADA2GLTF"

	# IFCconvert
	wget --quiet https://s3.amazonaws.com/ifcopenshell-builds/IfcConvert-v0.6.0-9bcd932-linux64.zip
	unzip -q IfcConvert-v0.6.0-9bcd932-linux64.zip
	mv IfcConvert "/usr/local/bin/IfcConvert"

	wget --quiet https://github.com/bimspot/xeokit-metadata/releases/download/1.0.0/xeokit-metadata-linux-x64.tar.gz
	tar -zxvf xeokit-metadata-linux-x64.tar.gz
	chmod +x xeokit-metadata-linux-x64/xeokit-metadata
	cp -r xeokit-metadata-linux-x64/ "/usr/lib/xeokit-metadata"
	ln -s /usr/lib/xeokit-metadata/xeokit-metadata /usr/local/bin/xeokit-metadata

	cd /
	rm -rf $tmpdir

	gem install bundler --version "$BUNDLER_VERSION" --no-document

	useradd -d /home/$APP_USER -m $APP_USER

) >/tmp/dockerize.log || display_error

if test -f ./docker/setup/preinstall-$PLATFORM.sh ; then
	echo " ---> Executing preinstall for $PLATFORM..."
	./docker/setup/preinstall-$PLATFORM.sh >/tmp/dockerize.log || display_error
fi

apt-get clean
rm -rf /var/lib/apt/lists/*

rm -f /tmp/dockerize.log
echo "      OK."
