#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
#set -o nounset
set -o pipefail
[ -n "${DEBUG:-}" ] && set -x # xtrace

Here=$PWD
ScriptPath=$( dirname "$0" )
cd "${ScriptPath}"
ScriptPath=$PWD
cd "${Here}"

# -------------------------------------------------------------------------------------------------

g_DepPackTmpFolder='_dependency_pack_tmp_folder' # 2do! 

# -------------------------------------------------------------------------------------------------

mkdir "${Here}/${g_DepPackTmpFolder}" || true
cd "${Here}/${g_DepPackTmpFolder}"

( base64 --decode --ignore-garbage | tar xvz --no-same-owner ) <<-DependencyPack
<base64-encoded gzip'd tar'd deployment tree comes here>
DependencyPack

# -------------------------------------------------------------------------------------------------

. _execute_after_unpacking.sh "$@"
cd "${Here}"
rm -rf "${g_DepPackTmpFolder}"
