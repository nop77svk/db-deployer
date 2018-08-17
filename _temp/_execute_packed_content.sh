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

# -------------------------------------------------------------------------------------------------

cd "${ScriptPath}/src"
bash ../bin/run_deploy.sh "$@"
cd "${Here}"
