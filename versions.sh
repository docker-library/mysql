#!/usr/bin/env bash
set -Eeuo pipefail

defaultDebianSuite='buster'
declare -A debianSuites=(
	[5.6]='stretch'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( *.*/ )
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
	export version

	debianSuite="${debianSuites[$version]:-$defaultDebianSuite}"
	debianVersion="$(
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

	# example 8.0.22-1debian10 => 8.0.22
	baseVersion="${debianVersion%-*}"

	export baseVersion debianSuite debianVersion
	json="$(
		jq <<<"$json" -c \
			'.[env.version] = {
				version: env.baseVersion,
				debian: {
					architectures: [ "amd64" ],
					suite: env.debianSuite,
					version: env.debianVersion,
				},
			}'
	)"
done

jq <<<"$json" -S . > versions.json
