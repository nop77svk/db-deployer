#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail
[ -n "${DEBUG:-}" ] && set -x # xtrace

Here=$PWD
ScriptPath=$( dirname "$0" )
cd "${ScriptPath}"
ScriptPath=$PWD
cd "${Here}"

DateTimeToken=$( date +%Y%m%d-%H%M%S )
RndToken=${DateTimeToken}-${RANDOM}

# -------------------------------------------------------------------------------------------------

g_DepPackTmpFolder="_packed_content_tmp_folder.${RndToken}"

# -------------------------------------------------------------------------------------------------

mkdir "${Here}/${g_DepPackTmpFolder}"
cd "${Here}/${g_DepPackTmpFolder}"

( base64 --decode --ignore-garbage | tar xvz --no-same-owner ) <<-DependencyPack
<base64-encoded gzip'd tar'd deployment tree comes here>
DependencyPack

# -------------------------------------------------------------------------------------------------

. _execute_packed_content.sh "$@" -v "cfg_log_folder=${Here}"
cd "${Here}"
