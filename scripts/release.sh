#!/bin/sh

set -e

. libstd-ecm.sh

REPOSITORY='rosskirkpat/wins'
STRICT_MATCH='true'
LIST_ASSETS='true'

usage() {
    echo "usage: $0 [dhlr] <repository>
    -l    list assets file names
    -r    set target repository. default: $REPOSITORY
    -p    use release tag prefix instead. ie: v0.4.0
    -x    print debug messages
    -h    show help

examples:
    $0 v0.4.0 
    $0 -r rosskirkpat/wins -p v0.4.1"
}

while getopts 'a:xhlr:p' c; do
    case "${c}" in
    x)
        set_debug
        ;;
    r)
        REPOSITORY=$OPTARG
        ;;
    p)
        STRICT_MATCH='false'
        ;;
    l)
        LIST_ASSETS='true'
        ;;
    h)
        usage
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
    esac
done

shift $((OPTIND - 1))
if [ -z "${1}" ]; then
    echo "error: release tag required"
    usage
    exit 1
fi

has_gh

# gh environment variable overrides
export GH_REPO="${REPOSITORY}"
export PAGER='cat'

setup_tmp

if [ "${STRICT_MATCH}" = 'true' ]; then
    for tag in "$@"; do
        echo "${tag}" >>"${TMP_DIR}/release-list"
    done
else
    PATTERN=".tag_name | startswith(\"${1}\")"
    gh api 'repos/{owner}/{repo}/releases' -q ".[] | select(${PATTERN}) | \"\(.tag_name)\" " >"${TMP_DIR}/release-list"
fi

while IFS= read -r tag_name; do
    wins='wins.exe'
    gh release view "${tag_name}" --json assets -q '.assets.[] | .name' >"${TMP_DIR}/${tag_name}-assets"
    if grep -vq $wins "${TMP_DIR}/${tag_name}-assets"; then
        echo "uploading $wins to ${REPOSITORY}"
        gh release upload "${tag_name}" /mnt/c/package/$wins -R "${REPOSITORY}"
    fi
    assets_count=$(wc -l <"${TMP_DIR}/${tag_name}-assets")

done <"${TMP_DIR}/release-list"

if [ "${LIST_ASSETS}" = 'true' ]; then
    find "${TMP_DIR}" -type f -name '*-assets' -exec \
        sh -c '_file="$1"; echo "=== $(basename -s -assets $_file)"; cat $_file' shell {} \;  
fi


exit 0
