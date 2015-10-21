#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
	if [ "$version" = '5.5' ]; then
		fullVersion="$(curl -sSL "https://dev.mysql.com/downloads/mysql/$version.html?os=2" \
			| grep '">(mysql-'"$version"'.*-linux.*-x86_64\.tar\.gz)<' \
			| sed -r 's!.*\(mysql-([^<)]+)-linux.*-x86_64\.tar\.gz\).*!\1!' \
			| sort -V | tail -1)"
	else
		fullVersion="$(curl -fsSL "http://repo.mysql.com/apt/debian/dists/jessie/mysql-$version/binary-amd64/Packages.gz" | gunzip | awk -F ': ' '$1 == "Package" { pkg = $2; next } pkg == "mysql-server" && $1 == "Version" { print $2 }')"
	fi
	
	(
		set -x
		sed -ri '
			s/^(ENV MYSQL_MAJOR) .*/\1 '"$version"'/;
			s/^(ENV MYSQL_VERSION) .*/\1 '"$fullVersion"'/
		' "$version/Dockerfile"
	)
done
