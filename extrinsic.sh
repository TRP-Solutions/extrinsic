#!/bin/bash
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
				if [ "$local_hashcommit"="$headcommit" ]
				then
					echo "Not updating $1; already at HEAD"
					return;
				fi
			fi
			if [ -d "$folder" ]
			then
				echo "Updating $1"
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

function repo_exists {
	curl -s -o /dev/null --head -w "%{http_code}" $1
}

function repo_head {
	git ls-remote -q $1 2> /dev/null | grep "HEAD" | sed -E "s/([0-9a-f]+)\WHEAD/\1/"
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
