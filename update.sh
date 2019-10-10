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

	cp -a .template.Debian/docker-entrypoint.sh "$version/docker-entrypoint.sh"

	fullVersion="$(
		curl -fsSL "https://repo.mysql.com/apt/debian/dists/$debianSuite/mysql-$version/binary-amd64/Packages.gz" \
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
