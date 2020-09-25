#!/usr/bin/env bash

set -euo pipefail

PAYLOAD=$(yj -tj < buildpack.toml | jq '{ primary: . }')

for PACKAGE in $(yj -t < package.toml | jq -r '.dependencies[].image'); do
  PAYLOAD=$(jq -n -r \
    --argjson PAYLOAD "${PAYLOAD}" \
    --argjson BUILDPACK "$(crane export "${PACKAGE}" - \
      | tar xOf - --absolute-names --wildcards "/cnb/buildpacks/*/*/buildpack.toml" \
      | yj -tj)" \
    '$PAYLOAD | .buildpacks += [ $BUILDPACK ]')
done

jq -n -r \
  --argjson PAYLOAD "${PAYLOAD}" \
  --arg RELEASE_NAME "${RELEASE_NAME}" \
  '"\($PAYLOAD.primary.buildpack.name) \($RELEASE_NAME)"' \
  > "${HOME}"/name

jq -n -r \
  --argjson PAYLOAD "${PAYLOAD}" \
  --arg RELEASE_BODY "${RELEASE_BODY}" \
  '
def id(b):
  "**ID**: `\(b.buildpack.id)`"
;

def included_buildpackages(b): [
  "#### Included Buildpackages:",
  "Name | ID | Version",
  ":--- | :- | :------",
  ( b | sort_by(.buildpack.name | ascii_downcase) | map("\(.buildpack.name) | `\(.buildpack.id)` | `\(.buildpack.version)`") ),
  ""
];

def stacks(s): [
  "#### Supported Stacks:",
  ( s | sort_by(.id | ascii_downcase) | map("- `\(.id)`") ),
  ""
];

def default_dependency_versions(d): [
  "#### Default Dependency Versions:",
  "ID | Version",
  ":- | :------",
  ( d | to_entries | sort_by(.key | ascii_downcase) | map("`\(.key)` | `\(.value)`") ),
  ""
];

def dependencies(d): [
  "#### Dependencies:",
  "Name | Version | SHA256",
  ":--- | :------ | :-----",
  ( d | sort_by(.name | ascii_downcase) | map("\(.name) | `\(.version)` | `\(.sha256)`")),
  ""
];

def order_groupings(o): [
  "<details>",
  "<summary>Order Groupings</summary>",
  "",
  ( o | map([
    "ID | Version | Optional",
    ":- | :------ | :-------",
    ( .group | map([ "`\(.id)` | `\(.version)`", ( select(.optional) | "| `\(.optional)`" ) ] | join(" ")) ),
    ""
  ])),
  "</details>",
  ""
];

def primary_buildpack(p): [
  id(p.primary),
  "**Digest**: <!-- DIGEST PLACEHOLDER -->",
  "",
  ( select(p.buildpacks) | included_buildpackages(p.buildpacks) ),
  ( select(p.primary.stacks) | stacks(p.primary.stacks) ),
  ( select(p.primary.metadata."default-versions") | default_dependency_versions(p.primary.metadata."default-versions") ),
  ( select(p.primary.metadata.dependencies) | dependencies(p.primary.metadata.dependencies) ),
  ( select(p.primary.order) | order_groupings(p.primary.order) ),
  ( select(p.buildpacks) | "---" ),
  ""
];

def nested_buildpack(b): [
  "<details>",
  "<summary>\(b.buildpack.name) \(b.buildpack.version)</summary>",
  "",
  id(b),
  "",
  ( select(b.stacks) | stacks(b.stacks) ),
  ( select(b.metadata."default-versions") | default_dependency_versions(b.metadata."default-versions") ),
  ( select(b.metadata.dependencies) | dependencies(b.metadata.dependencies) ),
  ( select(b.order) | order_groupings(b.order) ),
  "---",
  "",
  "</details>",
  ""
];

$PAYLOAD | [
  primary_buildpack(.),
  ( select(.buildpacks) | [ .buildpacks | sort_by(.buildpack.name | ascii_downcase) | map(nested_buildpack(.)) ] ),
  "",
  "---",
  "",
  $RELEASE_BODY
] | flatten | join("\n")
' > "${HOME}"/body

gh api \
  --method PATCH \
  "/repos/:owner/:repo/releases/${RELEASE_ID}" \
  --field "tag_name=${RELEASE_TAG_NAME}" \
  --field "name=@${HOME}/name" \
  --field "body=@${HOME}/body"
