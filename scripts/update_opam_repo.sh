#! /bin/sh

# Update the repository of opam packages used by tezos.  Tezos uses a
# private, shrunk down, opam repository to store all its
# dependencies. This is generated by the official opam repository
# (branch master) and then filtered using opam admin to include only
# the cone of tezos dependencies.  This repository is then used to
# create the based opam image used by the CI to compile tezos and to
# generate the docker images.  From time to time, when it is necessary
# to update a dependency, this repository should be manually
# refreshed. This script takes care of generating a patch for the
# private opam tezos repository. This patch must be applied manually
# w.r.t. the master branch. The procedure is as follows :
#
# 1. Update the variable `full_opam_repository_tag` in `version.sh` to
#    a commit hash from the master branch of the official
#    opam-repository. All the required packages will be extracted from
#    this snapshot to the repo.
#
# 2. Run this script, it will generate a file `opam_repo.patch`
#
# 3. Review the patch.
#
# 4. In the tezos opam-repository, create a new branch from master and
#    apply this patch. Push the patch and create a merge request. A
#    new docker image with all the prebuilt dependencies will be
#    created by the CI.
#
# 5. Update the variable `opam_repository_tag` in files
#    `scripts/version.sh` and `.gitlab-ci.yml` with the hash of the
#    newly created commit in `tezos/opam-repository`.
#
# 6. Enjoy your new dependencies

set -e

target="$(pwd)"/opam_repo.patch tmp_dir=$(mktemp -dt tezos_deps_opam.XXXXXXXX)

cleanup () {
    set +e
    echo Cleaning up...
    rm -rf "$tmp_dir"
    rm -rf Dockerfile
}
trap cleanup EXIT INT

script_dir="$(cd "$(dirname "$0")" && echo "$(pwd -P)/")"
src_dir="$(dirname "$script_dir")"

. "$script_dir"/version.sh

opams=$(find "$src_dir/vendors" "$src_dir/src" -name \*.opam -print)

## Shallow clone of opam repository (requires git protocol version 2)
export GIT_WORK_TREE="$tmp_dir"
export GIT_DIR="$GIT_WORK_TREE/.git"
git init
git config --local protocol.version 2
git remote add origin https://github.com/ocaml/opam-repository
git fetch --depth 1 origin "$full_opam_repository_tag"

## Adding the various tezos packages
packages=
for opam in $opams; do

    dir=$(dirname $opam)
    file=$(basename $opam)
    package=${file%.opam}
    packages=$packages,$package.dev
    mkdir -p "$tmp_dir"/packages/$package/$package.dev

    ## HACK: For some reason, `opam admin list/filter` do not follow
    ## `--with-test/doc` for 'toplevel' package, only for their
    ## 'dependencies.  We want the exact opposite (like for `opam
    ## install`), so we manually remove the tag in the most
    ## ugliest-possible way...

    sed -e "s/{ *with-test *}//" \
        -e "s/with-test \& //" \
        -e "s/\& with-test//" \
        -e "s/{ *with-doc *}//" \
        -e "s/with-doc \& //" \
        -e "s/\& with-doc//" \
        $opam > "$tmp_dir"/packages/$package/$package.dev/opam

done

## Filtering unrequired packages
cd $tmp_dir
git reset --hard "$full_opam_repository_tag"
opam admin filter --yes --resolve \
  $packages,ocaml,ocaml-base-compiler,odoc,opam-depext,js_of_ocaml-ppx,reactiveData,opam-ed

## Adding useful compiler variants
for variant in afl flambda fp fp+flambda spacetime ; do
    git checkout packages/ocaml-variants/ocaml-variants.$ocaml_version+$variant
done

## Removing the various tezos packages
for opam in $opams; do
    file=$(basename $opam)
    package=${file%.opam}
    rm -r "$tmp_dir"/packages/$package
done

## Adding safer hashes
opam admin add-hashes sha256 sha512

## Generating the diff!
git remote add tezos $opam_repository_url
git fetch --depth 1 tezos "$opam_repository_tag"
git reset "$opam_repository_tag"
git add packages
git diff HEAD -- packages > "$target"

echo
echo "Wrote proposed update in: $target."
echo 'Please add this patch to: `https://gitlab.com/tezos/opam-repository`'
echo 'And update accordingly the commit hash in: `.gitlab-ci.yml` and `scripts/version.sh`'
echo
