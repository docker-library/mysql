#!/usr/bin/env bash
set -Eeuo pipefail

declare -A aliases=(
	[8.4]='8 lts'
)

defaultDefaultVariant='oracle'
declare -A defaultVariants=(
	#[8.0]='debian'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

# add the "latest" alias to the "newest" version (LTS vs innovation; see sorting in "versions.sh")
latest="$(jq -r 'keys_unsorted[0]' versions.json)"
aliases["$latest"]+=' latest'
# if "innovation" currently is in line with an LTS, add the "innovation" alias to the LTS release
innovation="$(jq -r 'to_entries | if .[0].value.version == .[1].value.version and .[1].key == "innovation" then .[0].key else "innovation" end' versions.json)"
if [ "$innovation" != 'innovation' ]; then
	aliases["$innovation"]+=' innovation'
fi

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

# sort version numbers with highest first
IFS=$'\n'; set -- $(sort -rV <<<"$*"); unset IFS

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "dir/dockerfile" or any file COPY'd from it
dirCommit() {
	local dir="$1"; shift
	local df="$1"; shift
	(
		cd "$dir"
		local files; files="$(
			git show "HEAD:./$df" | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						print $i
					}
				}
			'
		)"
		fileCommit "$df" $files
	)
}

cat <<-EOH
# this file is generated via https://github.com/docker-library/mysql/blob/$(fileCommit "$self")/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon),
             Joseph Ferguson <yosifkit@gmail.com> (@yosifkit)
GitRepo: https://github.com/docker-library/mysql.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version; do
	export version

	if ! fullVersion="$(jq -re '
		if env.version == "innovation" and keys_unsorted[0] != env.version then
			# https://github.com/docker-library/mysql/pull/1046#issuecomment-2087323746
			# if any explicit/LTS release is *newer* than the current innovation release, we should skip innovation
			# (because we pre-sorted the full list in "versions.sh", we just need to check whether "innovation" is first 🚀)
			false
		else
			.[env.version].version
		end
	' versions.json)"; then
		continue
	fi

	versionAliases=()
	while [ "$fullVersion" != "$version" -a "${fullVersion%[.-]*}" != "$fullVersion" ]; do
		versionAliases+=( $fullVersion )
		fullVersion="${fullVersion%[.-]*}"
	done
	versionAliases+=( $fullVersion )
	if [ "$version" != "$fullVersion" ]; then
		versionAliases+=( $version )
	fi
	versionAliases+=( ${aliases[$version]:-} )

	defaultVariant="${defaultVariants[$version]:-$defaultDefaultVariant}"
	for variant in oracle debian; do
		export variant

		df="Dockerfile.$variant"
		[ -s "$version/$df" ] || continue
		commit="$(dirCommit "$version" "$df")"

		variantAliases=( "${versionAliases[@]/%/-$variant}" )
		variantAliases=( "${variantAliases[@]//latest-/}" )

		case "$variant" in
			debian)
				suite="$(jq -r '.[env.version][env.variant].suite' versions.json)"
				variantAliases=( "${versionAliases[@]/%/-$suite}" "${variantAliases[@]}" )
				variantAliases=( "${variantAliases[@]//latest-/}" )
				;;

			oracle)
				ol="$(jq -r '.[env.version][env.variant].variant | split("-")[0]' versions.json)"
				variantAliases=( "${versionAliases[@]/%/-oraclelinux$ol}" "${variantAliases[@]}" )
				variantAliases=( "${variantAliases[@]//latest-/}" )
				;;
		esac

		if [ "$variant" = "$defaultVariant" ]; then
			variantAliases=( "${versionAliases[@]}" "${variantAliases[@]}" )
		fi

		# TODO if the list of architectures supported by MySQL ever is greater than that of the base image it's FROM, this list will need to be filtered
		variantArches="$(jq -r '.[env.version][env.variant].architectures | join(", ")' versions.json)"

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: $variantArches
			GitCommit: $commit
			Directory: $version
			File: $df
		EOE
	done
done
