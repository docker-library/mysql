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

# Templating
declare -A passwordset
passwordset["5.5"]="DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost') ;\nSET PASSWORD FOR 'root'@'localhost'=PASSWORD('\${MYSQL_ROOT_PASSWORD}');"
passwordset["5.6"]="DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost') ;\nSET PASSWORD FOR 'root'@'localhost'=PASSWORD('\${MYSQL_ROOT_PASSWORD}');"
passwordset["5.7"]="ALTER USER 'root'@'localhost' IDENTIFIED BY '\${MYSQL_ROOT_PASSWORD}';"
passwordset["8.0"]="ALTER USER 'root'@'localhost' IDENTIFIED BY '\${MYSQL_ROOT_PASSWORD}';"
declare -A database_init
database_init["5.5"]='mysql_install_db --datadir="$DATADIR" --rpm --basedir=/usr/local/mysql "${@:2}"'
database_init["5.6"]='mysql_install_db --datadir="$DATADIR" --rpm --keep-my-cnf "${@:2}"'
database_init["5.7"]='"$@" --initialize-insecure'
database_init["8.0"]='"$@" --initialize-insecure'
declare -A server_startup
server_startup["5.5"]='"$@" --skip-networking --basedir=/usr/local/mysql --socket="${SOCKET}" \&'
server_startup["5.6"]='"$@" --skip-networking --socket="${SOCKET}" \&'
server_startup["5.7"]='"$@" --daemonize --skip-networking --socket="${SOCKET}" || result="$?"'
server_startup["8.0"]='"$@" --daemonize --skip-networking --socket="${SOCKET}" || result="$?"'

for version in "${versions[@]}"; do
	sed -e 's!%%PASSWORDSET%%!'"${passwordset["$version"]}"'!g' \
		-e 's!%%DATABASEINIT%%!'"${database_init["$version"]}"'!g' \
		-e 's!%%SERVERSTARTUP%%!'"${server_startup["$version"]}"'!g' \
		.template.Debian/docker-entrypoint.sh > "$version/docker-entrypoint.sh"

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
