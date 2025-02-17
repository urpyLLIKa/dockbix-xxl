#!/bin/bash
# use on master branch and retag also older tags

# delete all current tags
git fetch --tags --force
tags=()
for t in `git tag`
do
    if [[ "$t" != 4.2* ]]; then
         continue
    fi
    echo "Deleting tag $t"
    git tag -d $t
    git push origin :refs/tags/$t
    tags=("${tags[@]}" "$t")
done
git push origin master
git push origin --tags

# create tags from the list
tags=('4.2.0' '4.2.1' '4.2.2' '4.2.3' '4.2.4' '4.2.5' '4.2.6');
for t in "${tags[@]}"
do
    echo "Creating tag $t"
    git checkout master
    sed -i -e "s#^[[:space:]]*ZABBIX_VERSION=.*#  ZABBIX_VERSION=tags/$t \\\#" Dockerfile
    sleep 5    
    git add Dockerfile
    sleep 5
    git commit -m "Tag $t"
    sleep 5
    git tag -a $t -m "Tag $t"
    sleep 5
    last=$t        
done
git push origin master
git push origin --tags

# master is the latest stable tag
git checkout master
sed -i -e "s#^[[:space:]]*ZABBIX_VERSION=.*#  ZABBIX_VERSION=tags/4.2.6 \\\#" Dockerfile
sleep 5
git add Dockerfile
sleep 5
git commit -m "Master = the latest stable tag"
git push origin master
