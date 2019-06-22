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
<put here the output from "tar c . | gzip -9c | base64">
DependencyPack

# -------------------------------------------------------------------------------------------------

. _execute_packed_content.sh "$@" -v "cfg_log_folder=${Here}"
cd "${Here}"
