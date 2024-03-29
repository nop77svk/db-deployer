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
set -o nounset
set -o pipefail
[ -n "${DEBUG:-}" ] && set -x # xtrace

Here=$PWD
ScriptPath=$( dirname "$0" )
cd "${ScriptPath}"
ScriptPath=$PWD
cd "${Here}"

# -------------------------------------------------------------------------------------------------
# setup auxiliary routines

CommonsPath="${ScriptPath}/.common"
. "${CommonsPath}/common.sh"

g_LogFolder="${Here}"
LogFileStub=run_deploy
#ErrorNotificationMailRecipients=
. "${CommonsPath}/error_handling.sh"

DoLog  ---------------------------------------------------------------------------------------------------

. "${CommonsPath}/os_specific_utils.sh"

ScriptPath=$( EchoPathWinToUnix "${ScriptPath}" )
Here=$( EchoPathWinToUnix "${Here}" )

# ------------------------------------------------------------------------------------------------

InfoMessage "Deployer configuration info"

InfoMessage "    running as "$( id -a )
InfoMessage "    current path = \"${Here}\""
InfoMessage "    script path = \"${ScriptPath}\""
InfoMessage "    path to commons = \"${CommonsPath}\""
InfoMessage "    unique filename token = \"${RndToken}\""

# ------------------------------------------------------------------------------------------------

# note: only the first argument is allowed to be "positionally" notated - for backwards compatibility reasons
if [ -z "${1:-}" ] ; then
	gx_Env=
	gx_Action=help
else if [ "${1:0:1}" = "-" ] ; then
	gx_Env=
	gx_Action=all
else
	gx_Env="${1:-as-set}"
	shift 1
	gx_Action=all
fi ; fi

unset OPTIND
unset gx_ConfigValueOverrides
declare -a gx_ConfigValueOverrides

while getopts e:a:hsv: l_arg_name ; do
	case "${l_arg_name}" in
		e)
			gx_Env="${OPTARG}"
			;;
		a)
			gx_Action="${OPTARG}"
			;;
		h)
			gx_Action=help
			;;
		s)
			gx_Action=sync
			;;
		v)
			[[ "${OPTARG}" =~ ^(cfg|dpltgt|dbgrp)_[a-zA-Z_]+=[^=[:space:]]*$ ]] || ThrowException "Invalid config var override \"${OPTARG}\""

			gx_ConfigValueOverrides+=("${OPTARG}")
			;;
		*)
			ThrowException "Error parsing command line argument #$OPTIND"
	esac
done
shift $((OPTIND-1))

InfoMessage "    target environment = \"${gx_Env}\""
[ "${gx_Action}" != "all" ] && InfoMessage "    specific deployment action = \"${gx_Action}\""
[ -n "${gx_ConfigValueOverrides:-}" ] && InfoMessage "    note: there are ${#gx_ConfigValueOverrides[*]} config value overrides on command line"

[ $# -eq 0 ] || ThrowException "There are $# positional arguments left on command line: \"$*\""

# ------------------------------------------------------------------------------------------------

if [ -n "${gx_Env}" ] ; then
	InfoMessage "Configuring the deployer"
	EnvPath=
	DeploySrcRoot=

	cd "${Here}"
	InfoMessage "    seeking for deployment sources root in \"${Here}\""
	while true ; do
		thisLevel=$(pwd)
		if [ "x${gx_Env}" = "xas-set" -a -f run_deploy.cfg ] ; then
			DeploySrcRoot="${thisLevel}"
			EnvPath="${thisLevel}"
			break
		else if [ "x${gx_Env}" != "xas-set" -a -d .env ] ; then
			DeploySrcRoot="${thisLevel}"
			EnvPath="${thisLevel}/.env"
			break
		else if [ "${thisLevel}" = / ] ; then
			break
		else
			InfoMessage "    now getting one level higher"
			cd ..
		fi ; fi ; fi
	done

	if [ "x${gx_Env}" != "xas-set" -a "x${EnvPath}" = "x" ] ; then
		InfoMessage "    not found; restarting from \"${ScriptPath}\""

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
				InfoMessage "    now getting one level higher"
				cd ..
			fi ; fi
		done
	fi

	if [ "x${DeploySrcRoot}" = "x" ] ; then
		ThrowException "Unable to determine deployment sources root"
	fi

	# ------------------------------------------------------------------------------------------------

	case "x${gx_Env}" in
		"xas-set" )
			DeployTargetConfigFile="${EnvPath}/run_deploy.cfg"
			;;
		"x" )
			DeployTargetConfigFile=
			;;
		* )
			DeployTargetConfigFile="${EnvPath}/${gx_Env}.cfg"
			;;
	esac

	InfoMessage "    environment config file in use = \"${DeployTargetConfigFile}\""
	. "${DeployTargetConfigFile}" || ThrowException "No \"${DeployTargetConfigFile}\" config file present"

	if [ -n "${gx_ConfigValueOverrides:-}" ] ; then
		InfoMessage "    overriding from command line"

		for l_cfg_ovd in "${gx_ConfigValueOverrides[@]}" ; do
			l_cfg_ovd_name="${l_cfg_ovd%%=*}"
			l_cfg_ovd_value="${l_cfg_ovd#*=}"
			if [[ "${l_cfg_ovd_name}" =~ passw(or)?d$ ]] ; then
				InfoMessage "        switch \"${l_cfg_ovd_name}\" from \"${!l_cfg_ovd_name:-}\" to \"*****\""
			else
				InfoMessage "        switch \"${l_cfg_ovd_name}\" from \"${!l_cfg_ovd_name:-}\" to \"*****\""
			fi
			eval "${l_cfg_ovd_name}='${l_cfg_ovd_value}'"
		done
	fi
fi

# ------------------------------------------------------------------------------------------------

formerLogFolder="${g_LogFolder}"
newLogFolder=$( EchoPathWinToUnix "${cfg_log_folder:-${g_LogFolder:-${DeploySrcRoot:-${Here}}}}" )

if [ "x${formerLogFolder}" != "x${newLogFolder}" ] ; then
	InfoMessage "    note: switching log output from \"${g_LogFolder}\" to \"${newLogFolder}\""
	g_LogFolder="${newLogFolder}"
	InfoMessage "    note: log output folder switched from \"${formerLogFolder}\" to \"${g_LogFolder}\""
fi

# ------------------------------------------------------------------------------------------------

if [ "${gx_Action}" != "help" ] ; then
	InfoMessage "Further configuring the deployer"

	TmpPath=$( EchoPathWinToUnix "${cfg_tmp_path:-${DeploySrcRoot}}" )
	TmpPath=$( EchoFolderAbsolutePath "${TmpPath}" )
	InfoMessage "    temporary files path = \"${TmpPath}\""

	GlobalPluginsPath="${ScriptPath}/.plugin"
	InfoMessage "    path to global plugins = \"${GlobalPluginsPath}\""

	LocalPluginsPath="${DeploySrcRoot}/.plugin"
	InfoMessage "    path to local plugins = \"${LocalPluginsPath}\""

	InfoMessage "    symbolic environment id = \"${cfg_environment:=}\""

	DeployRepoTech="${deploy_repo_tech:-oracle-sqlplus}"
	InfoMessage "    deployment repository technology = \"${DeployRepoTech}\""

	InfoMessage "    application identifier = \"${cfg_app_id:-}\""
	[ -n "${cfg_app_id:-}" ] || ThrowException "Application (= deployment repository tenant) identifier is not set"
	if echo "${cfg_app_id}" | grep -qEv '^[A-Za-z][A-Za-z0-9_-]*$' ; then
		ThrowException "Application identifier contains unallowed characters"
	fi
fi

# ------------------------------------------------------------------------------------------------

if [ "${gx_Action}" != "help" ] ; then
	InfoMessage "Preparing the temporary locations"

	touch "${TmpPath}/touch.${RndToken}.tmp" || ThrowException "Temporary files folder not writable"
	rm "${TmpPath}/touch.${RndToken}.tmp"

	cd "${TmpPath}"
	rm ${gx_Env}.*.tmp 2> /dev/null || true
	rm ${gx_Env}.*.sql 2> /dev/null || true
	rm ${gx_Env}.*.stderr.out 2> /dev/null || true
	rm ${gx_Env}.*.tbz2 2> /dev/null || true
	[ -z "${DEBUG:-}" ] && rm ${gx_Env}.*.log 2> /dev/null || true
fi

# ------------------------------------------------------------------------------------------------

declare -A g_techs_loaded
if [ "${gx_Action}" != "help" ] ; then
	InfoMessage "Initializing deployment technologies"

	set \
		| ${local_grep} -Ei '^dpltgt_.*_tech\s*=' \
		| ${local_sed} 's/^dpltgt_.*_tech\s*=\s*\(.*\)\s*$/\1/g' \
		| ${local_sort} -u \
		| ${local_gawk} '
			{
				print "InfoMessage \"    " $0 "\"";
				print ". \"${CommonsPath}/tech." $0 "/init.sh\" initialize";
				print "g_techs_loaded[''" $0 "'']=''yes''";
			}' \
		> "${TmpPath}/${gx_Env}.prepare_technologies.${RndToken}.tmp" \
		|| ThrowException "No(?) deployment technologies defined for target \"${gx_Env}\""

	. "${TmpPath}/${gx_Env}.prepare_technologies.${RndToken}.tmp"

	[ -z "${DEBUG:-}" ] || true && (
		rm "${TmpPath}/${gx_Env}.prepare_technologies.${RndToken}.tmp"
	)
fi

# ================================================================================================

if [ "${gx_Action}" != "help" ] ; then
	InfoMessage "Initializing repository technology (${DeployRepoTech})"
	if [ ! ${g_techs_loaded["${DeployRepoTech}"]} ] ; then
		. "${CommonsPath}/tech.${DeployRepoTech}/init.sh"
		g_techs_loaded["${DeployRepoTech}"]=yes
		cd "${ScriptPath}"
	fi

	DeployRepoTechPath="${CommonsPath}/repo.${DeployRepoTech}"
	. "${DeployRepoTechPath}/init.sh"
	cd "${ScriptPath}"
fi

# ------------------------------------------------------------------------------------------------

if [ "${gx_Action}" != "help" ] ; then
	l_plugins_found=()

	if [ -d "${GlobalPluginsPath}" -a "${GlobalPluginsPath}" != "${LocalPluginsPath}" ] ; then
		while read -r preScriptfile ; do
			l_plugins_found+=("${preScriptfile}")
		done < <( "${local_find}" "${GlobalPluginsPath}" -name 'pre-*.sh' | "${local_sort}" -t - -k 2 -n )
	fi

	if [ -d "${LocalPluginsPath}" ] ; then
		while read -r preScriptfile ; do
			l_plugins_found+=("${preScriptfile}")
		done < <( "${local_find}" "${LocalPluginsPath}" -name 'pre-*.sh' | "${local_sort}" -t - -k 2 -n )
	fi
	
	if (( ${#l_plugins_found[@]} )) ; then
		InfoMessage "Executing pre-deployment plugins"
		for preScriptfile in "${l_plugins_found[@]}" ; do
			( . "${preScriptfile}" )
		done
	fi
fi

# ------------------------------------------------------------------------------------------------

if [ "${gx_Action}" = "delta" -o "${gx_Action}" = "all" -o "${gx_Action}" = "sync" -o "${gx_Action}" = "delta-prep" ] ; then
	InfoMessage "Preparing the deployment"

	InfoMessage "    Fetching the complete list of increment script files"
	cd "${DeploySrcRoot}"

# 2do! do not ignore the "deploy_repo" target; do a limited set of actions instead!
	if [ ${OStype} = "cygwin" -o ${OStype} = "linux" -o ${OStype} = "mingw" ] ; then
		${local_find} . -mindepth 2 -not -path './.*/*' -not -name '*.~???' -not -name '*.???~' -not -name '*;deploy_repo.*' -not -name '*.tmp' -not -name '*.log' -type f | ${local_sed} 's/^\.\///g' > "${TmpPath}/${gx_Env}.script_full_paths.${RndToken}.tmp"
	else if [ ${OStype} = "SunOS" ] ; then
		${local_find} . ! -name '*.???~' ! -name '*.~???' ! -name '*;deploy_repo.*' -! -name '*.tmp' -! -name '*.log' -type f | ${local_grep} -Evi '^\.\/\..*\/' 2> /dev/null | ${local_gawk} -v depf=2 -v FS='/' 'NF>=(1+depf)' > "${TmpPath}/${gx_Env}.script_full_paths.${RndToken}.tmp"
	else
		ThrowException "ERROR: Unknown OS type!"
	fi ; fi
fi

# ------------------------------------------------------------------------------------------------

if [ "${gx_Action}" = "delta" -o "${gx_Action}" = "all" -o "${gx_Action}" = "sync" -o "${gx_Action}" = "delta-prep" ] ; then
	InfoMessage "    Merging the list of found script files to (unfinished increments in) deployment repository"

	cd "${TmpPath}"
	DeployRepo_MergeIncrements
fi

# ------------------------------------------------------------------------------------------------

if [ "${gx_Action}" = "delta" -o "${gx_Action}" = "all" -o "${gx_Action}" = "sync" -o "${gx_Action}" = "delta-prep" ] ; then
	InfoMessage "    Setting up a deployment run"

	cd "${DeploySrcRoot}"
	DeployRepo_CreateRun "${gx_Action}"
fi

# ------------------------------------------------------------------------------------------------

if [ "${gx_Action}" = "delta" -o "${gx_Action}" = "all" -o "${gx_Action}" = "delta-prep" ] ; then
	InfoMessage "    Fetching the ultimate list of scripts to run from repository"

	cd "${DeploySrcRoot}"
	DeployRepo_GetListToExecute
fi

# ------------------------------------------------------------------------------------------------

if [ "${gx_Action}" = "delta" -o "${gx_Action}" = "all" ] ; then
	InfoMessage "Running the deployment"
	cd "${DeploySrcRoot}"

	IFS='|'
	cat "${TmpPath}/${gx_Env}.retrieve_the_deployment_setup.${RndToken}.tmp" \
		| tr '\r' '\n' \
		| while read -r l_id_script_execution l_num_order l_id_script l_id_increment l_target_id l_script_folder l_script_file l_add_info || break
	do
		[ -z "${l_id_script_execution}" ] && continue
		InfoMessage "    script \"${l_script_folder}/${l_script_file}\" (ID \"${l_id_script}\", exec \"${l_id_script_execution}\") in schema \"${l_target_id}\""

		if ( echo ",${cfg_target_no_run:-}," | ${local_grep} -q ",${l_target_id}," ) ; then
			l_is_fake_exec=yes
		else if [ "${gx_Action}" = "sync" ] ; then
			l_is_fake_exec=yes
		else
			l_is_fake_exec=no
		fi ; fi

		# ----------------------------------------------------------------------------------------------

		# 2do! pass the l_add_info to both repository and technology APIs?
		if [ "${l_is_fake_exec}" = "no" ] ; then
			l_script_tech_var=dpltgt_${l_target_id}_tech
			l_script_tech=${!l_script_tech_var:-oracle-sqlplus}

			InfoMessage "        pre-phase"

			DeployRepo_PrePhase "${l_id_script}" "${l_id_script_execution}"

			# ----------------------------------------------------------------------------------------------

			InfoMessage "        execution"

			. "${CommonsPath}/tech.${l_script_tech}/api.sh" \
				run \
				"${l_id_script}" "${l_id_script_execution}" \
				"${l_target_id}" \
				"${l_script_folder}" "${l_script_file}"

			l_script_return_code=$?

			# ----------------------------------------------------------------------------------------------

			InfoMessage "        post-phase"

			DeployRepo_PostPhase "${l_id_script}" "${l_id_script_execution}" "${l_script_return_code}"

			# ----------------------------------------------------------------------------------------------

			if [ ${l_script_return_code} -gt 0 ] ; then
				ThrowException "The most recent increment script exited with status of ${l_script_return_code}"
			fi

			[ -z "${DEBUG:-}" ] || true && (
				. "${CommonsPath}/tech.${l_script_tech}/api.sh" cleanup "${l_id_script}" "${l_id_script_execution}"
				DeployRepo_CleanUp "${l_id_script}" "${l_id_script_execution}"
			)

		# ----------------------------------------------------------------------------------------------
		else
			InfoMessage "        fake execution for deployment repository synchronization"

			DeployRepo_FakeExecution "${l_id_script}" "${l_id_script_execution}"
			l_script_return_code=$?
		fi
	done

	# note: the following catches the explicit exception thrown above
	l_script_return_code=$?
	[ ${l_script_return_code} -gt 0 ] && exit ${l_script_return_code}

	unset IFS
	[ -z "${DEBUG:-}" ] || true && (
		rm "${TmpPath}/${gx_Env}.retrieve_the_deployment_setup.${RndToken}.sql"
		rm "${TmpPath}/${gx_Env}.retrieve_the_deployment_setup.${RndToken}.tmp"
	)
fi

# ------------------------------------------------------------------------------------------------

if [ "${gx_Action}" != "help" ] ; then
	l_plugins_found=()

	if [ -d "${GlobalPluginsPath}" -a "${GlobalPluginsPath}" != "${LocalPluginsPath}" ] ; then
		while read -r postScriptFile ; do
			l_plugins_found+=("${postScriptFile}")
		done < <( "${local_find}" "${GlobalPluginsPath}" -name 'post-*.sh' | "${local_sort}" -t - -k 2 -n )
	fi

	if [ -d "${LocalPluginsPath}" ] ; then
		while read -r postScriptFile ; do
			l_plugins_found+=("${postScriptFile}")
		done < <( "${local_find}" "${LocalPluginsPath}" -name 'post-*.sh' | "${local_sort}" -t - -k 2 -n )
	fi

	if (( ${#l_plugins_found[@]} )) ; then
		InfoMessage "Executing post-deployment plugins"
		for postScriptFile in "${l_plugins_found[@]}" ; do
			( . "${postScriptFile}" )
		done
	fi
fi

# ------------------------------------------------------------------------------------------------

if [ "${gx_Action}" = "help" ] ; then
	DoLog "Help screen invoked!"

	cat <<-EOF
		-------------------------------------------------------------------------------------
		Run as
		    $0 [<env id>] [ -e <env id> | -s | -v <cfg var>=<value> | -h ]*
		where
		    * <env id> refers to the .cfg files within your sources' .env folder,
		        * If not supplied, the script searches for run_deploy.cfg in the "current"
		          folder and all super-folders.
		    * -e <env id> is an alternative to the (legacy) way of specifying deployment
		      environment id,
		    * -s causes the deployer only to store the list of script files in the deployment
		      repository marked as "executed successfully",
		        * This is helpful in setting up new environment with list of "patches" already
		          deployed at other already existing evironments.
		    * -v causes a deployment target variable (dpltgt_*, dbgrp_*) or an environment
		      specific config variable (cfg_*) to be set up/overridden from a CLI,
		        * WARNING: Use with caution! You may be overriding a well designed deployment
		          configuration with invalid and/or potentially harmful values!
		    * -h shows this help info.
		        * If an environment id is supplied, the list of available deployment targets
		          is shown as well.
		-------------------------------------------------------------------------------------
		Each deployment increment consists of a "package" of "scripts".

		Each "package" is a leaf-level folder of name of "yyyymmdd-hh24mi;some_comment" where
		the ";some_comment" part is optional.

		    * The "yyyymmdd-hh24mi" part is parsed and stored in deployment repository
		      and will be used for ordering of the "packages" during a deployment.
		    * The "some_comment" part is also stored deployment repository, but is
		      informative only.

		Each "script" is a leaf-level file of name "nnnnnnnn;target_id.extension" placed in
		the "package" folder.

		    * The "nnnnnnnn" part is an arbitrary positive integer with arbitrary number of
		      leading zeroes, is parsed and stored in deployment repository and
		      will be used for ordering of the "scripts" within a package during a deployment.
		    * The "target_id" part is mandatory and contains the deployment target identifier
		      under which the script has to be executed. The target identifier refers to the
		      dpltgt_<target_id>_<something> and dbgrp_<target_id> variables defined in
		      the environment config file.
		    * The "extension" part can be anything. Usually it is "sql" for any scripts,
		      "pck" for packages, "vw" for views, "trg" for triggers, and so on. You decide.
		      The actual behaviour for an extension is to be decided by the respective
		      technology in use for a particular deployment target.
	EOF

	if [ -n "${gx_Env}" ] ; then
		cat <<-EOF
			-------------------------------------------------------------------------------------
			List of deployment targets available for environment "${gx_Env}":
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
	fi

	cat <<-EOF
		-------------------------------------------------------------------------------------
	EOF
fi

# ------------------------------------------------------------------------------------------------

if [ "${gx_Action}" != "help" ] ; then
	InfoMessage "CleanUp"

	for l_tech_id in ${!g_techs_loaded[@]} ; do
		InfoMessage "    for \"${l_tech_id}\" technology"
		"${CommonsPath}/tech.${l_tech_id}/api.sh" teardown
	done
fi

# ------------------------------------------------------------------------------------------------

InfoMessage "DONE"

cd "${Here}"
