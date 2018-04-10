#!/bin/bash
# ------------------------------------------------------------------------------------------------
# incremental deployments framework
# ------------------------------------------------------------------------------------------------
# author: Peter Hrasko
# e-mail: peter.hrasko.sk@gmail.com
# web:    peterhrasko.wordpress.com
# ------------------------------------------------------------------------------------------------
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
# setup auxiliary routines

CommonsPath=${ScriptPath}/.common
. "${CommonsPath}/common.sh"

LogFolder="${ScriptPath}"
LogFileStub=run_deploy
#ErrorNotificationMailRecipients=
. "${CommonsPath}/error_handling.sh"

DoLog  ---------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------

InfoMessage "Deployer configuration info"

InfoMessage "    running as "$( id -a )
InfoMessage "    current path = \"${Here}\""
InfoMessage "    script path = \"${ScriptPath}\""
InfoMessage "    path to commons = \"${CommonsPath}\""
InfoMessage "    filename token = \"${RndToken}\""

l_action=${2:-all}
Env=${1:-as-set}

if [ "${Env}" = "help" ] ; then
	Env='dev'
	l_action=help
fi

[ "${l_action}" != "all" ] && InfoMessage "    specific action = \"${l_action}\""
InfoMessage "    client-defined environment = \"${Env}\""

# ------------------------------------------------------------------------------------------------

set -o nounset

InfoMessage "Seeking for deployment sources root"
EnvPath=
DeploySrcRoot=

cd "${Here}"
InfoMessage "    Starting from \"${Here}\""
while true ; do
	thisLevel=$(pwd)
	if [ "x${Env}" != "xas-set" -a -d .env ] ; then
		DeploySrcRoot="${thisLevel}"
		EnvPath="${thisLevel}/.env"
		break
	else if [ "x${Env}" = "xas-set" -a -f run_deploy.cfg ] ; then
		DeploySrcRoot="${thisLevel}"
		EnvPath="${thisLevel}"
		break
	else if [ "${thisLevel}" = / ] ; then
		break
	else
		InfoMessage "    Now getting one level higher"
		cd ..
	fi ; fi ; fi
done

if [ "x${Env}" != "xas-set" -a "x${EnvPath}" = "x" ] ; then
	InfoMessage "    Not found; Restarting from \"${ScriptPath}\""

	cd "${ScriptPath}"
	while true ; do
		thisLevel=$(pwd)
		if [ -d .env ] ; then
			DeploySrcRoot="${thisLevel}"
			EnvPath="${thisLevel}/.env"
			break
		else if [ "${thisLevel}" = / ] ; then
			break
		else
			InfoMessage "    Now getting one level higher"
			cd ..
		fi ; fi
	done
fi

if [ "x${DeploySrcRoot}" = "x" ] ; then
	ThrowException "Unable to determine deployment sources root"
fi

if [ "x${Env}" != "xas-set" ] ; then
	DeployTargetConfigFile="${EnvPath}/${Env}.cfg"
else
	DeployTargetConfigFile="${EnvPath}/run_deploy.cfg"
fi

InfoMessage "    determined deployment sources root = \"${DeploySrcRoot}\""
InfoMessage "    environment config file in use = \"${DeployTargetConfigFile}\""

. "${DeployTargetConfigFile}" || ThrowException "No \"${DeployTargetConfigFile}\" config file present"

InfoMessage "    note: switching log output from \"${LogFolder}\" to \"${DeploySrcRoot}\""
formerLogFolder="${LogFolder}"
LogFolder="${DeploySrcRoot}"
. "${CommonsPath}/error_handling.sh"
InfoMessage "    note: log output folder switched from \"${formerLogFolder}\" to \"${LogFolder}\""

GlobalPluginsPath="${ScriptPath}/.plugin"
LocalPluginsPath="${DeploySrcRoot}/.plugin"

# ------------------------------------------------------------------------------------------------

InfoMessage "Further configuring the deployer"

LogPath=$( FolderAbsolutePath "${LogPath:-${DeploySrcRoot}}" )
TmpPath=$( FolderAbsolutePath "${TmpPath:-${DeploySrcRoot}}" )

InfoMessage "    temporary files path = \"${TmpPath}\""
InfoMessage "    log files path = \"${LogPath}\""
InfoMessage "    symbolic environment id = \"${cfg_environment}\""

DeployRepoTech=${dpltgt_deploy_repo_tech:-oracle}
InfoMessage "    deployment repository technology = \"${DeployRepoTech}\""

cd "${TmpPath}"

# ------------------------------------------------------------------------------------------------

InfoMessage "Prechecks"

touch "${TmpPath}/touch.${RndToken}.tmp" || ThrowException "Temporary files folder not writable"
rm "${TmpPath}/touch.${RndToken}.tmp"

# ------------------------------------------------------------------------------------------------

InfoMessage "Cleaning up the temporary folder"

cd "${TmpPath}"
rm ${Env}.*.tmp 2> /dev/null || InfoMessage '    Note: No TMP files to clean up'
rm ${Env}.*.sql 2> /dev/null || InfoMessage '    Note: No SQL files to clean up'
rm ${Env}.*.stderr.out 2> /dev/null || InfoMessage '    Note: No STDERR.OUT files to clean up'
rm ${Env}.*.tbz2 2> /dev/null || InfoMessage '    Note: No TBZ2 files to clean up'
[ -z "${DEBUG:-}" ] && rm ${Env}.*.log 2> /dev/null || InfoMessage '    Note: No LOG files to clean up'

# ------------------------------------------------------------------------------------------------

InfoMessage "Shell/OS-specific setup"

. "${CommonsPath}/os_specific_utils.sh"
InfoMessage "    You are on \"${OStype}\""

TmpPath=$( PathWinToUnix "${TmpPath}" )
ScriptPath=$( PathWinToUnix "${ScriptPath}" )
Here=$( PathWinToUnix "${Here}" )

# ------------------------------------------------------------------------------------------------

InfoMessage "Preparing deployment technologies"

set \
	| ${local_grep} -Ei '^dpltgt_.*_tech\s*=' \
	| ${local_sed} 's/^dpltgt_.*_tech\s*=\s*\(.*\)\s*$/\1/g' \
	| ${local_sort} -u \
	| ${local_gawk} '
		{
			print "InfoMessage \"    " $0 "\"";
			print ". \"${CommonsPath}/tech." $0 "/technology.sh\" initialize";
		}' \
	> "${TmpPath}/${Env}.prepare_technologies.${RndToken}.tmp" \
	|| ThrowException "No(?) deployment technologies defined for target \"${Env}\""

. "${TmpPath}/${Env}.prepare_technologies.${RndToken}.tmp"

[ -z "${DEBUG:-}" ] || true && (
	rm "${TmpPath}/${Env}.prepare_technologies.${RndToken}.tmp"
)

# ================================================================================================

InfoMessage "Initializing deployment repository (${DeployRepoTech})"
. "${CommonsPath}/tech.${DeployRepoTech}/repository.sh" initialize

# ------------------------------------------------------------------------------------------------

if [ "${l_action}" != "help" ] ; then
	InfoMessage "Executing pre-deployment plugins"

	[ -d "${GlobalPluginsPath}" -a "${GlobalPluginsPath}" != "${LocalPluginsPath}" ] \
		&& "${local_find}" "${GlobalPluginsPath}" -name 'pre-*.sh' \
			| "${local_sort}" -t - -k 2 -n \
			| while read -r preScriptfile
		do
			InfoMessage "    ${preScriptfile} (global)"
			( . "${preScriptfile}" )
		done

	[ -d "${LocalPluginsPath}" ] \
		&& "${local_find}" "${LocalPluginsPath}" -name 'pre-*.sh' \
			| "${local_sort}" -t - -k 2 -n \
			| while read -r preScriptfile
		do
			InfoMessage "    ${preScriptfile}"
			( . "${preScriptfile}" )
		done
fi

# ------------------------------------------------------------------------------------------------

InfoMessage "Preparing the deployment"

if [ "${l_action}" = "delta" -o "${l_action}" = "all" -o "${l_action}" = "sync" -o "${l_action}" = "delta-prep" ] ; then
	InfoMessage "    Fetching the complete list of increment script files"
	cd "${DeploySrcRoot}"

	if [ ${OStype} = "cygwin" ] ; then
		${local_find} . -mindepth 2 -not -path './.*/*' -not -name '*.~???' -not -name '*.???~' -type f | ${local_sed} 's/^\.\///g' > "${TmpPath}/${Env}.script_full_paths.${RndToken}.tmp"
	else if [ ${OStype} = "SunOS" ] ; then
		${local_find} . ! -name '*.???~' ! -name '*.~???' -type f | ${local_grep} -Evi '^\.\/\..*\/' 2> /dev/null | ${local_gawk} -v depf=2 -v FS='/' 'NF>=(1+depf)' > "${TmpPath}/${Env}.script_full_paths.${RndToken}.tmp"
	else
		ThrowException "ERROR: Unknown OS type!"
	fi ; fi
fi

# ------------------------------------------------------------------------------------------------

if [ "${l_action}" = "delta" -o "${l_action}" = "all" -o "${l_action}" = "sync" -o "${l_action}" = "delta-prep" ] ; then
	InfoMessage "    Merging the list of found script files to (unfinished increments in) deployment repository"

	cd "${TmpPath}"
	. "${CommonsPath}/tech.${DeployRepoTech}/repository.sh" \
		merge-inc
fi

# ------------------------------------------------------------------------------------------------

if [ "${l_action}" = "delta" -o "${l_action}" = "all" -o "${l_action}" = "sync" -o "${l_action}" = "delta-prep" ] ; then
	InfoMessage "    Setting up a deployment run"

	cd "${DeploySrcRoot}"
	. "${CommonsPath}/tech.${DeployRepoTech}/repository.sh" \
		create-run \
		"${l_action}"
fi

# ------------------------------------------------------------------------------------------------

if [ "${l_action}" = "delta" -o "${l_action}" = "all" -o "${l_action}" = "delta-prep" ] ; then
	InfoMessage "    Fetching the ultimate list of scripts to run from repository"

	cd "${DeploySrcRoot}"
	. "${CommonsPath}/tech.${DeployRepoTech}/repository.sh" \
		get-list-to-exec
fi

# ------------------------------------------------------------------------------------------------

if [ "${l_action}" = "delta" -o "${l_action}" = "all" ] ; then
	InfoMessage "Running the deployment"
	cd "${DeploySrcRoot}"

	IFS='|'
	cat "${TmpPath}/${Env}.retrieve_the_deployment_setup.${RndToken}.tmp" \
		| tr '\r' '\n' \
		| while read -r l_id_script_execution l_num_order l_id_script l_id_increment l_schema_id l_script_folder l_script_file l_add_info || break
	do
		[ -z "${l_id_script_execution}" ] && continue
		InfoMessage "    script \"${l_script_folder}/${l_script_file}\" (ID \"${l_id_script}\", exec \"${l_id_script_execution}\") in schema \"${l_schema_id}\""

		if ( echo ",${cfg_target_no_run:-}," | ${local_grep} -q ",${l_schema_id}," ) ; then
			l_is_fake_exec=yes
		else if [ "${l_action}" = "sync" ] ; then
			l_is_fake_exec=yes
		else
			l_is_fake_exec=no
		fi ; fi

		# ----------------------------------------------------------------------------------------------

		# 2do! pass the l_add_info to both repository.sh and script_exec.sh
		if [ "${l_is_fake_exec}" = "no" ] ; then
			l_script_tech_var=dpltgt_${l_schema_id}_tech
			l_script_tech=${!l_script_tech_var:-oracle}

			InfoMessage "        pre-phase"

			. "${CommonsPath}/tech.${DeployRepoTech}/repository.sh" \
				pre-phase-run \
				"${l_id_script}" "${l_id_script_execution}"

			# ----------------------------------------------------------------------------------------------

			InfoMessage "        execution"

			. "${CommonsPath}/tech.${l_script_tech}/script_exec.sh" \
				run \
				"${l_id_script}" "${l_id_script_execution}" \
				"${l_schema_id}" \
				"${l_script_folder}" "${l_script_file}"

			l_script_return_code=$?

			# ----------------------------------------------------------------------------------------------

			InfoMessage "        post-phase"

			. "${CommonsPath}/tech.${DeployRepoTech}/repository.sh" \
				post-phase-run \
				"${l_id_script}" "${l_id_script_execution}" \
				"${l_script_return_code}"

			# ----------------------------------------------------------------------------------------------

			if [ ${l_script_return_code} -gt 0 ] ; then
				ThrowException "The most recent increment script exited with status of ${l_script_return_code}"
			fi

			[ -z "${DEBUG:-}" ] || true && (
				. "${CommonsPath}/tech.${l_script_tech}/script_exec.sh" cleanup "${l_id_script}" "${l_id_script_execution}"
				. "${CommonsPath}/tech.${DeployRepoTech}/repository.sh" cleanup "${l_id_script}" "${l_id_script_execution}"
			)

		# ----------------------------------------------------------------------------------------------
		else
			InfoMessage "        fake execution for deployment repository synchronization"

			. "${CommonsPath}/tech.${DeployRepoTech}/repository.sh" fake-exec "${l_id_script}" "${l_id_script_execution}"
			l_script_return_code=$?
		fi
	done

	# note: the following catches the explicit exception thrown above
	l_script_return_code=$?
	[ ${l_script_return_code} -gt 0 ] && exit ${l_script_return_code}

	unset IFS
	[ -z "${DEBUG:-}" ] || true && (
		rm "${TmpPath}/${Env}.retrieve_the_deployment_setup.${RndToken}.sql"
		rm "${TmpPath}/${Env}.retrieve_the_deployment_setup.${RndToken}.tmp"
	)
fi

# ------------------------------------------------------------------------------------------------

if [ "${l_action}" != "help" ] ; then
	InfoMessage "Executing post-deployment plugins"

	[ -d "${GlobalPluginsPath}" -a "${GlobalPluginsPath}" != "${LocalPluginsPath}" ] \
		&& "${local_find}" "${GlobalPluginsPath}" -name 'post-*.sh' \
			| "${local_sort}" -t - -k 2 -n \
			| while read -r postScriptfile
		do
			InfoMessage "    ${postScriptfile} (global)"
			( . "${postScriptfile}" )
		done

	[ -d "${LocalPluginsPath}" ] \
		&& "${local_find}" "${LocalPluginsPath}" -name 'post-*.sh' \
			| "${local_sort}" -t - -k 2 -n \
			| while read -r postScriptfile
		do
			InfoMessage "    ${postScriptfile}"
			( . "${postScriptfile}" )
		done
fi

# ------------------------------------------------------------------------------------------------

if [ "${l_action}" = "help" ] ; then
	DoLog "Help screen invoked!"

	cat <<-EOF
		-------------------------------------------------------------------------------------
		Each deployment increment consists of a "package" of "scripts".

		Each "package" is a leaf-level folder of name of "yyyymmdd-hh24mi;some_comment" where
		the ";some_comment" part is optional.

		    * The "yyyymmdd-hh24mi" part is parsed and stored in T_DB_INCREMENT.DAT_FOLDER
		      column and will be used for ordering of the "packages" during a deployment.
		    * The "some_comment" part is stored in T_DB_INCREMENT.TXT_COMMENT column.

		Each "script" is a leaf-level file of name "nnnnnnnn;target_id.extension" placed in
		the "package" folder.

		    * The "nnnnnnnn" part is an arbitrary positive integer with arbitrary number of
		      leading zeroes, is parsed and stored in the T_DB_SCRIPT.NUM_ORDER column and
		      will be used for ordering of the "scripts" within a package during a deployment.
		    * The "target_id" part is mandatory and contains the deployment target identifier
		      under which the script has to be executed. The target identifier refers to the
		      dpltgt_<target_id>_<something> and dbgrp_<target_id> variables defined on the
              level of a deployment tool.
		    * The "extension" part can be anything. Usually it is "sql" for any scripts,
		      "pck" for packages, "vw" for views, "trg" for triggers, and so on. You decide.
		-------------------------------------------------------------------------------------
		List of deployment targets available for environment "${Env}":
	EOF

	declare | ${local_grep} -E '^(dpltgt|dbgrp)_' \
		| ${local_gawk} '
			$0 ~ /^dpltgt_/ {
				match($0, /^dpltgt_(.*)_(db|user|password)\s*=/, xx);
				targetName = xx[1];
				if (targetName != "")
					targetList[targetName] = "atomic";
			}

			$0 ~ /^dbgrp_/ {
				match($0, /^dbgrp_(.*)\s*=/, xx);
				targetName = xx[1];
				if (targetName != "")
					targetList[targetName] = "composite";
			}

			END {
				asorti(targetList, tlistOrder);
				for (i in tlistOrder)
				{
					j = tlistOrder[i];
					print "    * " j (targetList[j] != "atomic" ? " (" targetList[j] ")" : "");
				}
			}
		'

	cat <<-EOF
		-------------------------------------------------------------------------------------
	EOF
fi

# ------------------------------------------------------------------------------------------------

if [ "${l_action}" != "help" ] ; then
	InfoMessage "CleanUp"

	set \
		| ${local_grep} -Ei '^dpltgt_.*_tech\s*=' \
		| ${local_sed} 's/^dpltgt_.*_tech\s*=\s*\(.*\)\s*$/\1/g' \
		| ${local_sort} -u \
		| ${local_gawk} '
			{
				print "InfoMessage \"    for " $0 "\"";
				print ". \"${CommonsPath}/tech." $0 "/technology.sh\" teardown";
			}' \
		> "${TmpPath}/${Env}.cleanup.${RndToken}.tmp"

	. "${TmpPath}/${Env}.cleanup.${RndToken}.tmp"

	[ -z "${DEBUG:-}" ] || true && (
		rm "${TmpPath}/${Env}.cleanup.${RndToken}.tmp"
	)
fi

# ------------------------------------------------------------------------------------------------

InfoMessage "DONE"

cd "${Here}"
