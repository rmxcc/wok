#!/bin/bash

repo=$wok_repo/mail
index_domain=$repo/.index/domain
index_account=$repo/.index/account
index_alias=$repo/.index/alias

test ! -d $repo \
|| test ! -d $index_domain \
|| test ! -d $index_account \
|| test ! -d $index_alias \
	&& echo "Invalid repository" \
	&& exit 1

# Parameters
#============

usage() {
	test -n "$1" && echo -e "$1\n"
	echo "Usage: wok mail <action>"
	echo
	echo "    add [options] <domain>     Create the domain"
	echo "    rm [options] <domain>      Remove the domain"
	echo "        -f, --force            ... wihout confirmation"
	echo "    ls [pattern]               List domains (by pattern if specified)"
	echo "    account <domain> [command]"
	echo "        add <src> <dest@host>  Create an account for the domain"
	echo "        rm <src>               Remove an account of the domain"
	echo "        ls                     List accounts of the domain"
	echo "    alias <domain> [command]   Manage aliases for the domain"
	echo "        add <src> <dest@host>  Create an alias for the domain"
	echo "        rm <src>               Remove an alias of the domain"
	echo "        ls                     List aliases of the domain"
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
force=
argv=
while [ -n "$1" ]; do
	arg="$1";shift
	case "$arg" in
		-p|--password) password="$1";shift;;
		-f|--force) force=1;;
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
&& test $action != 'account' \
&& test $action != 'alias' \
	&& usage "Invalid action."

# Add, rm, user validation
if [ "$action" = 'add' ] || [ "$action" = 'rm' ]; then
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
			&& error "This domain is already registered"
		test -z "$($wok_path/wok-www ls $domain)" \
			&& error "This domain does not exist"
		#uid="$($wok_path/wok-www uid $domain)"
		#test -z "$password" && getpasswd password
		#test "$(preg_match ':\\W:' "$password")" && error "Invalid password."
		#user="$(slugify 63 $domain $index_user _ www_)"
		#db="$(slugify 63 $domain $index_db _ www_)"
		echo -n "Registering mail domain $domain... "
			cmd="
				insert into public.virtual_domain (name) values ('$domain');
			"
			echo "$cmd" | $(cd /tmp; silent sudo -u postgres psql $wok_mail_db)
			echo "done"
		touch $repo/$domain
		ln -s "../../$domain" $index_domain/$domain
		echo "_domain=$domain" >> $repo/$domain
		mkdir $index_account/$domain
		mkdir $index_alias/$domain
		;;
	rm)
		test ! -e $index_domain/$domain && exit 1
		if test ! $force; then
			confirm "Remove mail domain?" || exit 0
		fi
		source $repo/$domain
		echo -n "Unregistering domain $domain... "
			cmd="
				delete from public.virtual_domain where name = '$_domain';
			"
			echo "$cmd" | $(cd /tmp; silent sudo -u postgres psql $wok_mail_db)
			echo "done"
		rm $index_domain/$_domain
		rm -rf $index_account/$_domain
		rm -rf $index_alias/$_domain
		rm $repo/$domain
		;;
	account)
		$wok_path/wok-mail-account $*
		;;
	alias)
		$wok_path/wok-mail-alias $*
		;;
esac