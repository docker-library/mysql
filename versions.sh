#!/usr/bin/env bash
set -Eeuo pipefail

defaultDebianSuite='bullseye'
declare -A debianSuites=(
	[5.7]='buster'
)

defaultOracleVariant='8-slim'
declare -A oracleVariants=(
	[5.7]='7-slim'
)

# https://repo.mysql.com/yum/mysql-8.0-community/docker/
declare -A bashbrewArchToRpmArch=(
	[amd64]='x86_64'
	[arm64v8]='aarch64'
)

fetch_rpm_versions() {
	local repo="$1"; shift
	local arch="$1"; shift
	local oracleVersion="$1"; shift
	local package="$1"; shift

	curl -fsSL "$repo/$arch/" 2>/dev/null \
		| grep -oE '"'"$package"'-[0-9][^"]+[.]el'"$oracleVersion"'[.]'"$arch"'[.]rpm"' \
		| sed -r 's/^"'"$package-|[.]$arch[.]rpm"'"$//g' \
		| sort -rV
}

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

	doc='{}'

	if [[ "$version" == 5.* ]] || [ "$version" = '8.0' ]; then
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
		doc="$(
			jq <<<"$doc" -c '
				. += {
					version: env.baseVersion,
					debian: {
						architectures: [ "amd64" ],
						suite: env.debianSuite,
						version: env.debianVersion,
					},
				}
			'
		)"
	fi

	oracleVariant="${oracleVariants[$version]:-$defaultOracleVariant}"
	oracleVersion="${oracleVariant%%-*}" # "7", etc
	rpmVersion=
	shellVersion=
	doc="$(jq <<<"$doc" -c '. += { oracle: { architectures: [] } }')"
	for bashbrewArch in $(xargs -n1 <<<"${!bashbrewArchToRpmArch[*]}" | sort | xargs); do
		rpmArch="${bashbrewArchToRpmArch[$bashbrewArch]}"
		rpmRepo="https://repo.mysql.com/yum/mysql-$version-community/docker/el/$oracleVersion"
		archVersions="$(
			fetch_rpm_versions "$rpmRepo" "$rpmArch" "$oracleVersion" 'mysql-community-server-minimal' \
				| grep -E "^$version[.]" \
				|| :
		)"
		archVersion="$(head -1 <<<"$archVersions")"
		[ -n "$archVersion" ] || continue
		if [ -z "$rpmVersion" ]; then
			rpmVersion="$archVersion"
		elif [ "$rpmVersion" != "$archVersion" ]; then
			echo >&2 "error: $version architecture version mismatch! ('$rpmVersion' vs '$archVersion' on '$rpmArch'/'$bashbrewArch')"
			exit 1
		fi
		shellArchVersions="$(fetch_rpm_versions "https://repo.mysql.com/yum/mysql-tools-community/el/$oracleVersion" "$rpmArch" "$oracleVersion" 'mysql-shell')"
		shellArchVersion="$(head -1 <<<"$shellArchVersions")"
		if [ -z "$shellVersion" ]; then
			shellVersion="$shellArchVersion"
		elif [ "$shellVersion" != "$shellArchVersion" ]; then
			echo >&2 "error: shell version mismatch! ('$shellVersion' vs '$shellArchVersion' on '$rpmArch'/'$bashbrewArch')"
			exit 1
		fi
		export bashbrewArch
		doc="$(jq <<<"$doc" -c '.oracle.architectures = (.oracle.architectures + [ env.bashbrewArch ] | sort)')"
	done
	baseVersion="$(jq <<<"$doc" -r '.version // ""')"
	# example 8.0.22-1.el7 => 8.0.22
	oracleBaseVersion="${rpmVersion%-*}"
	: "${baseVersion:=$oracleBaseVersion}"
	if [ "$baseVersion" != "$oracleBaseVersion" ]; then
		echo >&2 "error: Oracle and Debian version mismatch! ('$oracleBaseVersion' vs '$baseVersion')"
		exit 1
	fi
	export baseVersion rpmVersion shellVersion oracleVariant
	doc="$(jq <<<"$doc" -c '
		. += {
			version: env.baseVersion,
			oracle: (.oracle + {
				version: env.rpmVersion,
				variant: env.oracleVariant,
			}),
			"mysql-shell": {
				version: env.shellVersion,
			},
		}
	')"

	echo "$version: $baseVersion"

	json="$(jq <<<"$json" -c --argjson doc "$doc" '.[env.version] = $doc')"
done

jq <<<"$json" -S . > versions.json
