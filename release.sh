#!/usr/bin/env bash
set -e

while getopts v: flag
do
    case "${flag}" in
        v) version=${OPTARG};;
    esac
done

echo $version

./build.sh -c ./config/prod.json

rm -rf ./package
mkdir -p package

echo "{
  \"name\": \"@maplelabs/maple-token\",
  \"version\": \"${version}\",
  \"description\": \"Maple Token Artifacts and ABIs\",
  \"author\": \"Maple Labs\",
  \"license\": \"AGPLv3\",
  \"repository\": {
    \"type\": \"git\",
    \"url\": \"https://github.com/maple-labs/maple-token.git\"
  },
  \"bugs\": {
    \"url\": \"https://github.com/maple-labs/maple-token/issues\"
  },
  \"homepage\": \"https://github.com/maple-labs/maple-token\"
}" > package/package.json

mkdir -p package/artifacts
mkdir -p package/abis

cat ./out/dapp.sol.json | jq '.contracts | ."contracts/MapleToken.sol" | .MapleToken' > package/artifacts/MapleToken.json
cat ./out/dapp.sol.json | jq '.contracts | ."contracts/MapleToken.sol" | .MapleToken | .abi' > package/abis/MapleToken.json

npm publish ./package --access public

rm -rf ./package
