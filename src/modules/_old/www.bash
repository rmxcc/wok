#!/bin/bash

repo=$wok_repo/www
index_domain=$repo/.index/domain
index_uid=$repo/.index/uid

test ! -d $repo \
|| test ! -d $index_domain \
|| test ! -d $index_uid \
	&& echo "Invalid repository" \
	&& exit 1

# Parameters
#============

usage() {
	test -n "$1" && echo -e "$1\n"
	echo "Usage: wok www <action>"
	echo
	echo "    add <domain>           Create the domain"
	echo "    rm <domain> [options]  Remove the domain"
	echo "        -f, --force        ... without confirmation"
	echo "    uid <domain>           Get the uid relative to the domain"
	echo "    ls [pattern]           List domains (by pattern if specified)"
	echo
	exit 1
}

# Processing
force=
action=
#domain=
argv=
while [ -n "$1" ]; do
	arg=$1;shift
	case $arg in
		-f|--force) force=1;;
		*)
			if test -z "$action"; then action="$arg"
			#elif test -z "$domain"; then domain="$arg"
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
&& test $action != 'uid' \
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
			&& echo "This domain already exists" \
			&& exit 1
		uid="$(slugify 32 $domain $index_uid - www-)"
		test -z "$uid" && echo "Could not create user slug" && exit 1
		touch $repo/$domain
		ln -s "../../$domain" $index_domain/$domain
		ln -s "../../$domain" $index_uid/$uid
		echo "_domain=$domain" >> $repo/$domain
		echo "_uid=$uid" >> $repo/$domain
		echo -n "Creating directory: $wok_www_path/$domain... "
			mkdir -p $wok_www_path/$domain
			echo "done"
		echo -n "Creating log directory: $wok_www_log_path/$domain... "
			mkdir -p $wok_www_log_path/$domain
			echo "done"
		echo -n "Creating system user: $uid... "
			useradd \
				-g $wok_www_uid_group \
				-s $wok_www_uid_shell \
				-M -d $wok_www_path/$domain \
				$uid
			chown -R $uid:$wok_www_uid_group $wok_www_path/$domain
			echo "done"
		echo -n "Creating default structure... "
			touch $wok_www_path/$domain/.zshrc
			mkdir $wok_www_path/$domain/public
			cat $wok_www_placeholder | sed "s/{site}/$domain/g" > $wok_www_path/$domain/public/index.php
			mkdir $wok_www_path/$domain/.ssh
			chmod -R 700 $wok_www_path/$domain/.ssh
			touch $wok_www_path/$domain/.ssh/authorized_keys
			cat $wok_www_key_path/* >> $wok_www_path/$domain/.ssh/authorized_keys
			chmod 600 $wok_www_path/$domain/.ssh/authorized_keys
			chown -R $uid:$wok_www_uid_group $wok_www_path/$domain
			echo "done"
		;;
	rm)
		test ! -e $index_domain/$domain \
			&& echo "This domain does not exist" \
			&& exit 1
		if test ! $force; then
			confirm "Remove www data?" || exit 0
		fi
		source $repo/$domain
		echo -n "Removing system user: $_uid... "
			silent userdel -f $_uid &>> /dev/null
			echo "done"
		echo -n "Removing log directory: $wok_www_log_path/$domain... "
			rm -rf $wok_www_log_path/$domain
			echo "done"
		echo -n "Removing directory: $wok_www_path/$domain... "
			rm -rf $wok_www_path/$domain
			echo "done"
		rm $index_domain/$_domain
		rm $index_uid/$_uid
		rm $repo/$domain
		;;
	uid)
		test ! -e $index_domain/$domain \
			&& echo "This domain does not exist" \
			&& exit 1
		source $repo/$domain
		echo $_uid
		;;
esac