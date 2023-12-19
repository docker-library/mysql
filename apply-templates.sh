#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s extglob # support globs like !(foo)

[ -f versions.json ] # run "versions.sh" first

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

jqt='.jq-template.awk'
if [ -n "${BASHBREW_SCRIPTS:-}" ]; then
	jqt="$BASHBREW_SCRIPTS/jq-template.awk"
elif [ "$BASH_SOURCE" -nt "$jqt" ]; then
	# https://github.com/docker-library/bashbrew/blob/master/scripts/jq-template.awk
	wget -qO "$jqt" 'https://github.com/docker-library/bashbrew/raw/9f6a35772ac863a0241f147c820354e4008edf38/scripts/jq-template.awk'
fi

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

generated_warning() {
	cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#

	EOH
}

for version; do
	export version

	rm -f "$version"/!(config)
	mkdir -p "$version"

	for variant in oracle debian; do
		export variant

		echo "processing $version ($variant) ..."

		variantVersion="$(jq -r '.[env.version][env.variant] // {} | .version // ""' versions.json)"
		if [ -n "$variantVersion" ]; then
			dockerfile="Dockerfile.$variant"
			{
				generated_warning
				gawk -f "$jqt" "$dockerfile"
			} > "$version/$dockerfile"
		fi
	done

	cp -a docker-entrypoint.sh "$version/docker-entrypoint.sh"
done
