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

# Copy entrypoint template
templateVersions=( "5.7 8.0" )
for version in ${templateVersions}; do
	cp "template.Debian/docker-entrypoint.sh" "${version}/"
done

for version in "${versions[@]}"; do
	if [ "${version}" = "template.Debian" ]; then continue; fi # If update.sh is run without arguments, the template directory is included in the list
	debianVariant="${debianVariants[$version]:-$defaultDebianVariant}"
	debianSuite="${debianVariant%%-*}" # "stretch", etc

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
