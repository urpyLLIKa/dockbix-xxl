#!/bin/bash
set -e

SOURCE_BRANCH="master"
TARGET_BRANCH="master"

function doCompile {
  docker rmi urpyllika/dockbix-xxl:latest || true
  ZVERSION=$(docker run --rm -ti urpyllika/dockbix-xxl:latest zabbix_agentd -V | grep ^zabbix_agentd | awk -F'\\(Zabbix\\) ' '{print $2}' | sed -e 's/[[:blank:],[:cntrl:]]$//g;/^$/d')
  echo $ZVERSION
  sed -i "s#.*\"version\":.*#\"version\": \"$ZVERSION\",#" latest
  sed -i "s#Docker image version.*is available#Docker image version $ZVERSION  is available#" latest
}

# Pull requests and commits to other branches shouldn't try to deploy
if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    echo "Skipping deploy."
    exit 0
fi

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`

# Clone the existing master for this repo into out/
git clone $REPO out
cd out
git checkout $TARGET_BRANCH || git checkout --orphan $TARGET_BRANCH

# Run our compile script
doCompile

# Now let's go have some fun with the cloned repo
git config user.name "Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"

# If there are no changes to the compiled out (e.g. this is a README update) then just bail.
if [ -z `git diff --exit-code` ]; then
    echo "No changes to the output on this push; exiting."
    exit 0
fi

# Commit the "changes", i.e. the new version.
# The delta will show diffs between new and old versions.
git add latest
DATE=`date +"%Y-%m-%d %H:%M:%S"`
git commit -m "Latest version update $DATE"

# Get the deploy key by using Travis's stored variables to decrypt deploy_key.enc
ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in ../artifacts/deploy_key.enc -out deploy_key -d
chmod 600 deploy_key
eval `ssh-agent -s`
ssh-add deploy_key

# Now that we're all set up, we can push.
git push $SSH_REPO $TARGET_BRANCH
