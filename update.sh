#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

defaultDebianVariant='stretch-slim'
declare -A debianVariants=(
	#[5.5]='jessie'
)

for version in "${versions[@]}"; do
	debianVariant="${debianVariants[$version]:-$defaultDebianVariant}"
	debianSuite="${debianVariant%%-*}" # "stretch", etc

	if [ "$version" = '5.5' ]; then
		fullVersion="$(curl -sSL "https://dev.mysql.com/downloads/mysql/$version.html?os=2" \
			| grep '">(mysql-'"$version"'.*-linux.*-x86_64\.tar\.gz)<' \
			| sed -r 's!.*\(mysql-([^<)]+)-linux.*-x86_64\.tar\.gz\).*!\1!' \
			| sort -V | tail -1)"
	else
		fullVersion="$(
			curl -fsSL "http://repo.mysql.com/apt/debian/dists/$debianSuite/mysql-$version/binary-amd64/Packages.gz" \
				| gunzip \
				| awk -F ': ' '
					$1 == "Package" {
						pkg = $2
						next
					}
					pkg == "mysql-server" && $1 == "Version" {
						print $2
					}
				'
		)"
	fi

	(
		set -x
		sed -ri \
			-e 's/^(ENV MYSQL_VERSION) .*/\1 '"$fullVersion"'/' \
			-e 's/^(ENV MYSQL_MAJOR) .*/\1 '"$version"'/' \
			-e 's/^(FROM) .*/\1 debian:'"$debianVariant"'/' \
			-e 's!(http://repo.mysql.com/apt/debian/) [^ ]+!\1 '"$debianSuite"'!' \
			"$version/Dockerfile"
	)
done
