#!/bin/bash

repo=$wok_repo/ftp
index_domain=$repo/.index/domain
index_user=$repo/.index/user

test ! -d $repo \
|| test ! -d $index_domain \
|| test ! -d $index_user \
	&& echo "Invalid repository" \
	&& exit 1

# Parameters
#============

usage() {
	test -n "$1" && echo -e "$1\n"
	echo "Usage: wok ftp <action>"
	echo
	echo "    add [options] <domain>  Create the domain"
	echo "        -p, --password <password>"
	echo "    rm <domain>             Remove the domain"
	echo "    ls [pattern]            List domains (by pattern if specified)"
	echo
	exit 1
}

error() {
	echo $1
	exit 1
}

# Processing
action=
password=
argv=
while [ -n "$1" ]; do
	arg="$1";shift
	case "$arg" in
		-p|--password) password="$1";shift;;
		*)
			if test -z "$action"; then action="$arg"
			else argv="$argv $arg"
			fi
			;;
	esac
done
set -- $argv # Restitute the rest...

# Validation
test -z "$action" && usage
test $action != 'add' \
&& test $action != 'rm' \
&& test $action != 'ls' \
	&& usage "Invalid action."

# Add, rm, user validation
if [ $action != 'ls' ]; then
	domain="$1";shift
	test -z "$domain" && usage "Give a domain (e.g. example.org)."
	test ! $(preg_match ':^[a-z0-9\-.]{1,255}$:' $domain) \
		&& echo "Invalid domain name" \
		&& exit 1
fi

if [ $action = 'ls' ]; then
	pattern="$1";shift
	test -z "$pattern" && pattern='*'
fi

# Run
#=====

case $action in
	ls)
		silent cd $repo
		find . -maxdepth 1 -type f -name "$pattern" \
			| sed -r 's/^.{2}//' \
			| sort
		silent cd -
		;;
	add)
		test -e $index_domain/$domain \
			&& error "This domain is already registeted"
		test -z "$($wok_path/wok-www ls $domain)" \
			&& error "This domain does not exist"
		uid="$($wok_path/wok-www uid $domain)"
		test -z "$password" && getpasswd password
		test "$(preg_match ':\\W:' "$password")" && error "Invalid password."
		user="$(slugify 32 $domain $index_user _ www_)"
		echo -n "Registering FTP access for $domain... "
			cmd="
				insert into $wok_ftp_table (name, password, uid, gid, home)
				values ('$user', md5('$password'), '$uid', '$wok_www_uid_group', '$wok_www_path/$domain/public');
			"
			echo "$cmd" | $(cd /tmp; silent sudo -u postgres psql "$wok_ftp_db")
			echo "done"
		touch $repo/$domain
		ln -s "../../$domain" $index_domain/$domain
		ln -s "../../$domain" $index_user/$user
		echo "_domain=$domain" >> $repo/$domain
		echo "_user=$user" >> $repo/$domain
		;;
	rm)
		test ! -e $index_domain/$domain && exit 1
		source $repo/$domain
		echo -n "Unregistering FTP access... "
			cmd="
				delete from $wok_ftp_table
				where name = '$_user';
			"
			echo "$cmd" | $(cd /tmp; silent sudo -u postgres psql "$wok_ftp_db")
			echo "done"
		rm $index_domain/$_domain
		rm $index_user/$_user
		rm $repo/$domain
		;;
esac