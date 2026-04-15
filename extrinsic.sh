#!/bin/bash

# Extrinsic is licensed under the Apache License 2.0 license
# https://github.com/TRP-Solutions/extrinsic/blob/main/LICENSE

function do_update {
	local name="$1"
	local repository="$2"
	local subfolder="$3"
	local branch="$4"
	local folder="$5"

	if [ -n "$branch" ]
	then
		local headcommit=$(repo_branch "$repository" "$branch")
		local headmsg="HEAD of branch $branch"
	else
		local headcommit=$(repo_head "$repository")
		local headmsg="HEAD"
	fi

	if [ $refresh_arg = 0 ]
	then
		if [ -f "$folder/.extrinsic-hashcommit" ]
		then
			read local_hashcommit < "$folder/.extrinsic-hashcommit"
			if [ "$local_hashcommit" = "$headcommit" ]
			then
				echo "$name: [NO UPDATE] Already at $headmsg"
				return;
			fi
		fi
	fi

	if [ -d "$folder" ]
	then
		if svn_modifications "$folder"
		then
			echo "$name: [NO UPDATE] SVN modifications detected"
			return;
		fi
		echo "$name: [UPDATING]"
		rm -rf "$folder"/*

		#mkdir "$folder"
		git clone --quiet --no-checkout "$repository" "$folder/git"
		cd "$folder/git"
		if [ -n "$subfolder" ]
		then
			git sparse-checkout set --no-cone "$subfolder"
		fi
		if [ -n "$branch" ]
		then
			git checkout -q $branch
		else
			git checkout -q
		fi
		cd "$folder"
		mv -f "$folder/git/$subfolder/"* "$folder/"
		rm -rf "$folder/git/"
		if [ -n "$branch" ]
		then
			echo "$repository $subfolder $branch" > .extrinsic-source
		else
			echo "$repository $subfolder" > .extrinsic-source
		fi
		echo $headcommit > .extrinsic-hashcommit
	fi
}

function update {
	local name="$1"
	local repository="$2"
	local subfolder="$3"
	local branch="$4"
	if [ $(repo_exists "$repository") = 200 ]
	then
		if [ -n "$name" ]
		then
			local origin=`pwd`
			if [ "$name" = "." ]
			then
				local folder="$origin"
				cd "$origin/.."
			else
				local folder="$origin/$name"
			fi
			do_update "$name" "$repository" "$subfolder" "$branch" "$folder"
			cd "$origin"
		fi
	fi
}

function svn_modifications {
	if [ $clean_arg = 1 ]
	then
		return 1
	fi
	local is_modified=1 #false
	# svn info $1 return error code in $? if $1 is not an svn repository
	svn info $1 > /dev/null 2>&1
	if [ $? = 1 ]
	then
		# directory is not a SVN repository
		return 1
	fi
	while read status file
	do
		if [ "$file" = "" ] || [ "$file" = "$1" ] || [ "$file" = "$1/.extrinsic-source" ] || [ "$file" = "$1/.extrinsic-hashcommit" ]
		then
			continue
		fi
		is_modified=0
	done <<< `svn status "$1"`
	return $is_modified
}

function repo_exists {
	if [ -n "$1" ]
	then
		curl -s -o /dev/null --head -w "%{http_code}" $1
	else
		echo 400
	fi
}

function repo_head {
	git ls-remote -q $1 2> /dev/null | grep "HEAD" | (read hash head; echo $hash)
}

function repo_branch {
	git ls-remote -q $1 2> /dev/null | grep "refs/heads/$2" | (read hash branch; echo $hash)
}

function update_source {
	local source="$1"
	local name="$2"
	if [ -r "$source" ]
	then
		while read repository subfolder branch
		do
			update "$name" "$repository" "$subfolder" "$branch"
		done < "$source"
	fi
}

function print_usage {
	echo "OPTIONS:
	-c, --clean    Update from repository ignoring and overwriting any SVN changes
	-r, --refresh  Update from repository without checking .extrinsic-hashcommit
	-f, --force    Same as --clean --refresh"
}

# Transform long options to short ones
for arg in "$@"; do
	shift
	case "$arg" in
		'--clean')  set -- "$@" '-c'   ;;
		'--refresh') set -- "$@" '-r'  ;;
		'--force')  set -- "$@" '-f'   ;;
		*)          set -- "$@" "$arg" ;;
	esac
done

# Default behavior
clean_arg=0;
refresh_arg=0;

# Parse short options
OPTIND=1
while getopts ":hcrf" opt
do
  case "$opt" in
    'h') print_usage; exit 0 ;;
    'c') clean_arg=1 ;;
    'r') refresh_arg=1 ;;
    'f') clean_arg=1;refresh_arg=1 ;;
    '?') print_usage >&2; exit 1 ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

arg_count=0;
for arg in "$@"; do
	if [ -d ./"$arg" ]
	then
		arg_count=$arg_count+1;
		source="${arg%/}"/.extrinsic-source
		update_source "$source" "${source%/.extrinsic-source}"
	fi
done

if [ $arg_count = 0 ]
then
	# read and execute
	update_source .extrinsic-source .

	for source in */.extrinsic-source
	do
		update_source "$source" "${source%/.extrinsic-source}"
	done
fi
