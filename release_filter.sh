#!/bin/bash
#
# Copyright 2021 The Triple Banana Authors. All rights reserved.
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Exit when any command fails
set -ex

# Checkout bromite
git clone https://github.com/bromite/filters.git bromite

# Check version
UPSTREAM_BASE=$(sha256sum bromite/filters.dat | awk '{print $1}')
if [[ -f BASE && $(cat BASE) = $UPSTREAM_BASE ]]; then
    echo "Already up to date"
    exit 0
fi

# Create a filter
NEXT_VERSION=$(cat metadata.json | jq -r '.version'| awk -F. -v OFS=. 'NF==1{print ++$NF}; NF>1{if(length($NF+1)>length($NF))$(NF-1)++; $NF=sprintf("%0*d", length($NF), ($NF+1)%(10^length($NF))); print}')
cp bromite/filters.dat $NEXT_VERSION.filter
vim -c "set binary" -c "%s/wcslog.js/wcslog.ts/g" -c "wq" $NEXT_VERSION.filter
zip -9 $NEXT_VERSION.filter.zip $NEXT_VERSION.filter

# Update metadata
jq --arg version $NEXT_VERSION --indent 4 '.version = $version' metadata.json > metadata.json.tmp
mv metadata.json.tmp metadata.json
FILTER_SIZE=$(ls -l $NEXT_VERSION.filter | awk '{print $5}')
jq --argjson size $FILTER_SIZE --indent 4 '.size= $size' metadata.json > metadata.json.tmp
mv metadata.json.tmp metadata.json

# Update BASE
echo $UPSTREAM_BASE > BASE

# Create PR
git config --global user.name "GitHub Actions"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git add BASE
git add $NEXT_VERSION.filter
git add $NEXT_VERSION.filter.zip
git add metadata.json
git checkout -B release
git commit -m "Release $NEXT_VERSION"
git push -f https://$GITHUB_TOKEN@github.com/triplebanana/filter.git
curl \
    -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/triplebanana/filter/pulls \
    -d '{"title":"Release '${NEXT_VERSION}'", "head":"release","base":"gh-pages"}'
