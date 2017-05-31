#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
set -o pipefail
set -o nounset
[ -n "${DEBUG:=}" ] && set -x # xtrace

# -------------------------------------------------------------------------------------------------

if [ "${Action}" = "prereq" -o "${Action}" = "sync" -o "${Action}" = "all" ] ; then
	InfoMessage "        Installing/upgrading the deployment engine repository"

	cd "${GlobalPluginsPath}/repo_ddl"
	set \
		| ${local_grep} -Ei '^dpltgt_deploy_repo_' \
		| ${local_sed} 's/^dpltgt_\(.*\)\s*=\s*\(.*\)\s*$/define \1 = \2/g' \
		| ${local_sed} "s/= '\(.*\)'$/= \1/g" \
		>> "_deploy_repo_defines.${RndToken}.tmp"

	"${SqlPlusBinary}" -L -S "${cfg_deploy_repo_db}" @_deploy_repository.sql ${RndToken} \
		|| ThrowException "SQL*Plus failed"
		2> "${TmpPath}/${Env}._deploy_repository.${RndToken}.err"
		> "${TmpPath}/${Env}._deploy_repository.${RndToken}.out"

	[ -z "${DEBUG}" ] && (
		rm -f "_deploy_repository.${RndToken}.log"
		rm -f "_deploy_repository.upgrade_script.${RndToken}.tmp"
		rm -f "${TmpPath}/${Env}._deploy_repository.${RndToken}.err"
		rm -f "${TmpPath}/${Env}._deploy_repository.${RndToken}.out"
		rm -f "_deploy_repo_defines.${RndToken}.tmp"
	)

	cd "${ScriptPath}"
fi
