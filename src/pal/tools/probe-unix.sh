#!/usr/bin/env bash
# vim: set ts=4 sw=4 et ai :

declare -r clang_min_version="3.5"

get_clang_version() {
    local clang="$1"
    "$clang" --version | head -n 1 | sed -r 's/.*\(based on LLVM ([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/'
}

# Compares two version strings. Usage:
#   version_cmp <v1> <v2>
# exit code:
#   0 if v1 and v2 represents the same version
#   1 if v1 < v2
#   2 if v1 > v2
version_cmp() {
    local v1="$1"
    local v2="$2"
    local -a v1parts
    local -a v2parts
    local p1
    local p2

    IFS='.' read -a v1parts <<< "$v1"
    IFS='.' read -a v2parts <<< "$v2"
    if [[ ${#v1parts[@]} > ${#v2parts[@]} ]]; then
        cnt=${#v1parts[@]}
    else
        cnt=${#v2parts[@]}
    fi
    for i in seq 0 $((cnt-1)); do
        p1="${v1parts[i]}"
        if [[ -z "$p1" ]]; then
            p1=0
        fi
        p2="${v2parts[i]}"
        if [[ -z "$p2" ]]; then
            p2=0
        fi
        if [[ "$p1" < "$p2" ]]; then
            return 1
        elif [[ "$p1" > "$p2" ]]; then
            return 2
        fi
    done
    return 0
}

is_version() {
    local v="$1"
    grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)*$' <<< "$v"
}

check_clang_version() {
    local clang_version="$1"

    if ! is_version "$clang_version"; then
        return 2
    fi
    version_cmp $clang_min_version $clang_version
    if [[ $? == 2 ]]; then # min_version > clang_version
        return 1
    else
        return 0
    fi
}

check_clang() {
    local clang="$1"
    local clang_version="$(get_clang_version "$1")"
    check_clang_version "$clang_version"
}

get_newest_clang() {
	local -a clang_versions=("${!1}")
	local -a clang_paths=("${!2}")
    local -a newest_version='0.0'
    local -a newest_path
    for i in seq 0 $((${#clang_versions[@]}-1)); do
        version_cmp "$newest_version" "${clang_versions[i]}"
        if [[ $? == 1 ]]; then # newest_version < clang_versions[i]
            newest_version="${clang_versions[i]}"
            newest_path="${clang_paths[i]}"
        fi
    done
    echo "$newest_path"
}

# Locate a clang of at least $clang_min_version
# 1. Check if CXX or CC is set and is a clang that is at least 3.5, then use that
# 2. Use whatever clang is given that it's at least 3.5
# 3. Use the newest version of clang available
locate_clang() {
    local clang_version
    local -a clang_version
    local -a clang_versions
    local -a clang_paths

    if hash clang 2>/dev/null; then
        if check_clang clang; then
            which clang
            return 0
        fi
    fi
    if [[ -n "$CC" ]]; then
        if check_clang "$CC"; then
            echo "$CC"
            return 0
        else
            echo 'If $CC is set then it must point to a clang of at least version '$clang_min_version >&2
            return 2
        fi
    fi
    if [[ -n "$CXX" ]]; then
        if check_clang "$CXX"; then
            echo "$CXX"
            return 0
        else
            echo 'If $CXX is set then it must point to a clang of at least version '$clang_min_version >&2
            return 2
        fi
    fi
    IFS=':' read -a pathParts <<< "$PATH"

    for f in find -L "${pathParts[@]}" -maxdepth 1 -type f -regex '.*/clang-[0-9]+\.[0-9]+\(\.[0-9]+\)?' -print; do
        clang_version="$(get_clang_version "$clang")"
        if check_clang_version "$clang_version"; then
            clang_versions+=("$clang_version")
            clang_paths+=("$f")
        fi
    done
    if [[ ${#clang_versions[@]} == 0 ]]; then
        echo "No valid versions of clang found. Ensure a clang of at least" \
             "version $clang_min_version is on the path or set the CC environment variable" \
             "to point to a clang of at least version 3.5" >&2
        return 1
    fi
    get_newest_clang clang_versions[@] clang_paths[@]
}

locate_versioned_exec() {
    true
}
