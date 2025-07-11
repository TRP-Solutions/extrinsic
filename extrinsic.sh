#!/bin/bash

# Extrinsic is licensed under the Apache License 2.0 license
# https://github.com/TRP-Solutions/extrinsic/blob/main/LICENSE

function update {
	if [ $(repo_exists $2) = 200 ]
	then
		if [ -n "$1" ]
		then
			local origin=`pwd`
			if [ "$1" = "." ]
			then
				local folder="$origin"
				cd "$origin/.."
			else
				local folder="$origin/$1"
			fi
			if [ -n "$4" ]
			then
				local headcommit=$(repo_branch $2 $4)
				if [ -f "$folder/.extrinsic-hashcommit" ]
				then
					read local_hashcommit < "$folder/.extrinsic-hashcommit"
					if [ "$local_hashcommit" = "$headcommit" ]
					then
						echo "$1: [NO UPDATE] Already at HEAD of branch $4"
						return;
					fi
				fi
			else
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
			fi
			if [ -d "$folder" ]
			then
				if svn_modifications "$folder"
				then
					echo "$1: [NO UPDATE] SVN modifications detected"
					return;
				fi
				echo "$1: [UPDATING]"
				rm -rf "$folder/*"
				#mkdir "$folder"
				git clone --quiet --no-checkout $2 "$folder/git"
				cd "$folder/git"
				if [ -n "$3" ]
				then
					git sparse-checkout set --no-cone "$3"
				fi
				if [ -n "$4" ]
				then
					git checkout -q $4
				else
					git checkout -q
				fi
				cd "$folder"
				mv "$folder/git/$3/"* "$folder/"
				rm -rf "$folder/git/"
				if [ -n "$4" ]
				then
					echo "$2 $3 $4" > .extrinsic-source
				else
					echo "$2 $3" > .extrinsic-source
				fi
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

function repo_branch {
	git ls-remote -q $1 2> /dev/null | grep "refs/heads/$2" | (read hash branch; echo $hash)
}

if [ -r .extrinsic-source ]
then
	while read repository subfolder
	do
		update . $repository $subfolder
	done < .extrinsic-source
	# handle last line
	if [ -n "$repository" ]
	then
		update . $repository $subfolder
	fi
	cd .
else
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
fi
