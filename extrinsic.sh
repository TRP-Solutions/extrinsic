#!/bin/bash

# Extrinsic is licensed under the Apache License 2.0 license
# https://github.com/TRP-Solutions/extrinsic/blob/main/LICENSE

function update {
	if [ $(repo_exists $2) = 200 ]
	then
		if [ -n "$1" ]
		then
			local origin=`pwd`
			local folder="`pwd`/$1"
			local headcommit=$(repo_head $2)
			if [ -f "$folder/.extrinsic-hashcommit" ]
			then
				read local_hashcommit < "$folder/.extrinsic-hashcommit"
				if [ "$local_hashcommit" = "$headcommit" ]
				then
					echo "$1: [NO UPDATE] Already at HEAD"
					return;
				fi
			fi
			if [ -d "$folder" ]
			then
				if svn_modifications "$folder"
				then
					echo "$1: [NO UPDATE] SVN modifications detected"
					return;
				fi
				echo "$1: [UPDATING]"
				rm -rf "$folder"
				mkdir "$folder"
				git clone --quiet --no-checkout $2 "$folder/git"
				cd "$folder/git"
				if [ -n "$3" ]
				then
					git sparse-checkout set --no-cone "$3"
				fi
				git checkout -q
				cd "$folder"
				mv "$folder/git/$3/"* "$folder/"
				rm -rf "$folder/git/"
				echo "$2 $3" > .extrinsic-source
				echo $headcommit > .extrinsic-hashcommit
				cd $origin
			fi
		fi
	fi
}

function svn_modifications {
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
	curl -s -o /dev/null --head -w "%{http_code}" $1
}

function repo_head {
	git ls-remote -q $1 2> /dev/null | grep "HEAD" | (read hash head; echo $hash)
}

for source in */.extrinsic-source
do
	if [ -r "$source" ]
	then
		while read repository subfolder
		do
			update ${source%/.extrinsic-source} $repository $subfolder
		done < "$source"
		# handle last line
		if [ -n "$repository" ]
		then
			update ${source%/.extrinsic-source} $repository $subfolder
		fi
	else
		echo "Error: Can't read " $source
		exit 1
	fi
done
