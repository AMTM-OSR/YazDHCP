#!/bin/sh

##########################################################
##                                                      ##
##  __     __          _____   _    _   _____  _____    ##
##  \ \   / /         |  __ \ | |  | | / ____||  __ \   ##
##   \ \_/ /__ _  ____| |  | || |__| || |     | |__) |  ##
##    \   // _` ||_  /| |  | ||  __  || |     |  ___/   ##
##     | || (_| | / / | |__| || |  | || |____ | |       ##
##     |_| \__,_|/___||_____/ |_|  |_| \_____||_|       ##
##                                                      ##
##         https://github.com/AMTM-OSR/YazDHCP/         ##
##    Forked from https://github.com/jackyaz/YazDHCP    ##
##                                                      ##
##########################################################
# Last Modified: 2025-Jul-20
#---------------------------------------------------------

#############################################
# shellcheck disable=SC2012
# shellcheck disable=SC2016
# shellcheck disable=SC2018
# shellcheck disable=SC2019
# shellcheck disable=SC2059
# shellcheck disable=SC2155
# shellcheck disable=SC3043
# shellcheck disable=SC3045
#############################################

### Start of script variables ###
readonly SCRIPT_NAME="YazDHCP"
readonly SCRIPT_VERSION="v1.0.9"
readonly SCRIPT_VERSTAG="25072023"
SCRIPT_BRANCH="master"
SCRIPT_REPO="https://raw.githubusercontent.com/AMTM-OSR/$SCRIPT_NAME/$SCRIPT_BRANCH"
readonly SCRIPT_DIR="/jffs/addons/$SCRIPT_NAME.d"
readonly SCRIPT_CONF="$SCRIPT_DIR/DHCP_clients"
readonly SCRIPT_WEBPAGE_DIR="$(readlink -f /www/user)"
readonly SCRIPT_WEB_DIR="$SCRIPT_WEBPAGE_DIR/$SCRIPT_NAME"
readonly SHARED_DIR="/jffs/addons/shared-jy"
readonly SHARED_REPO="https://raw.githubusercontent.com/AMTM-OSR/shared-jy/master"
readonly SHARED_WEB_DIR="$SCRIPT_WEBPAGE_DIR/shared-jy"
### End of script variables ###

### Start of output format variables ###
readonly CRIT="\\e[41m"
readonly ERR="\\e[31m"
readonly WARN="\\e[33m"
readonly PASS="\\e[32m"
readonly BOLD="\\e[1m"
readonly CLEARct="\\e[0m"
### End of output format variables ###

##----------------------------------------##
## Modified by Martinski W. [2024-Jun-27] ##
##----------------------------------------##

### Start of router environment variables ###
[ -z "$(nvram get odmpid)" ] && ROUTER_MODEL="$(nvram get productid)" || ROUTER_MODEL="$(nvram get odmpid)"
ROUTER_MODEL="$(echo "$ROUTER_MODEL" | tr 'a-z' 'A-Z')"

##----------------------------------------##
## Modified by Martinski W. [2025-Mar-16] ##
##----------------------------------------##
readonly fwInstalledBaseVers="$(nvram get firmver | sed 's/\.//g')"
readonly fwInstalledBuildVers="$(nvram get buildno)"
readonly fwInstalledBranchVer="${fwInstalledBaseVers}.${fwInstalledBuildVers}"
readonly scriptVersRegExp="v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})"
readonly branchx_TAG="Branch: $SCRIPT_BRANCH"
readonly version_TAG="${SCRIPT_VERSION}_${SCRIPT_VERSTAG}"

# Give higher priority to built-in binaries #
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:$PATH"

### End of router environment variables ###

##----------------------------------------------##
## Added/modified by Martinski W. [2023-May-28] ##
##----------------------------------------------##
# DHCP Lease Time: Min & Max Values in seconds.
# 2 minutes=120 to 90 days=7776000 (inclusive).
# Single '0' or 'I' indicates "infinite" value.
# For NVRAM the "infinite" value (in secs.) is
# 1092 days (i.e. 156 weeks, or ~=3 years).
#------------------------------------------------#
readonly MinDHCPLeaseTime=120
readonly MaxDHCPLeaseTime=7776000
readonly InfiniteLeaseTimeTag="I"
readonly InfiniteLeaseTimeSecs=94348800
readonly YazDHCP_LEASEtag="DHCP_LEASE"
readonly DHCP_LEASE_KEYN="dhcp_lease"
readonly DHCP_LEASE_FILE="DHCP_Lease"
readonly SCRIPT_DHCP_LEASE_CONF="${SCRIPT_DIR}/$DHCP_LEASE_FILE"

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jun-16] ##
##----------------------------------------------##
## Start of script variables for the "Save Custom User Icons" feature ##
##--------------------------------------------------------------------##
readonly theJFFSdir="/jffs"
readonly userIconsDIRname="usericon"
readonly userIconsDIRpath="${theJFFSdir}/$userIconsDIRname"
readonly userIconsSavedFLEextn="tar.gzip"
readonly userIconsSavedFLEname="CustomUserIcons"
readonly userIconsSavedDIRname="SavedUserIcons"
readonly userIconsSavedCFGname="CustomUserIconsConfig"
readonly userIconsSavedSTAname="CustomUserIconsStatus"
readonly defUserIconsBackupDir="/opt/var/$userIconsSavedDIRname"
readonly altUserIconsBackupDir="/jffs/configs/$userIconsSavedDIRname"
readonly userIconsVarPrefix="Icons_"
readonly savedFileDateTimeStr="%Y-%m-%d_%H-%M-%S"
readonly NVRAM_Folder="${theJFFSdir}/nvram"
readonly NVRAM_ClientsKeyName="custom_clientlist"
readonly NVRAM_ClientsKeyVARsaved="${userIconsDIRpath}/NVRAMvar_${NVRAM_ClientsKeyName}.TMP"
readonly NVRAM_ClientsKeyFLEsaved="${userIconsDIRpath}/NVRAMfile_${NVRAM_ClientsKeyName}.TMP"
readonly SCRIPT_USER_ICONS_STATUS="/tmp/$userIconsSavedSTAname"
readonly SCRIPT_USER_ICONS_CONFIG="${SCRIPT_DIR}/$userIconsSavedCFGname"
readonly userIconsCFGCommentLine="## DO *NOT* EDIT THIS FILE BELOW THIS LINE. IT'S DYNAMICALLY UPDATED ##"

readonly userIconsBKPListHeader="From directory:"
readonly userIconsSavedBKPList="CustomUserIconsBackupList"
readonly SCRIPT_USER_ICONS_BKPLST="/tmp/$userIconsSavedBKPList"

readonly theHighWaterMarkThreshold=5
readonly theMinUserIconsBackupFiles=5
readonly theMaxUserIconsBackupFiles=50
readonly defMaxUserIconsBackupFiles=20

readonly CLRct="\e[0m"
readonly BOLDtext="\e[1m"
readonly LghtRED="\e[1;31m"
readonly LghtGREEN="\e[1;32m"
readonly MGNTct="\e[1;35m"
readonly REDct="${LghtRED}${BOLDtext}"
readonly GRNct="${LghtGREEN}${BOLDtext}"
readonly WarnBYLWct="\e[30;103m"
readonly theExitStr="${GRNct}e${CLRct}=Exit"

readonly MaxBckupsOpt="mx"
readonly BackupDirOpt="dp"
readonly BkupIconsOpt="bk"
readonly RestIconsOpt="rt"
readonly DeltIconsOpt="de"
readonly ListIconsOpt="ls"

iconsFound=false
backupsFound=false
waitToConfirm=false
inStartupMode=false
maxUserIconsBackupFiles="$defMaxUserIconsBackupFiles"
theUserIconsBackupDir="$defUserIconsBackupDir"
prefUserIconsBackupDir="$theUserIconsBackupDir"
userIconsBackupFPath="${theUserIconsBackupDir}/$userIconsSavedFLEname"
theBackupFilesMatch="${userIconsBackupFPath}_*.$userIconsSavedFLEextn"
##------------------------------------------------------------------##
## End of script variables for the "Save Custom User Icons" feature ##
##==================================================================##

##----------------------------------------##
## Modified by Martinski W. [2025-Mar-16] ##
##----------------------------------------##
# $1 = print to syslog, $2 = message to print, $3 = log level
Print_Output()
{
	local prioStr  prioNum
	if [ $# -gt 2 ] && [ -n "$3" ]
	then prioStr="$3"
	else prioStr="NOTICE"
	fi
	if [ "$1" = "true" ]
	then
		case "$prioStr" in
		    "$CRIT") prioNum=2 ;;
		     "$ERR") prioNum=3 ;;
		    "$WARN") prioNum=4 ;;
		    "$PASS") prioNum=6 ;; #INFO#
		          *) prioNum=5 ;; #NOTICE#
		esac
		logger -t "${SCRIPT_NAME}_[$$]" -p $prioNum "$2"
	fi
	printf "${BOLD}${3}%s${CLEARct}\n\n" "$2"
}

Firmware_Version_Check()
{
	if nvram get rc_support | grep -qF "am_addons"; then
		return 0
	else
		return 1
	fi
}

### Code for this function courtesy of https://github.com/decoderman- credit to @thelonelycoder ###
Firmware_Version_Number()
{ echo "$1" | awk -F. '{ printf("%d%03d%03d%02d\n", $1,$2,$3,$4); }' ; }

############################################################################

### Code for these functions inspired by https://github.com/Adamm00 - credit to @Adamm ###
Check_Lock()
{
	if [ -f "/tmp/$SCRIPT_NAME.lock" ]
	then
		ageoflock=$(($(date +%s) - $(date +%s -r /tmp/$SCRIPT_NAME.lock)))
		if [ "$ageoflock" -gt 600 ]
		then
			Print_Output true "Stale lock file found (>600 seconds old) - purging lock" "$ERR"
			kill "$(sed -n '1p' /tmp/$SCRIPT_NAME.lock)" >/dev/null 2>&1
			Clear_Lock
			echo "$$" > "/tmp/$SCRIPT_NAME.lock"
			return 0
		else
			Print_Output true "Lock file found (age: $ageoflock seconds) - stopping to prevent duplicate runs" "$ERR"
			if [ -z "$1" ]; then
				exit 1
			else
				if [ "$1" = "webui" ]; then
					exit 1
				fi
				return 1
			fi
		fi
	else
		echo "$$" > "/tmp/$SCRIPT_NAME.lock"
		return 0
	fi
}

Clear_Lock(){
	rm -f "/tmp/$SCRIPT_NAME.lock" 2>/dev/null
	return 0
}
############################################################################

Validate_IP()
{
	if expr "$1" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null
	then
		for i in 1 2 3 4
		do
			if [ "$(echo "$1" | cut -d. -f$i)" -gt 255 ]; then
				Print_Output false "Octet $i ($(echo "$1" | cut -d. -f$i)) - is invalid, must be less than 255" "$ERR"
				return 1
			fi
		done
	else
		Print_Output false "$1 - is not a valid IPv4 address, valid format is 1.2.3.4" "$ERR"
		return 1
	fi
}

##----------------------------------------------##
## Added/modified by Martinski W. [2023-Jan-30] ##
##----------------------------------------------##
# The DHCP Lease Time values can be given in:
# seconds, minutes, hours, days, or weeks.
# Single '0' or 'I' indicates "infinite" value.
#------------------------------------------------#
DHCP_LeaseValueToSeconds()
{
   if [ $# -eq 0 ] || [ -z "$1" ]
   then echo "-1" ; return 1 ; fi

   timeUnits="X"  timeFactor=1  timeNumber="$1"

   if [ "$1" = "0" ] || [ "$1" = "$InfiniteLeaseTimeTag" ]
   then echo "$InfiniteLeaseTimeSecs" ; return 0 ; fi

   if echo "$1" | grep -q "^0.*"
   then echo "-1" ; return 1 ; fi

   if echo "$1" | grep -q "^[0-9]\{1,7\}$"
   then
		timeUnits="s"
		timeNumber="$1"
   elif echo "$1" | grep -q "^[0-9]\{1,6\}[smhdw]\{1\}$"
   then
		timeUnits="$(echo "$1" | awk '{print substr($0,length($0),1)}')"
		timeNumber="$(echo "$1" | awk '{print substr($0,0,length($0)-1)}')"
   fi

   case "$timeUnits" in
		s) timeFactor=1 ;;
		m) timeFactor=60 ;;
		h) timeFactor=3600 ;;
		d) timeFactor=86400 ;;
		w) timeFactor=604800 ;;
   esac

   if ! echo "$timeNumber" | grep -q "^[0-9]\{1,7\}$"
   then echo "-1" ; return 1 ; fi

   timeValue="$((timeNumber * timeFactor))"
   echo "$timeValue"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-May-28] ##
##----------------------------------------------##
Check_DHCP_LeaseTime()
{
   NVRAM_LeaseTime="$(nvram get $DHCP_LEASE_KEYN)"

   if [ ! -f "$SCRIPT_DHCP_LEASE_CONF" ]
   then
      echo "## DO *NOT* EDIT THIS FILE. IT'S DYNAMICALLY UPDATED ##" > "$SCRIPT_DHCP_LEASE_CONF"
      echo "DHCP_LEASE=$NVRAM_LeaseTime" >> "$SCRIPT_DHCP_LEASE_CONF"
      return 1
   fi

   if ! grep -q "^DHCP_LEASE=" "$SCRIPT_DHCP_LEASE_CONF"
   then
      echo "DHCP_LEASE=$NVRAM_LeaseTime" >> "$SCRIPT_DHCP_LEASE_CONF"
      return 1
   fi

   LeaseValue="$(grep "^DHCP_LEASE=" "$SCRIPT_DHCP_LEASE_CONF" | awk -F '=' '{print $2}')"
   if [ -z "$LeaseValue" ]
   then
      sed -i "s/DHCP_LEASE=.*/DHCP_LEASE=$NVRAM_LeaseTime/" "$SCRIPT_DHCP_LEASE_CONF"
      return 1
   fi

   LeaseTime="$(DHCP_LeaseValueToSeconds "$LeaseValue")"

   if [ "$LeaseTime" = "$InfiniteLeaseTimeSecs" ] && \
      [ "$LeaseTime" != "$NVRAM_LeaseTime" ]
   then
      nvram set ${DHCP_LEASE_KEYN}="$LeaseTime"
      DO_NVRAM_COMMIT=true
      RESTART_DNSMASQ=true
      return 0
   fi

   if [ "$LeaseTime" = "-1" ] || \
      [ "$LeaseTime" -lt "$MinDHCPLeaseTime" ] || \
      [ "$LeaseTime" -gt "$MaxDHCPLeaseTime" ] || \
      [ "$LeaseTime" -eq "$NVRAM_LeaseTime" ]
   then return 1 ; fi

   nvram set ${DHCP_LEASE_KEYN}="$LeaseTime"
   DO_NVRAM_COMMIT=true
   RESTART_DNSMASQ=true
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2023-Apr-01] ##
##-------------------------------------##
GetFromCustomUserIconsConfig()
{
   keyName="${userIconsVarPrefix}$1"
   if [ $# -eq 0 ] || [ -z "$1" ] || \
      [ ! -f "$SCRIPT_USER_ICONS_CONFIG" ] || \
      ! grep -q "^${keyName}=" "$SCRIPT_USER_ICONS_CONFIG"
   then echo "" ; return 1 ; fi

   keyValue="$(grep "^${keyName}=" "$SCRIPT_USER_ICONS_CONFIG" | awk -F '=' '{print $2}')"
   echo "$keyValue" ; return 0
}

FixCustomUserIconsConfig()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] ; then return 1; fi

   keyName="${userIconsVarPrefix}$1"
   if ! grep -q "^${keyName}=" "$SCRIPT_USER_ICONS_CONFIG"
   then
       echo "${keyName}=$2" >> "$SCRIPT_USER_ICONS_CONFIG"
       return 0
   fi

   keyValue="$(grep "^${keyName}=" "$SCRIPT_USER_ICONS_CONFIG" | awk -F '=' '{print $2}')"
   if [ -z "$keyValue" ]
   then
       fixedVal="$(echo "$2" | sed 's/[\/.*-]/\\&/g')"
       sed -i "s/${keyName}=.*/${keyName}=${fixedVal}/" "$SCRIPT_USER_ICONS_CONFIG"
   fi
}

ClearCustomUserIconsStatus()
{ rm -f "$SCRIPT_USER_ICONS_STATUS" ; }

UpdateCustomUserIconsStatus()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] ; then return 1; fi

   if [ "$2" = "NONE" ] || [ ! -f "$2" ]
   then
       echo "${userIconsVarPrefix}${1}=NONE" > "$SCRIPT_USER_ICONS_STATUS"
   else
       echo "${userIconsVarPrefix}DIRP=${2%/*}"   > "$SCRIPT_USER_ICONS_STATUS"
       echo "${userIconsVarPrefix}FILE=${2##*/}" >> "$SCRIPT_USER_ICONS_STATUS"
       echo "${userIconsVarPrefix}${1}=OK"       >> "$SCRIPT_USER_ICONS_STATUS"
   fi
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jun-14] ##
##----------------------------------------------##
UpdateCustomUserIconsConfig()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] ; then return 1; fi

   if [ "$1" = "SAVED_DIR" ]
   then
       theUserIconsBackupDir="$2"
       userIconsBackupFPath="${2}/$userIconsSavedFLEname"
       theBackupFilesMatch="${userIconsBackupFPath}_*.$userIconsSavedFLEextn"
   fi
   if [ "$1" = "PREFS_DIR" ]
   then prefUserIconsBackupDir="$2"
   fi

   if [ $# -eq 3 ] && [ "$3" = "STATUSupdate" ] && \
      { [ "$1" = "SAVED" ] || [ "$1" = "RESTD" ] ; } && \
      { [ "$2" = "NONE" ] || [ -f "$2" ] ; }
   then UpdateCustomUserIconsStatus "$1" "$2" ; fi

   keyName="${userIconsVarPrefix}$1"
   if ! grep -q "^${keyName}=" "$SCRIPT_USER_ICONS_CONFIG"
   then
       echo "${keyName}=$2" >> "$SCRIPT_USER_ICONS_CONFIG"
       return 0
   fi

   keyValue="$(grep "^${keyName}=" "$SCRIPT_USER_ICONS_CONFIG" | awk -F '=' '{print $2}')"
   if [ -z "$keyValue" ] || [ "$keyValue" != "$2" ]
   then
       fixedVal="$(echo "$2" | sed 's/[\/.*-]/\\&/g')"
       sed -i "s/${keyName}=.*/${keyName}=${fixedVal}/" "$SCRIPT_USER_ICONS_CONFIG"
   fi
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jun-14] ##
##----------------------------------------------##
InitCustomUserIconsConfig()
{
   thePrefix="$userIconsVarPrefix"
   if [ ! -f "$SCRIPT_USER_ICONS_CONFIG" ]
   then
       {
        echo "$userIconsCFGCommentLine"
        echo "${thePrefix}SAVED_MAX=20"
        echo "${thePrefix}SAVED_DIR=NONE"
        echo "${thePrefix}PREFS_DIR=NONE"
        echo "${thePrefix}FOUND=FALSE"
        echo "${thePrefix}SAVED=NONE"
        echo "${thePrefix}RESTD=NONE"
       } > "$SCRIPT_USER_ICONS_CONFIG"
       return 0
   fi

   commentStr="$(echo "$userIconsCFGCommentLine" | sed 's/[.*-]/\\&/g')"
   nFoundStr="$(grep -n "^${commentStr}" "$SCRIPT_USER_ICONS_CONFIG")"
   if [ -z "$nFoundStr" ] || \
      [ "$(echo "$nFoundStr" | awk -F ':' '{print $1}')" -ne 1 ]
   then
       sed -i "\\~${commentStr}~d" "$SCRIPT_USER_ICONS_CONFIG"
       sed -i "1 i ${userIconsCFGCommentLine}" "$SCRIPT_USER_ICONS_CONFIG"
   fi
   if ! grep -q "^${thePrefix}SAVED_DIR=" "$SCRIPT_USER_ICONS_CONFIG"
   then sed -i "2 i ${thePrefix}SAVED_DIR=NONE" "$SCRIPT_USER_ICONS_CONFIG"
   fi
   if ! grep -q "^${thePrefix}SAVED_MAX=" "$SCRIPT_USER_ICONS_CONFIG"
   then sed -i "2 i ${thePrefix}SAVED_MAX=20" "$SCRIPT_USER_ICONS_CONFIG"
   fi
   if ! grep -q "^${thePrefix}PREFS_DIR=" "$SCRIPT_USER_ICONS_CONFIG"
   then sed -i "4 i ${thePrefix}PREFS_DIR=NONE" "$SCRIPT_USER_ICONS_CONFIG"
   fi
   return 1
}

##-------------------------------------##
## Added by Martinski W. [2024-Jan-08] ##
##-------------------------------------##
_GetDefaultUSBMountPoint_()
{
   local mountPointPath  retCode=0
   local mountPointRegExp="^/dev/sd.* /tmp/mnt/.*"

   mountPointPath="$(grep -m1 "$mountPointRegExp" /proc/mounts | awk -F ' ' '{print $2}')"
   [ -z "$mountPointPath" ] && retCode=1
   echo "$mountPointPath" ; return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jan-08] ##
##----------------------------------------##
ValidateUserIconsBackupDirectory()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1; fi

   [ ! -d "$theUserIconsBackupDir" ] && \
   mkdir -m 755 "$theUserIconsBackupDir" 2>/dev/null
   [ -d "$theUserIconsBackupDir" ] && return 0

   local LogTag
   if [ -z "$defaultUSBMountPoint" ] && \
      echo "$theUserIconsBackupDir" | grep -qE "^(/tmp/mnt/|/tmp/opt/|/mnt/|/opt/)"
   then LogTag="**INFO**: "
   else LogTag="**ERROR**: "
   fi

   Print_Output true "$LogTag Backup directory [$theUserIconsBackupDir] NOT FOUND." "$ERR"
   Print_Output true "Trying again with directory [$1]" "$PASS"
   theUserIconsBackupDir="$1"
   switchBackupDir=true
   return 1
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2024-Jan-08] ##
##----------------------------------------------##
GetUserIconsSavedVars()
{
   switchBackupDir=false
   defaultUSBMountPoint="$(_GetDefaultUSBMountPoint_)"
   savdUserIconsBackupDir="$(GetFromCustomUserIconsConfig "SAVED_DIR")"
   prefUserIconsBackupDir="$(GetFromCustomUserIconsConfig "PREFS_DIR")"

   if [ -z "$savdUserIconsBackupDir" ] || [ "$savdUserIconsBackupDir" = "NONE" ]
   then savdUserIconsBackupDir="$defUserIconsBackupDir" ; fi

   if [ -z "$prefUserIconsBackupDir" ] || [ "$prefUserIconsBackupDir" = "NONE" ]
   then
       prefUserIconsBackupDir="$savdUserIconsBackupDir"
       UpdateCustomUserIconsConfig PREFS_DIR "$prefUserIconsBackupDir"
   fi

   theUserIconsBackupDir="$prefUserIconsBackupDir"
   for nextBKdir in "$savdUserIconsBackupDir" "$defUserIconsBackupDir" "$altUserIconsBackupDir"
   do ValidateUserIconsBackupDirectory "$nextBKdir" && break ; done

   mkdir -m 755 "$theUserIconsBackupDir" 2>/dev/null
   if [ ! -d "$theUserIconsBackupDir" ]
   then
       Print_Output true "**ERROR**: Backup directory [$theUserIconsBackupDir] NOT FOUND." "$ERR"
       return 1
   fi

   if "$switchBackupDir"
   then
       if "$inStartupMode"
       then LogMsg="*WARNING*: Temporary Backup directory [$theUserIconsBackupDir]"
       else LogMsg="*WARNING*: Alternative Backup directory [$theUserIconsBackupDir]"
       fi
       Print_Output true "$LogMsg" "$WARN"
       _WaitForEnterKey_
   fi
   ! "$inStartupMode" && UpdateCustomUserIconsConfig SAVED_DIR "$theUserIconsBackupDir"

   maxUserIconsBackupFiles="$(GetFromCustomUserIconsConfig "SAVED_MAX")"
   if [ -z "$maxUserIconsBackupFiles" ] || \
      ! echo "$maxUserIconsBackupFiles" | grep -qE "^[0-9]{1,}$"
   then maxUserIconsBackupFiles="$defMaxUserIconsBackupFiles" ; fi

   if [ "$maxUserIconsBackupFiles" -lt "$theMinUserIconsBackupFiles" ]
   then maxUserIconsBackupFiles="$theMinUserIconsBackupFiles" ; fi

   if [ "$maxUserIconsBackupFiles" -gt "$theMaxUserIconsBackupFiles" ]
   then maxUserIconsBackupFiles="$theMaxUserIconsBackupFiles" ; fi

   UpdateCustomUserIconsConfig SAVED_MAX "$maxUserIconsBackupFiles"
   return 0
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jun-14] ##
##----------------------------------------------##
Check_CustomUserIconsConfig()
{
   if ! InitCustomUserIconsConfig
   then
       FixCustomUserIconsConfig FOUND FALSE
       FixCustomUserIconsConfig SAVED NONE
       FixCustomUserIconsConfig RESTD NONE
       FixCustomUserIconsConfig SAVED_MAX "$defMaxUserIconsBackupFiles"
       FixCustomUserIconsConfig SAVED_DIR "$defUserIconsBackupDir"
       FixCustomUserIconsConfig PREFS_DIR "$defUserIconsBackupDir"
   fi
   GetUserIconsSavedVars
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-26] ##
##----------------------------------------##
Conf_FromSettings()
{
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	TMPFILE="/tmp/yazdhcp_clients.tmp"
	if [ -f "$SETTINGSFILE" ]
	then
		if [ "$(grep -E "yazdhcp_|^$YazDHCP_LEASEtag" $SETTINGSFILE | grep -v "version" -c)" -gt 0 ]
		then
			Print_Output true "Updated DHCP information from WebUI found, merging into $SCRIPT_CONF" "$PASS"
			cp -a "$SCRIPT_CONF" "$SCRIPT_CONF.bak"
			grep -E "yazdhcp_|^$YazDHCP_LEASEtag" "$SETTINGSFILE" | grep -v "version" > "$TMPFILE"
			sed -i "s/yazdhcp_//g;s/ /=/g" "$TMPFILE"
			DHCPCLIENTS=""
			while IFS='' read -r line || [ -n "$line" ]
			do
				if echo "$line" | grep -q "^${YazDHCP_LEASEtag}="
				then
					LEASE_VALUE="$(echo "$line" | cut -d '=' -f2)"
					sed -i "s/DHCP_LEASE=.*/DHCP_LEASE=$LEASE_VALUE/" "$SCRIPT_DHCP_LEASE_CONF"
					continue
				fi
				DHCPCLIENTS="${DHCPCLIENTS}$(echo "$line" | cut -f2 -d'=')"
			done < "$TMPFILE"

			echo "$DHCPCLIENTS" | sed 's/|/:/g;s/></\n/g;s/>/ /g;s/<//g' > /tmp/yazdhcp_clients_parsed.tmp

			RESTART_DNSMASQ=false
			DO_NVRAM_COMMIT=false
			echo "MAC,IP,HOSTNAME,DNS" > "$SCRIPT_CONF"

			while IFS='' read -r line || [ -n "$line" ]
			do
				if ! CheckAgainstNVRAMvar "$line" ; then DO_NVRAM_COMMIT=true ; fi
				if [ "$(echo "$line" | wc -w)" -eq 4 ]; then
					echo "$line" | awk '{ print ""$1","$2","$3","$4""; }' >> "$SCRIPT_CONF"
				elif [ "$(echo "$line" | wc -w)" -gt 1 ]; then
					if [ "$(echo "$line" | cut -d " " -f3 | wc -L)" -eq 0 ]; then
						echo "$line" | awk '{ print ""$1","$2","","$3""; }' >> "$SCRIPT_CONF"
					else
						printf "%s,\\n" "$(echo "$line" | sed 's/ /,/g')" >> "$SCRIPT_CONF"
					fi
				fi
			done < /tmp/yazdhcp_clients_parsed.tmp

			LANSUBNET="$(nvram get lan_ipaddr | cut -d'.' -f1-3)"
			LANNETMASK="$(nvram get lan_netmask)"
			if [ "$LANNETMASK" = "255.255.255.0" ]; then
				awk -F "," -v lansub="$LANSUBNET" 'FNR==1{print $0; next} BEGIN {OFS = ","} $2=lansub"."$2' "$SCRIPT_CONF" > "$SCRIPT_CONF.tmp"
			else
				cp "$SCRIPT_CONF" "$SCRIPT_CONF.tmp"
			fi
			sort -t . -k 3,3n -k 4,4n "$SCRIPT_CONF.tmp" > "$SCRIPT_CONF"
			rm -f "$SCRIPT_CONF.tmp"

			grep 'yazdhcp_version' "$SETTINGSFILE" > "$TMPFILE"
			sed -i "\\~yazdhcp_~d" "$SETTINGSFILE"
			sed -i "\\~${YazDHCP_LEASEtag}~d" "$SETTINGSFILE"
			mv "$SETTINGSFILE" "$SETTINGSFILE.bak"
			cat "$SETTINGSFILE.bak" "$TMPFILE" > "$SETTINGSFILE"
			rm -f /tmp/yazdhcp*
			rm -f "$SETTINGSFILE.bak"

			ProcessDHCPClients "$DO_NVRAM_COMMIT"
			Check_DHCP_LeaseTime
			if "$DO_NVRAM_COMMIT" ; then nvram commit ; fi

			Print_Output true "Merge of updated DHCP client information from WebUI completed successfully" "$PASS"

			if "$RESTART_DNSMASQ"
			then
				Print_Output true "Restarting dnsmasq for new DHCP settings to take effect." "$PASS"
				## Delay restarting dnsmasq until the one from WebGUI is completed ##
				(sleep 2 ; service restart_dnsmasq >/dev/null 2>&1) &
			fi
		else
			Print_Output false "No updated DHCP information from WebUI found, no merge into $SCRIPT_CONF necessary" "$PASS"
		fi
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Mar-17] ##
##----------------------------------------##
Set_Version_Custom_Settings()
{
	SETTINGSFILE="/jffs/addons/custom_settings.txt"
	case "$1" in
		local)
			if [ -f "$SETTINGSFILE" ]
			then
				if [ "$(grep -c "^yazdhcp_version_local" "$SETTINGSFILE")" -gt 0 ]
				then
					if [ "$SCRIPT_VERSION" != "$(grep "^yazdhcp_version_local" "$SETTINGSFILE" | cut -f2 -d' ')" ]
					then
						sed -i "s/^yazdhcp_version_local.*/yazdhcp_version_local $SCRIPT_VERSION/" "$SETTINGSFILE"
					fi
				else
					echo "yazdhcp_version_local $SCRIPT_VERSION" >> "$SETTINGSFILE"
				fi
			else
				echo "yazdhcp_version_local $SCRIPT_VERSION" >> "$SETTINGSFILE"
			fi
		;;
		server)
			if [ -f "$SETTINGSFILE" ]
			then
				if [ "$(grep -c "^yazdhcp_version_server" "$SETTINGSFILE")" -gt 0 ]
				then
					if [ "$2" != "$(grep "^yazdhcp_version_server" "$SETTINGSFILE" | cut -f2 -d' ')" ]
					then
						sed -i "s/^yazdhcp_version_server.*/yazdhcp_version_server $2/" "$SETTINGSFILE"
					fi
				else
					echo "yazdhcp_version_server $2" >> "$SETTINGSFILE"
				fi
			else
				echo "yazdhcp_version_server $2" >> "$SETTINGSFILE"
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Mar-16] ##
##----------------------------------------##
Update_Check()
{
	echo 'var updatestatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_update.js"
	doupdate="false"
	localver="$(grep "SCRIPT_VERSION=" /jffs/scripts/"$SCRIPT_NAME" | grep -m1 -oE "$scriptVersRegExp")"
	curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep -qF "jackyaz" || \
	{ Print_Output true "404 error detected - stopping update" "$ERR"; return 1; }
	serverver="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE "$scriptVersRegExp")"
	if [ "$localver" != "$serverver" ]
	then
		doupdate="version"
		Set_Version_Custom_Settings server "$serverver"
		echo 'var updatestatus = "'"$serverver"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	else
		localmd5="$(md5sum "/jffs/scripts/$SCRIPT_NAME" | awk '{print $1}')"
		remotemd5="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | md5sum | awk '{print $1}')"
		if [ "$localmd5" != "$remotemd5" ]
		then
			doupdate="md5"
			Set_Version_Custom_Settings server "$serverver-hotfix"
			echo 'var updatestatus = "'"$serverver-hotfix"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
		fi
	fi
	if [ "$doupdate" = "false" ]; then
		echo 'var updatestatus = "None";' > "$SCRIPT_WEB_DIR/detect_update.js"
	fi
	echo "$doupdate,$localver,$serverver"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Mar-16] ##
##----------------------------------------##
Update_Version()
{
	if [ $# -eq 0 ] || [ -z "$1" ] || [ "$1" = "unattended" ]
	then
		updatecheckresult="$(Update_Check)"
		isupdate="$(echo "$updatecheckresult" | cut -f1 -d',')"
		localver="$(echo "$updatecheckresult" | cut -f2 -d',')"
		serverver="$(echo "$updatecheckresult" | cut -f3 -d',')"

		if [ "$isupdate" = "version" ]; then
			Print_Output true "New version of $SCRIPT_NAME available - updating to $serverver" "$PASS"
		elif [ "$isupdate" = "md5" ]; then
			Print_Output true "MD5 hash of $SCRIPT_NAME does not match - downloading updated $serverver" "$PASS"
		fi

		Update_File shared-jy.tar.gz

		if [ "$isupdate" != "false" ]
		then
			Update_File Advanced_DHCP_Content.asp

			Download_File "$SCRIPT_REPO/$SCRIPT_NAME.sh" "/jffs/scripts/$SCRIPT_NAME" && \
			Print_Output true "$SCRIPT_NAME successfully updated" "$PASS"
			chmod 0755 /jffs/scripts/"$SCRIPT_NAME"
			Clear_Lock
			if [ -z "$1" ]
			then
				exec "$0" setversion
			elif [ "$1" = "unattended" ]
			then
				exec "$0" setversion unattended
			fi
			exit 0
		else
			Print_Output true "No new version - latest is $localver" "$WARN"
			Clear_Lock
		fi
	fi

	if [ $# -gt 0 ] && [ "$1" = "force" ]
	then
		serverver="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE "$scriptVersRegExp")"
		Print_Output true "Downloading latest version ($serverver) of $SCRIPT_NAME" "$PASS"
		Update_File Advanced_DHCP_Content.asp
		Update_File shared-jy.tar.gz
		Download_File "$SCRIPT_REPO/$SCRIPT_NAME.sh" "/jffs/scripts/$SCRIPT_NAME" && \
		Print_Output true "$SCRIPT_NAME successfully updated" "$PASS"
		chmod 0755 /jffs/scripts/"$SCRIPT_NAME"
		Clear_Lock
		if [ $# -lt 2 ] || [ -z "$2" ]
		then
			exec "$0" setversion
		elif [ "$2" = "unattended" ]
		then
			exec "$0" setversion unattended
		fi
		exit 0
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Mar-16] ##
##----------------------------------------##
Update_File()
{
	if [ "$1" = "Advanced_DHCP_Content.asp" ]
	then
		tmpfile="/tmp/$1"
		if [ -f "$SCRIPT_DIR/$1" ]
		then
			Download_File "$SCRIPT_REPO/$1" "$tmpfile"
			if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1
			then
				Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
				Print_Output true "New version of $1 downloaded" "$PASS"
				Mount_WebUI
			fi
			rm -f "$tmpfile"
		else
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
			Mount_WebUI
		fi
	elif [ "$1" = "shared-jy.tar.gz" ]
	then
		if [ ! -f "$SHARED_DIR/$1.md5" ]
		then
			Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
			Download_File "$SHARED_REPO/$1.md5" "$SHARED_DIR/$1.md5"
			tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
			rm -f "$SHARED_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
		else
			localmd5="$(cat "$SHARED_DIR/$1.md5")"
			remotemd5="$(curl -fsL --retry 4 --retry-delay 5 "$SHARED_REPO/$1.md5")"
			if [ "$localmd5" != "$remotemd5" ]
			then
				Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
				Download_File "$SHARED_REPO/$1.md5" "$SHARED_DIR/$1.md5"
				tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
				rm -f "$SHARED_DIR/$1"
				Print_Output true "New version of $1 downloaded" "$PASS"
			fi
		fi
	else
		return 1
	fi
}

Create_Dirs()
{
	if [ ! -d "$SCRIPT_DIR" ]; then
		mkdir -p "$SCRIPT_DIR"
	fi

	if [ ! -d "$SHARED_DIR" ]; then
		mkdir -p "$SHARED_DIR"
	fi

	if [ ! -d "$SCRIPT_WEBPAGE_DIR" ]; then
		mkdir -p "$SCRIPT_WEBPAGE_DIR"
	fi

	if [ ! -d "$SCRIPT_WEB_DIR" ]; then
		mkdir -p "$SCRIPT_WEB_DIR"
	fi
}

##----------------------------------------------##
## Added/modified by Martinski W. [2023-May-28] ##
##----------------------------------------------##
Create_DHCP_LeaseConfig()
{
   Check_DHCP_LeaseTime && nvram commit
   ln -sf "$SCRIPT_DHCP_LEASE_CONF" "${SCRIPT_WEB_DIR}/${DHCP_LEASE_FILE}.htm" 2>/dev/null
}

##----------------------------------------------##
## Added/modified by Martinski W. [2023-Apr-16] ##
##----------------------------------------------##
Create_CustomUserIconsConfig()
{
   Check_CustomUserIconsConfig
   ln -sf "$SCRIPT_USER_ICONS_CONFIG" "${SCRIPT_WEB_DIR}/${userIconsSavedCFGname}.htm" 2>/dev/null
   ln -sf "$SCRIPT_USER_ICONS_STATUS" "${SCRIPT_WEB_DIR}/${userIconsSavedSTAname}.htm" 2>/dev/null
   ln -sf "$SCRIPT_USER_ICONS_BKPLST" "${SCRIPT_WEB_DIR}/${userIconsSavedBKPList}.htm" 2>/dev/null
}

##----------------------------------------##
## Modified by Martinski W. [2023-Apr-01] ##
##----------------------------------------##
Create_Symlinks()
{
	rm -rf "${SCRIPT_WEB_DIR:?}/"* 2>/dev/null

	ln -s "$SCRIPT_CONF" "$SCRIPT_WEB_DIR/DHCP_clients.htm" 2>/dev/null
	Create_DHCP_LeaseConfig
	Create_CustomUserIconsConfig

	if [ ! -d "$SHARED_WEB_DIR" ]; then
		ln -s "$SHARED_DIR" "$SHARED_WEB_DIR" 2>/dev/null
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Mar-14] ##
##----------------------------------------##
Auto_ServiceEvent()
{
	case $1 in
		create)
			if [ -f /jffs/scripts/service-event ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)
				STARTUPLINECOUNTEX=$(grep -cx 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'" ; then { /jffs/scripts/'"$SCRIPT_NAME"' service_event "$@" & }; fi # '"$SCRIPT_NAME" /jffs/scripts/service-event)

				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi

				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'" ; then { /jffs/scripts/'"$SCRIPT_NAME"' service_event "$@" & }; fi # '"$SCRIPT_NAME" >> /jffs/scripts/service-event
				fi
			else
				echo "#!/bin/sh" > /jffs/scripts/service-event
				echo "" >> /jffs/scripts/service-event
				echo 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'" ; then { /jffs/scripts/'"$SCRIPT_NAME"' service_event "$@" & }; fi # '"$SCRIPT_NAME" >> /jffs/scripts/service-event
				chmod 0755 /jffs/scripts/service-event
			fi
		;;
		delete)
			if [ -f /jffs/scripts/service-event ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)

				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
			fi
		;;
	esac
}

Auto_Startup()
{
	case $1 in
		create)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)
				STARTUPLINECOUNTEX=$(grep -cx "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME" /jffs/scripts/services-start)

				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi

				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
				fi
			else
				echo "#!/bin/sh" > /jffs/scripts/services-start
				echo "" >> /jffs/scripts/services-start
				echo "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
				chmod 0755 /jffs/scripts/services-start
			fi
		;;
		delete)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)

				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-26] ##
##----------------------------------------##
Auto_DNSMASQ()
{
	if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

	if [ $# -gt 1 ] && [ "$2" = "false" ]
	then doRESTART=false
	else doRESTART=true
	fi

	case $1 in
		create)
			entryDeleted=0
			CONFCHANGED="false"
			ADDN_HOSTSFILE="addn-hosts=$SCRIPT_DIR/.hostnames # ${SCRIPT_NAME}_hostnames"
			DHCP_HOSTSFILE="dhcp-hostsfile=$SCRIPT_DIR/.staticlist # ${SCRIPT_NAME}_staticlist"
			DHCP_OPTS_FILE="dhcp-optsfile=$SCRIPT_DIR/.optionslist # ${SCRIPT_NAME}_optionslist"

			if [ -f /jffs/configs/dnsmasq.conf.add ]
			then
				STARTUPLINECOUNT="$(grep -c "# ${SCRIPT_NAME}_hostnames" /jffs/configs/dnsmasq.conf.add)"
				STARTUPLINECOUNTEX="$(grep -cx "$ADDN_HOSTSFILE" /jffs/configs/dnsmasq.conf.add)"

				if [ "$STARTUPLINECOUNT" -gt 1 ] || \
				   { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; } || \
				   { [ ! -s "$SCRIPT_DIR/.hostnames" ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; }
				then
					sed -i -e '/# '"${SCRIPT_NAME}_hostnames"'/d' /jffs/configs/dnsmasq.conf.add
					entryDeleted="$((entryDeleted | 0x01))"
				fi

				STARTUPLINECOUNTEX="$(grep -cx "$ADDN_HOSTSFILE" /jffs/configs/dnsmasq.conf.add)"
				if [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ -s "$SCRIPT_DIR/.hostnames" ]
				then
					echo "$ADDN_HOSTSFILE" >> /jffs/configs/dnsmasq.conf.add
					CONFCHANGED="true"
					entryDeleted="$((entryDeleted & (~0x01)))"
				fi

				STARTUPLINECOUNT="$(grep -c "# ${SCRIPT_NAME}_staticlist" /jffs/configs/dnsmasq.conf.add)"
				STARTUPLINECOUNTEX="$(grep -cx "$DHCP_HOSTSFILE" /jffs/configs/dnsmasq.conf.add)"

				if [ "$STARTUPLINECOUNT" -gt 1 ] || \
				   { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; } || \
				   { [ ! -s "$SCRIPT_DIR/.staticlist" ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; }
				then
					sed -i -e '/# '"${SCRIPT_NAME}_staticlist"'/d' /jffs/configs/dnsmasq.conf.add
					entryDeleted="$((entryDeleted | 0x02))"
				fi

				STARTUPLINECOUNTEX="$(grep -cx "$DHCP_HOSTSFILE" /jffs/configs/dnsmasq.conf.add)"
				if [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ -s "$SCRIPT_DIR/.staticlist" ]
				then
					echo "$DHCP_HOSTSFILE" >> /jffs/configs/dnsmasq.conf.add
					CONFCHANGED="true"
					entryDeleted="$((entryDeleted & (~0x02)))"
				fi

				STARTUPLINECOUNT="$(grep -c "# ${SCRIPT_NAME}_optionslist" /jffs/configs/dnsmasq.conf.add)"
				STARTUPLINECOUNTEX="$(grep -cx "$DHCP_OPTS_FILE" /jffs/configs/dnsmasq.conf.add)"

				if [ "$STARTUPLINECOUNT" -gt 1 ] || \
				   { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; } || \
				   { [ ! -s "$SCRIPT_DIR/.optionslist" ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; }
				then
					sed -i -e '/# '"${SCRIPT_NAME}_optionslist"'/d' /jffs/configs/dnsmasq.conf.add
					entryDeleted="$((entryDeleted | 0x04))"
				fi

				STARTUPLINECOUNTEX="$(grep -cx "$DHCP_OPTS_FILE" /jffs/configs/dnsmasq.conf.add)"
				if [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ -s "$SCRIPT_DIR/.optionslist" ]
				then
					echo "$DHCP_OPTS_FILE" >> /jffs/configs/dnsmasq.conf.add
					CONFCHANGED="true"
					entryDeleted="$((entryDeleted & (~0x04)))"
				fi
				[ "$((entryDeleted & 0x07))" -gt 0 ] && CONFCHANGED="true"
			else
				{
				  echo ""
				  [ -s "$SCRIPT_DIR/.hostnames" ] && echo "$ADDN_HOSTSFILE"
				  [ -s "$SCRIPT_DIR/.staticlist" ] && echo "$DHCP_HOSTSFILE"
				  [ -s "$SCRIPT_DIR/.optionslist" ] && echo "$DHCP_OPTS_FILE"
				} >> /jffs/configs/dnsmasq.conf.add
				chmod 0644 /jffs/configs/dnsmasq.conf.add
				CONFCHANGED="true"
			fi
			"$CONFCHANGED" && "$doRESTART" && service restart_dnsmasq >/dev/null 2>&1
		;;
		delete)
			if [ -f /jffs/configs/dnsmasq.conf.add ]; then
				CONFCHANGED="false"
				STARTUPLINECOUNT=$(grep -c "# ${SCRIPT_NAME}_hostnames" /jffs/configs/dnsmasq.conf.add)

				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"${SCRIPT_NAME}_hostnames"'/d' /jffs/configs/dnsmasq.conf.add
					CONFCHANGED="true"
				fi

				STARTUPLINECOUNT=$(grep -c "# ${SCRIPT_NAME}_staticlist" /jffs/configs/dnsmasq.conf.add)

				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"${SCRIPT_NAME}_staticlist"'/d' /jffs/configs/dnsmasq.conf.add
					CONFCHANGED="true"
				fi

				STARTUPLINECOUNT=$(grep -c "# ${SCRIPT_NAME}_optionslist" /jffs/configs/dnsmasq.conf.add)

				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"${SCRIPT_NAME}_optionslist"'/d' /jffs/configs/dnsmasq.conf.add
					CONFCHANGED="true"
				fi

				if [ "$CONFCHANGED" = "true" ]; then
					service restart_dnsmasq >/dev/null 2>&1
				fi
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Mar-16] ##
##----------------------------------------##
Download_File()
{ /usr/sbin/curl -LSs --retry 4 --retry-delay 5 --retry-connrefused "$1" -o "$2" ; }

##----------------------------------------##
## Modified by Martinski W. [2025-Mar-17] ##
##----------------------------------------##
Mount_WebUI()
{
	Print_Output true "Mounting WebUI tab for $SCRIPT_NAME" "$PASS"
	umount /www/Advanced_DHCP_Content.asp 2>/dev/null
	mount -o bind "$SCRIPT_DIR/Advanced_DHCP_Content.asp" /www/Advanced_DHCP_Content.asp
    Print_Output true "WebUI tab for $SCRIPT_NAME was mounted." "$PASS"
}

##-------------------------------------##
## Added by Martinski W. [2025-Mar-17] ##
##-------------------------------------##
_CheckFor_WebGUI_Page_()
{
   if [ "$(grep -c 'YazDHCP' /www/Advanced_DHCP_Content.asp)" -lt 10 ]
   then Mount_WebUI ; fi
}

Shortcut_Script()
{
	case $1 in
		create)
			if [ -d /opt/bin ] && [ ! -f "/opt/bin/$SCRIPT_NAME" ] && [ -f "/jffs/scripts/$SCRIPT_NAME" ]; then
				ln -s /jffs/scripts/"$SCRIPT_NAME" /opt/bin
				chmod 0755 /opt/bin/"$SCRIPT_NAME"
			fi
		;;
		delete)
			if [ -f "/opt/bin/$SCRIPT_NAME" ]; then
				rm -f /opt/bin/"$SCRIPT_NAME"
			fi
		;;
	esac
}

PressEnter()
{
	while true
	do
		printf "Press <Enter> key to continue..."
		read -rs key
		case "$key" in
			*) break ;;
		esac
	done
	return 0
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-16] ##
##----------------------------------------------##
#-------------------------------------------------------#
# NOTE for disabling shellcheck 2086 [Martinski W.]
# The first parameter [$1] MUST be UNQUOTED because it
# can be a file path argument that contains a wildcard 
# char [*] which when quoted is taken as a _literal_ 
# asterisk, and that leads to a failed execution.
# GOOD call example:
# mv -f /PATH/TO/DIR/FileName_*.tar "/PATH/TO/NEW/DIR"
#-------------------------------------------------------#
# shellcheck disable=SC2086
_movef_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then return 1 ; fi
   local prevIFS="$IFS"
   IFS="$(printf '\n\t')"
   mv -f $1 "$2" ; retcode="$?"
   IFS="$prevIFS"
   return "$retcode"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-16] ##
##----------------------------------------------##
#-------------------------------------------------------#
# NOTE for disabling shellcheck 2086 [Martinski W.]
# The single parameter [$1] MUST be UNQUOTED because it
# can be a file path argument that contains a wildcard 
# char [*] which when quoted is taken as a _literal_ 
# asterisk, and that leads to a failed execution.
# GOOD call example:
# rm -f /PATH/TO/DIR/FileName_*.tar
#-------------------------------------------------------#
# shellcheck disable=SC2086
_remf_()
{
   if [ $# -lt 1 ] || [ -z "$1" ] || [ "$1" = "*" ]
   then return 1 ; fi
   local prevIFS="$IFS"
   IFS="$(printf '\n\t')"
   rm -f $1 ; retcode="$?"
   IFS="$prevIFS"
   return "$retcode"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-16] ##
##----------------------------------------------##
#-------------------------------------------------------#
# NOTE for disabling shellcheck 2086 [Martinski W.]
# Both parameters [$1 $2] MUST be UNQUOTED because the
# 1st one can consist of some optional arguments for
# the 'ls' command (e.g. "ls -lt ..."), and 2nd param
# can be a file path argument that contains a wildcard
# char [*] which when quoted is taken as a _literal_
# asterisk, and that leads to a failed execution.
# GOOD call example:
# ls -lt /PATH/TO/DIR/FileName_*.tar
#-------------------------------------------------------#
# shellcheck disable=SC2086
_list2_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then return 1 ; fi
   local prevIFS="$IFS"
   IFS="$(printf '\n\t')"
   ls $1 $2 ; retcode="$?"
   IFS="$prevIFS"
   return "$retcode"
}

##-------------------------------------##
## Added by Martinski W. [2023-Apr-01] ##
##-------------------------------------##
_WaitForEnterKey_()
{
   ! "$waitToConfirm" && return 0
   echo ; read -rsp "Press <Enter> key to continue..." ; echo
}

_WaitForConfirmation_()
{
   ! "$waitToConfirm" && return 0
   read -rn 3 -p "$1 [yY|nN] N? " YESorNO ; echo
   if echo "$YESorNO" | grep -qE '^(Y|y|yes)$'
   then return 0 ; else return 1 ; fi
}

_NVRAM_IconsCleanupFiles_()
{ rm -f "$NVRAM_ClientsKeyVARsaved" "$NVRAM_ClientsKeyFLEsaved" ; }

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jun-10] ##
##----------------------------------------------##
_NVRAM_IconsSaveKeyValue_()
{
   NVRAM_SavedOK=false

   if [ -s "${NVRAM_Folder}/$NVRAM_ClientsKeyName" ]
   then
       if cp -fp "${NVRAM_Folder}/$NVRAM_ClientsKeyName" "$NVRAM_ClientsKeyFLEsaved"
       then NVRAM_SavedOK=true ; fi
   fi

   theKeyValue="$(nvram get "$NVRAM_ClientsKeyName")"
   if [ -n "$theKeyValue" ]
   then
       if ! echo "$theKeyValue" | grep -qE "^<.*"
       then theKeyValue="<$theKeyValue" ; fi
       echo "$theKeyValue" > "$NVRAM_ClientsKeyVARsaved"
       NVRAM_SavedOK=true
   fi

   "$NVRAM_SavedOK" && return 0

   Print_Output true "*WARNING*: NVRAM variable \"${NVRAM_ClientsKeyName}\" is EMPTY or NOT FOUND." "$WARN"
   return 1
}

_NVRAM_IconsRestoreKeyValue_()
{
   NVRAM_RestoredOK=false

   if [ -d "$NVRAM_Folder" ] && [ -f "$NVRAM_ClientsKeyFLEsaved" ] && \
      [ "$(ls -1 "$NVRAM_Folder" 2>/dev/null | wc -l)" -gt 0 ]
   then
       mv -f "$NVRAM_ClientsKeyFLEsaved" "${NVRAM_Folder}/$NVRAM_ClientsKeyName"
       nvram set ${NVRAM_ClientsKeyName}="$(cat "${NVRAM_Folder}/$NVRAM_ClientsKeyName")"
       NVRAM_RestoredOK=true
   fi

   if [ -f "$NVRAM_ClientsKeyVARsaved" ]
   then
      theKeyValueSaved="$(cat "$NVRAM_ClientsKeyVARsaved")"
      if [ "$(nvram get "$NVRAM_ClientsKeyName")" != "$theKeyValueSaved" ]
      then
          nvram set ${NVRAM_ClientsKeyName}="$theKeyValueSaved"
          NVRAM_RestoredOK=true
      fi
   fi

   _NVRAM_IconsCleanupFiles_
   "$NVRAM_RestoredOK" && nvram commit && return 0

   Print_Output true "*WARNING*: NVRAM variable \"${NVRAM_ClientsKeyName}\" was NOT restored." "$WARN"
   return 1
}

CheckForCustomIconFiles()
{
   if [ -d "$userIconsDIRpath" ] && \
      [ "$(ls -1 ${userIconsDIRpath}/*.log 2>/dev/null | wc -l)" -gt 0 ]
   then
       iconsFound=true
       UpdateCustomUserIconsConfig FOUND TRUE
       return 0
   else
       iconsFound=false
       UpdateCustomUserIconsConfig FOUND FALSE
       return 1
   fi
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jun-04] ##
##----------------------------------------------##
CheckForSavedIconFiles()
{
   theFileCount="$(_list2_ -1 "$theBackupFilesMatch" 2>/dev/null | wc -l)"
   if [ ! -d "$theUserIconsBackupDir" ] || [ "$theFileCount" -eq 0 ]
   then
       backupsFound=false
       UpdateCustomUserIconsConfig SAVED NONE
       UpdateCustomUserIconsConfig RESTD NONE
       return 1
   fi

   backupsFound=true  theBackupFile=""

   if [ $# -gt 0 ] && [ -n "$1" ] && "$1"
   then
       while IFS="$(printf '\n\t')" read -r FILE
       do theBackupFile="$FILE" ; break
       done <<EOT
$(_list2_ -1t "$theBackupFilesMatch" 2>/dev/null)
EOT
       UpdateCustomUserIconsConfig SAVED "$theBackupFile"
       UpdateCustomUserIconsConfig RESTD "$theBackupFile"
   fi
   return 0
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Sep-04] ##
##----------------------------------------------##
CheckForMaxIconsSavedFiles()
{
   if ! CheckForSavedIconFiles "$@" || \
      [ "$theFileCount" -le "$maxUserIconsBackupFiles" ]
   then return 0 ; fi

   if [ "$maxUserIconsBackupFiles" -ge "$defMaxUserIconsBackupFiles" ]
   then highWaterMark="$maxUserIconsBackupFiles"
   else highWaterMark="$((maxUserIconsBackupFiles + theHighWaterMarkThreshold))"
   fi

   if [ "$highWaterMark" -gt "$theMaxUserIconsBackupFiles" ]
   then highWaterMark="$theMaxUserIconsBackupFiles" ; fi

   if [ $# -gt 0 ] && [ -n "$1" ] && "$1" && \
      [ "$theFileCount" -gt "$highWaterMark" ]
   then   ## Remove the OLDEST backup file ##
       while IFS="$(printf '\n\t')" read -r FILE
       do
           _remf_ "$FILE" && theFileCount="$((theFileCount - 1))"
           break
       done <<EOT
$(_list2_ -1tr "$theBackupFilesMatch" 2>/dev/null)
EOT
       if [ "$theFileCount" -le "$maxUserIconsBackupFiles" ]
       then return 0 ; fi
   fi

   ! "$waitToConfirm" && return 1

   printf "\n\n${WarnBYLWct}**WARNING**${CLRct}\n"
   printf "The number of backup files [${REDct}${theFileCount}${CLRct}] exceeds the maximum [${GRNct}${maxUserIconsBackupFiles}${CLRct}].\n"
   printf "It's highly recommended that you either delete old backup files,\n"
   printf "or move them from the current directory to a different location.\n"
   _WaitForEnterKey_
   return 1
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jun-03] ##
##----------------------------------------------##
BackupCustomUserIcons()
{
   local retCode

   if ! CheckForCustomIconFiles
   then
       UpdateCustomUserIconsConfig SAVED NONE STATUSupdate
       Print_Output true "**ERROR**: Directory [$userIconsDIRpath] is EMPTY or NOT FOUND." "$ERR"
       return 1
   fi
   UpdateCustomUserIconsConfig SAVED WAIT
   _NVRAM_IconsSaveKeyValue_

   theFilePath="${userIconsBackupFPath}_$(date +"$savedFileDateTimeStr").$userIconsSavedFLEextn"
   if ! tar -czf "$theFilePath" -C "$theJFFSdir" "./$userIconsDIRname"
   then
       retCode=1
       UpdateCustomUserIconsConfig SAVED NONE STATUSupdate
       Print_Output true "**ERROR**: Could NOT save icon files." "$ERR"
   else
       retCode=0
       chmod 664 "$theFilePath"
       UpdateCustomUserIconsConfig SAVED "$theFilePath" STATUSupdate
       printf "All icon files were successfully saved in:\n[${GRNct}${theFilePath}${CLRct}]\n"
   fi
   _NVRAM_IconsCleanupFiles_
   CheckForMaxIconsSavedFiles true && _WaitForEnterKey_
   return "$retCode"
}

##----------------------------------------------##
## Added/modified by Martinski W. [2023-Nov-17] ##
##----------------------------------------------##
_GetFileSelectionIndex_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

   local selectStr  promptStr  numRegEx  indexNum  indexList
   local multiIndexListOK  theAllStr="${GRNct}all${CLRct}"

   if [ "$1" -eq 1 ]
   then selectStr="${GRNct}1${CLRct}"
   else selectStr="${GRNct}1${CLRct}-${GRNct}${1}${CLRct}"
   fi

   if [ $# -lt 2 ] || [ "$2" != "-MULTIOK" ]
   then
       multiIndexListOK=false
       promptStr="Enter selection [${selectStr}] [${theExitStr}]?"
   else
       multiIndexListOK=true
       promptStr="Enter selection [${selectStr} | ${theAllStr}] [${theExitStr}]?"
   fi
   fileIndex=0  multiIndex=false
   numRegEx="([1-9]|[1-9][0-9])"

   while true
   do
       printf "${promptStr}  " ; read -r userInput

       if [ -z "$userInput" ] || \
          echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then fileIndex="NONE" ; break ; fi

       if "$multiIndexListOK" && \
          echo "$userInput" | grep -qE "^(all|All)$"
       then fileIndex="ALL" ; break ; fi

       if echo "$userInput" | grep -qE "^${numRegEx}$" && \
          [ "$userInput" -gt 0 ] && [ "$userInput" -le "$1" ]
       then fileIndex="$userInput" ; break ; fi

       if "$multiIndexListOK" && \
          echo "$userInput" | grep -qE "^${numRegEx}\-${numRegEx}[ ]*$"
       then ## Index Range ##
           index1st="$(echo "$userInput" | awk -F '-' '{print $1}')"
           indexMax="$(echo "$userInput" | awk -F '-' '{print $2}')"
           if [ "$index1st" -lt "$indexMax" ]  && \
              [ "$index1st" -gt 0 ] && [ "$index1st" -le "$1" ] && \
              [ "$indexMax" -gt 0 ] && [ "$indexMax" -le "$1" ]
           then
               indexNum="$index1st"
               indexList="$indexNum"
               while [ "$indexNum" -lt "$indexMax" ]
               do
                   indexNum="$((indexNum+1))"
                   indexList="${indexList},${indexNum}"
               done
               userInput="$indexList"
           fi
       fi

       if "$multiIndexListOK" && \
          echo "$userInput" | grep -qE "^${numRegEx}(,[ ]*${numRegEx}[ ]*)+$"
       then ## Index List ##
           indecesOK=true
           indexList="$(echo "$userInput" | sed 's/ //g' | sed 's/,/ /g')"
           for theIndex in $indexList
           do
              if [ "$theIndex" -eq 0 ] || [ "$theIndex" -gt "$1" ]
              then indecesOK=false ; break ; fi
           done
           "$indecesOK" && fileIndex="$indexList" && multiIndex=true && break
       fi

       printf "${REDct}INVALID selection.${CLRct}\n"
   done
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jun-04] ##
##----------------------------------------------##
_GetFileSelection_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

   if [ $# -lt 2 ] || [ "$2" != "-MULTIOK" ]
   then indexType="" ; else indexType="$2" ; fi

   theFilePath=""  theFileName=""  fileTemp=""
   fileCount=0  fileIndex=0  multiIndex=false
   printf "\n${1}\n[Directory: ${GRNct}${theUserIconsBackupDir}${CLRct}]\n\n"

   while IFS="$(printf '\n\t')" read -r backupFilePath
   do
       fileCount=$((fileCount+1))
       fileVar="file_${fileCount}_Name"
       eval file_${fileCount}_Name="${backupFilePath##*/}"
       printf "${GRNct}%3d${CLRct}. " "$fileCount"
       eval echo "\$${fileVar}"
   done <<EOT
$(_list2_ -1t "$theBackupFilesMatch" 2>/dev/null)
EOT
   echo
   _GetFileSelectionIndex_ "$fileCount" "$indexType"

   if [ "$fileIndex" = "ALL" ] || [ "$fileIndex" = "NONE" ]
   then theFilePath="$fileIndex" ; return 0 ; fi

   if [ "$indexType" = "-MULTIOK" ] && "$multiIndex"
   then
       for index in $fileIndex
       do
           fileVar="file_${index}_Name"
           eval fileTemp="\$${fileVar}"
           if [ -z "$theFilePath" ]
           then theFilePath="${theUserIconsBackupDir}/$fileTemp"
           else theFilePath="${theFilePath}|${theUserIconsBackupDir}/$fileTemp"
           fi
       done
   else
       fileVar="file_${fileIndex}_Name"
       eval theFileName="\$${fileVar}"
       theFilePath="${theUserIconsBackupDir}/$theFileName"
   fi
   return 0
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jun-04] ##
##----------------------------------------------##
GetSavedBackupFilesList()
{
   GetUserIconsSavedVars
   rm -f "$SCRIPT_USER_ICONS_BKPLST"
   if ! CheckForSavedIconFiles
   then
       echo "NONE" > "$SCRIPT_USER_ICONS_BKPLST"
       return 1
   fi

   echo "## [$(date +"$savedFileDateTimeStr")] ##" > "$SCRIPT_USER_ICONS_BKPLST"
   echo "$userIconsBKPListHeader $theUserIconsBackupDir" >> "$SCRIPT_USER_ICONS_BKPLST"

   fileCount=0  fileName=""
   while IFS="$(printf '\n\t')" read -r backupFilePath
   do
       fileCount=$((fileCount+1))
       fileName="${backupFilePath##*/}"
       printf "%3d. ${fileName}\n" "$fileCount" >> "$SCRIPT_USER_ICONS_BKPLST"
   done <<EOT
$(_list2_ -1t "$theBackupFilesMatch" 2>/dev/null)
EOT
   return 0
}

##----------------------------------------------##
## Added/modified by Martinski W. [2023-Apr-24] ##
##----------------------------------------------##
RestoreUserIconFilesReq()
{
   GetUserIconsSavedVars
   if ! CheckForSavedIconFiles || [ ! -f "$SCRIPT_USER_ICONS_BKPLST" ]
   then
       UpdateCustomUserIconsConfig RESTD NONE STATUSupdate
       Print_Output true "**ERROR**: Backup file(s) [$theBackupFilesMatch] NOT found." "$ERR"
       return 1
   fi
   if [ $# -eq 0 ] || [ -z "$1" ] || \
      ! echo "$1" | grep -qE "^${SCRIPT_NAME}restoreIcons_reqNum_[1-9]+"
   then
       UpdateCustomUserIconsConfig RESTD NONE STATUSupdate
       Print_Output true "**ERROR**: INVALID index to backup file path was provided." "$ERR"
       return 1
   fi
   UpdateCustomUserIconsConfig RESTD WAIT

   local retCode
   fileCount=0  theFilePath=""
   fileIndex="$(echo "$1" | awk -F '_' '{print $3}')"

   while read -r theFileName
   do
       if echo "$theFileName" | grep -qE "^##" || \
          echo "$theFileName" | grep -qE "^$userIconsBKPListHeader"
       then continue ; fi

       fileCount=$((fileCount+1))
       if [ "$fileCount" -eq "$fileIndex" ]
       then
           theFilePath="${theUserIconsBackupDir}/${theFileName#* }"
           break
       fi
   done < "$SCRIPT_USER_ICONS_BKPLST"
   rm -f "$SCRIPT_USER_ICONS_BKPLST"

   if [ "$fileIndex" -gt "$fileCount" ]
   then
       UpdateCustomUserIconsConfig RESTD NONE STATUSupdate
       Print_Output true "**ERROR**: Archive file index [$fileIndex] is INVALID." "$ERR"
       return 1
   fi

   if [ -z "$theFilePath" ] || [ ! -f "$theFilePath" ]
   then
       UpdateCustomUserIconsConfig RESTD NONE STATUSupdate
       Print_Output true "**ERROR**: Archive file [$theFilePath] NOT FOUND." "$ERR"
       return 1
   fi
   Print_Output true "Restoring icon files from: [${fileIndex}. $theFilePath]" "$PASS"

   if ! tar -xzf "$theFilePath" -C "$theJFFSdir"
   then
       retCode=1
       UpdateCustomUserIconsConfig RESTD NONE STATUSupdate
       Print_Output true "**ERROR**: Could NOT restore icon files from [$theFilePath]." "$ERR"
   else
       retCode=0
       _NVRAM_IconsRestoreKeyValue_
       UpdateCustomUserIconsConfig RESTD "$theFilePath" STATUSupdate
       Print_Output true "All icon files were restored successfully." "$PASS"
   fi
   return "$retCode"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-17] ##
##----------------------------------------------##
RestoreCustomUserIcons()
{
   local retCode
   theFilePath=""  theFileCount=0

   if ! CheckForSavedIconFiles
   then
       UpdateCustomUserIconsConfig RESTD NONE STATUSupdate
       Print_Output true "**ERROR**: Backup file(s) [$theBackupFilesMatch] NOT FOUND." "$ERR"
       return 1
   fi
   UpdateCustomUserIconsConfig RESTD WAIT

   if [ $# -gt 0 ] && [ -n "$1" ] && "$1"
   then  ## Restore from the MOST recent backup file ##
       while IFS="$(printf '\n\t')" read -r FILE
       do theFilePath="$FILE" ; break
       done <<EOT
$(_list2_ -1t "$theBackupFilesMatch" 2>/dev/null)
EOT
   else
       _GetFileSelection_ "Select a backup file to restore the icon files from:"
   fi

   if [ "$theFilePath" = "NONE" ] || [ ! -f "$theFilePath" ]
   then
       UpdateCustomUserIconsConfig RESTD NONE STATUSupdate
       return 1
   fi

   printf "Restoring icon files from:\n[${GRNct}$theFilePath${CLRct}]\n"
   if ! _WaitForConfirmation_ "Please confirm selection"
   then
       printf "Icon file(s) ${REDct}NOT${CLRct} restored.\n"
       _WaitForEnterKey_
       return 99
   fi

   if ! tar -xzf "$theFilePath" -C "$theJFFSdir"
   then
       retCode=99
       UpdateCustomUserIconsConfig RESTD NONE STATUSupdate
       Print_Output true "**ERROR**: Could NOT restore icon files." "$ERR"
   else
       retCode=0
       _NVRAM_IconsRestoreKeyValue_
       UpdateCustomUserIconsConfig RESTD "$theFilePath" STATUSupdate
       printf "All icon files were restored ${GRNct}successfully${CLRct}.\n\n"
       ls -AlF "$userIconsDIRpath"
   fi
   _WaitForEnterKey_
   return "$retCode"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-17] ##
##----------------------------------------------##
ListContentsOfSavedIconsFile()
{
   local retCode
   theFilePath=""  theFileCount=0

   if ! CheckForSavedIconFiles
   then
       Print_Output true "**ERROR**: Backup file(s) [$theBackupFilesMatch] NOT FOUND." "$ERR"
       return 1
   fi
   _GetFileSelection_ "Select a backup file to list contents of:"

   if [ "$theFilePath" = "NONE" ] || [ ! -f "$theFilePath" ]
   then return 1 ; fi

   printf "Listing contents of backup file:\n[${GRNct}${theFilePath}${CLRct}]\n\n"
   if tar -tzf "$theFilePath" -C "$theJFFSdir"
   then
       retCode=0
       printf "\nContents were listed ${GRNct}successfully${CLRct}.\n"
   else
       retCode=99
       printf "\n${REDct}**ERROR**:${CLRct} Could NOT list contents.\n"
   fi
   _WaitForEnterKey_
   return "$retCode"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-17] ##
##----------------------------------------------##
DeleteSavedIconsFile()
{
   local retCode
   theFilePath=""  fileIndex=0  multiIndex=false

   if ! CheckForSavedIconFiles
   then
       Print_Output true "**ERROR**: Backup file(s) [$theBackupFilesMatch] NOT FOUND." "$ERR"
       return 1
   fi
   _GetFileSelection_ "Select a backup file to delete:" -MULTIOK

   if [ "$theFilePath" = "NONE" ] ; then return 1 ; fi
   if [ "$theFilePath" != "ALL" ] && ! "$multiIndex" && [ ! -f "$theFilePath" ]
   then return 1 ; fi

   if [ "$theFilePath" != "ALL" ]
   then
       fileToDelete="$theFilePath"
       delMsg="Deleting backup file(s):"
   else
       fileToDelete="$theBackupFilesMatch"
       delMsg="Deleting ${REDct}ALL${CLRct} backup(s):"
   fi
   if ! "$multiIndex"
   then theFileList="$fileToDelete"
   else
       theFileList="$(echo "$fileToDelete" | sed 's/|/\n/g')"
       fileToDelete="$theFileList"
   fi

   printf "${delMsg}\n${GRNct}${theFileList}${CLRct}\n"
   if ! _WaitForConfirmation_ "Please confirm deletion"
   then
       printf "File(s) ${REDct}NOT${CLRct} deleted.\n"
       _WaitForEnterKey_
       return 99
   fi

   fileDelOK=true
   local prevIFS="$IFS"
   IFS="$(printf '\n\t')"
   for thisFile in $fileToDelete
   do if ! _remf_ "$thisFile" ; then fileDelOK=false ; fi ; done
   IFS="$prevIFS"

   if "$fileDelOK"
   then
       retCode=0
       printf "File deletion completed ${GRNct}successfully${CLRct}.\n"
   else
       retCode=99
       printf "\n${REDct}**ERROR**:${CLRct} Could NOT delete file(s).\n"
   fi
   _WaitForEnterKey_
   return "$retCode"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-17] ##
##----------------------------------------------##
SetMaxNumberOfBackupFiles()
{
   local numRegEx="([1-9]|[1-9][0-9])"  newMaxNumOfBackups="DEFAULT"
   echo
   while true
   do
       printf "Enter the maximum number of backups of user icons to keep.\n"
       printf "[${GRNct}${theMinUserIconsBackupFiles}${CLRct}-${GRNct}${theMaxUserIconsBackupFiles}${CLRct}] | [DEFAULT: ${GRNct}${maxUserIconsBackupFiles}${CLRct}] [${theExitStr}]?  "
       read -r userInput

       if [ -z "$userInput" ] || \
          echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then newMaxNumOfBackups="DEFAULT" ; break ; fi

       if echo "$userInput" | grep -qE "^${numRegEx}$" && \
          [ "$userInput" -ge "$theMinUserIconsBackupFiles" ] && \
          [ "$userInput" -le "$theMaxUserIconsBackupFiles" ]
       then newMaxNumOfBackups="$userInput" ; break ; fi

       printf "${REDct}INVALID input.${CLRct}\n"
   done

   if [ "$newMaxNumOfBackups" != "DEFAULT" ]
   then
       maxUserIconsBackupFiles="$newMaxNumOfBackups"
       UpdateCustomUserIconsConfig SAVED_MAX "$maxUserIconsBackupFiles"
   fi
   return 0
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-17] ##
##----------------------------------------------##
SetCustomUserIconsBackupDirectory()
{
   local newBackupDirPath="DEFAULT"
   echo
   while true
   do
       printf "Enter the directory path where the backups subdirectory [${GRNct}${userIconsSavedDIRname}${CLRct}] will be stored.\n"
       printf "[DEFAULT: ${GRNct}${theUserIconsBackupDir%/*}${CLRct}] [${theExitStr}]?  "
       read -r userInput

       if [ -z "$userInput" ] || \
          echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then newBackupDirPath="DEFAULT" ; break ; fi

       if echo "$userInput" | grep -q '/$'
       then userInput="${userInput%/*}" ; fi

       if echo "$userInput" | grep -q '//'   || \
          echo "$userInput" | grep -q '/$'   || \
          ! echo "$userInput" | grep -q '^/' || \
          [ "${#userInput}" -lt 4 ]          || \
          [ "$(echo "$userInput" | awk -F '/' '{print NF-1}')" -lt 2 ]
       then
           printf "${REDct}INVALID input.${CLRct}\n"
           continue
       fi

       if [ -d "$userInput" ]
       then newBackupDirPath="$userInput" ; break ; fi

       rootDir="${userInput%/*}"
       if [ ! -d "$rootDir" ]
       then
           printf "${REDct}**ERROR**:${CLRct} Root directory path [$rootDir] does NOT exist.\n"
           printf "${REDct}INVALID input.${CLRct}\n"
           continue
       fi

       printf "The directory path '${REDct}${userInput}${CLRct}' does NOT exist.\n"
       if ! _WaitForConfirmation_ "Do you want to create it now"
       then
           printf "Directory was ${REDct}NOT${CLRct} created.\n\n"
       else
           mkdir -m 755 "$userInput" 2>/dev/null
           if [ -d "$userInput" ]
           then newBackupDirPath="$userInput" ; break
           else printf "\n${REDct}**ERROR**: Could NOT create directory [$userInput]${CLRct}.\n\n"
           fi
       fi
   done

   if [ "$newBackupDirPath" != "DEFAULT" ] && [ -d "$newBackupDirPath" ]
   then
       if  [ "${newBackupDirPath##*/}" != "$userIconsSavedDIRname" ]
       then newBackupDirPath="${newBackupDirPath}/$userIconsSavedDIRname" ; fi
       mkdir -m 755 "$newBackupDirPath" 2>/dev/null
       if [ ! -d "$newBackupDirPath" ]
       then
           printf "\n${REDct}**ERROR**${CLRct}: Could NOT create directory [${REDct}${newBackupDirPath}${CLRct}].\n"
           _WaitForEnterKey_ ; return 1
       fi
       if CheckForSavedIconFiles && [ "$newBackupDirPath" != "$theUserIconsBackupDir" ]
       then
           printf "\nMoving existing backup files to directory:\n[${GRNct}$newBackupDirPath${CLRct}]\n"
           if _movef_ "$theBackupFilesMatch" "$newBackupDirPath" && \
              ! CheckForSavedIconFiles
           then rmdir "$theUserIconsBackupDir" 2>/dev/null ; fi
       fi
       UpdateCustomUserIconsConfig SAVED_DIR "$newBackupDirPath"
       UpdateCustomUserIconsConfig PREFS_DIR "$newBackupDirPath"
       CheckForSavedIconFiles true
   fi
   return 0
}

##----------------------------------------------##
## Added/modified by Martinski W. [2023-Apr-15] ##
##----------------------------------------------##
ShowIconsMenuOptions()
{
   SEPstr="--------------------------------------------------------------------"
   printf "\n${SEPstr}\n"
   CheckForCustomIconFiles ; CheckForSavedIconFiles

   if ! "$iconsFound" && ! "$backupsFound"
   then
       printf "\nNo custom user icon files and no previously saved backup files were found.\n"
       printf "${REDct}Exiting to main menu...${CLRct}\n"
       _WaitForEnterKey_
       printf "\n${SEPstr}\n"
       return 1
   fi

   printf "\n ${GRNct}${MaxBckupsOpt}${CLRct}.  Maximum number of backups of icon files to keep."
   printf "\n      [Current Max: ${GRNct}${maxUserIconsBackupFiles}${CLRct}]\n"

   printf "\n ${GRNct}${BackupDirOpt}${CLRct}.  Directory path where backups of icon files are stored."
   printf "\n      [Current Path: ${GRNct}${theUserIconsBackupDir}${CLRct}]\n"

   if "$iconsFound" && [ -d "$theUserIconsBackupDir" ]
   then
       printf "\n ${GRNct}${BkupIconsOpt}${CLRct}.  Back up the icon files found in the ${GRNct}${userIconsDIRpath}${CLRct} directory.\n"
   fi

   if "$backupsFound"
   then
       printf "\n ${GRNct}${RestIconsOpt}${CLRct}.  Restore the icon files into the ${GRNct}${userIconsDIRpath}${CLRct} directory.\n"
       printf "\n ${GRNct}${DeltIconsOpt}${CLRct}.  Delete a previously saved backup of icon files.\n"
       printf "\n ${GRNct}${ListIconsOpt}${CLRct}.  List contents of a previously saved backup of icon files.\n"
   fi

   printf "\n  ${GRNct}e${CLRct}.  Exit to main menu.\n"
   printf "\n${SEPstr}\n"
   return 0
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-17] ##
##----------------------------------------------##
IconsMenuSelectionHandler()
{
   local exitMenu=false  retCode

   until ! ShowIconsMenuOptions
   do
      while true
      do
          printf "Choose an option:    " ; read -r userOption
          if [ -z "$userOption" ] ; then echo ; continue ; fi

          if echo "$userOption" | grep -qE "^(e|exit|Exit)$"
          then exitMenu=true ; break ; fi

          if [ "$userOption" = "$MaxBckupsOpt" ]
          then SetMaxNumberOfBackupFiles; break ; fi

          if [ "$userOption" = "$BackupDirOpt" ]
          then SetCustomUserIconsBackupDirectory ; break ; fi

          if [ "$userOption" = "$BkupIconsOpt" ] && \
             "$iconsFound" && [ -d "$theUserIconsBackupDir" ]
          then BackupCustomUserIcons ; break ; fi

          if [ "$userOption" = "$RestIconsOpt" ] && "$backupsFound"
          then
              while true
              do
                  RestoreCustomUserIcons ; retCode="$?"
                  if [ "$retCode" -eq 99 ]
                  then continue ; else break ; fi
              done
              break
          fi

          if [ "$userOption" = "$DeltIconsOpt" ] && "$backupsFound"
          then
              while true
              do
                  DeleteSavedIconsFile ; retCode="$?"
                  if [ "$retCode" -eq 99 ]
                  then continue ; else break ; fi
              done
              break
          fi

          if [ "$userOption" = "$ListIconsOpt" ] && "$backupsFound"
          then
              while true
              do
                  ListContentsOfSavedIconsFile ; retCode="$?"
                  if [ "$retCode" -eq 99 ] || [ "$retCode" -eq 0 ]
                  then continue ; else break ; fi
              done
              break
          fi

          printf "${REDct}INVALID option.${CLRct}\n"
      done
      "$exitMenu" && break
   done
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jun-14] ##
##----------------------------------------------##
Menu_CustomUserIconsOps()
{
   waitToConfirm=true
   if GetUserIconsSavedVars
   then
       CheckForMaxIconsSavedFiles
       IconsMenuSelectionHandler
       CheckForMaxIconsSavedFiles
   fi
   Clear_Lock
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jun-14] ##
##----------------------------------------------##
CheckUserIconFiles()
{
   waitToConfirm=false
   GetUserIconsSavedVars
   CheckForCustomIconFiles
   CheckForSavedIconFiles true
}

BackUpUserIconFiles()
{
   waitToConfirm=false
   ClearCustomUserIconsStatus
   GetUserIconsSavedVars
   BackupCustomUserIcons
   CheckForSavedIconFiles
}

RestoreUserIconFiles()
{
   waitToConfirm=false
   ClearCustomUserIconsStatus
   GetUserIconsSavedVars
   RestoreCustomUserIcons "$1"
   CheckForCustomIconFiles
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Jun-10] ##
##----------------------------------------------##
CheckAgainstNVRAMvar()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 0 ; fi

   if [ ! -s /jffs/nvram/dhcp_staticlist ]
   then theKeyVal="$(nvram get dhcp_staticlist)"
   else theKeyVal="$(cat /jffs/nvram/dhcp_staticlist)"
   fi
   if [ -z "$theKeyVal" ] ; then return 0 ; fi
   if ! echo "$theKeyVal" | grep -qE "^<.*"
   then theKeyVal="<$theKeyVal" ; fi

   retCode=0
   MACx_Addrs="$(echo "$1" | awk -F ' ' '{print $1}')"
   IPv4_Addrs="$(echo "$1" | awk -F ' ' '{print $2}')"
   IPv4_RegEx="([0-9]{1,3}\.){3}([0-9]{1,3})"
   MACx_RegEx="([a-fA-F0-9]{2}\:){5}([a-fA-F0-9]{2})"
   theRegExp1="<${MACx_Addrs}>${IPv4_RegEx}>[^<]*"
   theRegExp2="<${MACx_RegEx}>${IPv4_Addrs}>[^<]*"
   keyEntry=""

   if echo "$theKeyVal" | grep -qiE "$theRegExp1"
   then keyEntry="$(echo "$theKeyVal" | grep -ioE "$theRegExp1")"
   elif echo "$theKeyVal" | grep -qiE "$theRegExp2"
   then keyEntry="$(echo "$theKeyVal" | grep -ioE "$theRegExp2")"
   fi
   if [ -n "$keyEntry" ]
   then
       tempFile="/tmp/yazdhcp_nvramstr.tmp"
       echo "$theKeyVal" | sed "s/${keyEntry}//g" | sed '/^$/d' > "$tempFile"
       nvram set dhcp_staticlist="$(cat "$tempFile")"
       rm -f $tempFile
       retCode=1
   fi
   return $retCode
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-May-28] ##
##----------------------------------------------##
ValidateNVRAMentry()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

   retCode=0
   dupInfoMsg=""
   MACx_Addrs="$(echo "$1" | awk -F '|' '{print $1}')"
   IPv4_Addrs="$(echo "$1" | awk -F '|' '{print $2}')"
   theClientx="${MACx_Addrs},${IPv4_Addrs}"

   if grep -qi "^${theClientx}" "$SCRIPT_CONF"
   then
       dupInfoMsg="Client entry [$theClientx] is already found"
   elif grep -qi "^${MACx_Addrs}," "$SCRIPT_CONF"
   then
       dupInfoMsg="Client MAC address [$MACx_Addrs] is already found"
   elif grep -qi ",${IPv4_Addrs}," "$SCRIPT_CONF"
   then
       dupInfoMsg="Client IP address [$IPv4_Addrs] is already assigned"
   fi
   if [ -n "$dupInfoMsg" ]
   then
       Print_Output true "$dupInfoMsg in $SCRIPT_CONF file" "$WARN"
       Print_Output true "NVRAM entry will be skipped/ignored." "$WARN"
       retCode=1
   fi
   return $retCode
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jun-27] ##
##----------------------------------------##
### nvram parsing code based on dhcpstaticlist.sh by @Xentrk ###
Export_FW_DHCP_JFFS()
{
	printf "\n${BOLD}Do you want to export DHCP assignments and hostnames from NVRAM to %s DHCP client files?${CLEARct}\n" "$SCRIPT_NAME"
	printf "%s will backup NVRAM/JFFS DHCP data as part of the export process.\n" "$SCRIPT_NAME"
	printf "\n${BOLD}Enter answer (y/n):  ${CLEARct}"
	read -r confirm
	case "$confirm" in
		y|Y)
			:
		;;
		*)
			Clear_Lock
			return 1
		;;
	esac

	if [ "$(nvram get dhcp_staticlist | wc -m)" -le 1 ]
	then
		Print_Output true "DHCP static assignments not exported from NVRAM, no data found" "$PASS"
		Clear_Lock
		return 1
	fi

	if [ "$(Firmware_Version_Number "$fwInstalledBranchVer")" -lt "$(Firmware_Version_Number "3004.386.4")" ]
	then
		if [ -f /jffs/nvram/dhcp_hostnames ]
		then
			if [ "$(wc -m < /jffs/nvram/dhcp_hostnames)" -le 1 ]
			then
				Print_Output true "DHCP hostnames not exported from NVRAM, no data found" "$PASS"
				Clear_Lock
				return 1
			fi
		elif [ "$(nvram get dhcp_hostnames | wc -m)" -le 1 ]; then
			Print_Output true "DHCP hostnames not exported from NVRAM, no data found" "$PASS"
			Clear_Lock
			return 1
		fi

		if [ -f /jffs/nvram/dhcp_staticlist ]
		then
			sed 's/</\n/g;s/>/ /g;s/<//g' /jffs/nvram/dhcp_staticlist | sed '/^$/d' > /tmp/yazdhcp-ips.tmp
		else
			nvram get dhcp_staticlist | sed 's/</\n/g;s/>/ /g;s/<//g'| sed '/^$/d' > /tmp/yazdhcp-ips.tmp
		fi

		if [ -f /jffs/nvram/dhcp_hostnames ]; then
			HOSTNAME_LIST=$(sed 's/>undefined//' /jffs/nvram/dhcp_hostnames)
		else
			HOSTNAME_LIST=$(nvram get dhcp_hostnames | sed 's/>undefined//')
		fi

		OLDIFS=$IFS
		IFS="<"

		for HOST in $HOSTNAME_LIST
		do
			if [ "$HOST" = "" ]; then
				continue
			fi
			MAC=$(echo "$HOST" | cut -d ">" -f1)
			HOSTNAME=$(echo "$HOST" | cut -d ">" -f2)
			echo "$MAC $HOSTNAME" >> /tmp/yazdhcp-hosts.tmp
		done

		IFS=$OLDIFS

		sed -i 's/ $//' /tmp/yazdhcp-ips.tmp
		sed -i 's/ $//' /tmp/yazdhcp-hosts.tmp

		awk 'NR==FNR { k[$1]=$2; next } { print $0, k[$1] }' /tmp/yazdhcp-hosts.tmp /tmp/yazdhcp-ips.tmp > /tmp/yazdhcp.tmp

		echo "MAC,IP,HOSTNAME,DNS" > "$SCRIPT_CONF"
		sort -t . -k 3,3n -k 4,4n /tmp/yazdhcp.tmp > /tmp/yazdhcp_sorted.tmp

		while IFS='' read -r line || [ -n "$line" ]
		do
			if [ "$(echo "$line" | wc -w)" -eq 4 ]; then
				echo "$line" | awk '{ print ""$1","$2","$4","$3""; }' >> "$SCRIPT_CONF"
			else
				if ! Validate_IP "$(echo "$line" | cut -d " " -f3)" >/dev/null 2>&1; then
					printf "%s,\\n" "$(echo "$line" | sed 's/ /,/g')" >> "$SCRIPT_CONF"
				else
					echo "$line" | awk '{ print ""$1","$2","","$3""; }' >> "$SCRIPT_CONF"
				fi
			fi
		done < /tmp/yazdhcp_sorted.tmp

		rm -f /tmp/yazdhcp*.tmp

		if [ -f /jffs/nvram/dhcp_hostnames ]
		then
			cp -f /jffs/nvram/dhcp_hostnames "$SCRIPT_DIR/.nvram_jffs_dhcp_hostnames"
			rm -f /jffs/nvram/dhcp_hostnames
		fi
		nvram get dhcp_hostnames > "$SCRIPT_DIR/.nvram_dhcp_hostnames"
		nvram unset dhcp_hostnames
	else
		if [ -f /jffs/nvram/dhcp_staticlist ]; then
			sed 's/</\n/g;s/>/|/g;s/<//g' /jffs/nvram/dhcp_staticlist | sed '/^$/d' > /tmp/yazdhcp.tmp
		else
			nvram get dhcp_staticlist | sed 's/</\n/g;s/>/|/g;s/<//g'| sed '/^$/d' > /tmp/yazdhcp.tmp
		fi

		if [ ! -f "$SCRIPT_CONF" ] || [ ! -s "$SCRIPT_CONF" ]
		then echo "MAC,IP,HOSTNAME,DNS" > "$SCRIPT_CONF" ; fi
		sort -t . -k 3,3n -k 4,4n /tmp/yazdhcp.tmp > /tmp/yazdhcp_sorted.tmp

		while IFS='' read -r line || [ -n "$line" ]
		do
			if ! ValidateNVRAMentry "$line" ; then continue ; fi
			echo "$line" | awk 'FS="|" { print ""$1","$2","$4","$3""; }' >> "$SCRIPT_CONF"
		done < /tmp/yazdhcp_sorted.tmp

		rm -f /tmp/yazdhcp*.tmp
	fi

	if [ -f /jffs/nvram/dhcp_staticlist ]; then
		cp -f /jffs/nvram/dhcp_staticlist "$SCRIPT_DIR/.nvram_jffs_dhcp_staticlist"
	fi
	theKeyVal="$(nvram get dhcp_staticlist)"
	if ! echo "$theKeyVal" | grep -qE "^<.*"
	then theKeyVal="<$theKeyVal" ; fi
	echo "$theKeyVal" > "$SCRIPT_DIR/.nvram_dhcp_staticlist"
	nvram unset dhcp_staticlist
	nvram commit

	Print_Output true "DHCP information successfully exported from NVRAM" "$PASS"

	if ProcessDHCPClients true
	then
		Print_Output true "Restarting dnsmasq for exported DHCP settings to take effect." "$PASS"
		service restart_dnsmasq >/dev/null 2>&1
	fi
	Clear_Lock
}
##################################################################

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-26] ##
##----------------------------------------##
ProcessDHCPClients()
{
    local retCode=1
    if [ $# -gt 0 ] && { [ "$1" = "true" ] || [ "$1" = "false" ] ; }
    then RESTART_DNSMASQ="$1"
    else RESTART_DNSMASQ=false
    fi

    Update_Hostnames
    Update_Staticlist
    Update_Optionslist

    if "$RESTART_DNSMASQ"
    then
        retCode=0
        Auto_DNSMASQ create false 2>/dev/null
    fi
    return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Mar-14] ##
##----------------------------------------##
Update_Hostnames()
{
	existingmd5=""
	if [ -f "$SCRIPT_DIR/.hostnames" ]; then
		existingmd5="$(md5sum "$SCRIPT_DIR/.hostnames" | awk '{print $1}')"
	fi
	tail -n +2 "$SCRIPT_CONF" | awk -F',' '$3 != "" { print ""$2" "$3""; }' > "$SCRIPT_DIR/.hostnames"

	updatedmd5="$(md5sum "$SCRIPT_DIR/.hostnames" | awk '{print $1}')"
	if [ "$existingmd5" != "$updatedmd5" ]; then
		Print_Output true "DHCP hostname list updated successfully" "$PASS"
		RESTART_DNSMASQ=true
	else
		Print_Output true "DHCP hostname list unchanged" "$WARN"
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Mar-14] ##
##----------------------------------------##
Update_Staticlist()
{
	existingmd5=""
	if [ -f "$SCRIPT_DIR/.staticlist" ]; then
		existingmd5="$(md5sum "$SCRIPT_DIR/.staticlist" | awk '{print $1}')"
	fi
	tail -n +2 "$SCRIPT_CONF" | awk -F',' '{ print ""$1",set:"$1","$2""; }' > "$SCRIPT_DIR/.staticlist"
	updatedmd5="$(md5sum "$SCRIPT_DIR/.staticlist" | awk '{print $1}')"
	if [ "$existingmd5" != "$updatedmd5" ]; then
		Print_Output true "DHCP static assignment list updated successfully" "$PASS"
		RESTART_DNSMASQ=true
	else
		Print_Output true "DHCP static assignment list unchanged" "$WARN"
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Mar-14] ##
##----------------------------------------##
Update_Optionslist()
{
	existingmd5=""
	if [ -f "$SCRIPT_DIR/.optionslist" ]; then
		existingmd5="$(md5sum "$SCRIPT_DIR/.optionslist" | awk '{print $1}')"
	fi
	tail -n +2 "$SCRIPT_CONF" | awk -F',' '$4 != "" { print "tag:"$1",6,"$4""; }' > "$SCRIPT_DIR/.optionslist"
	updatedmd5="$(md5sum "$SCRIPT_DIR/.optionslist" | awk '{print $1}')"
	if [ "$existingmd5" != "$updatedmd5" ]; then
		Print_Output true "DHCP options list updated successfully" "$PASS"
		RESTART_DNSMASQ=true
	else
		Print_Output true "DHCP options list unchanged" "$WARN"
	fi
}

ScriptHeader()
{
	clear
	printf "\n"
	printf "${BOLD}##########################################################${CLEARct}\\n"
	printf "${BOLD}##                                                      ##${CLEARct}\\n"
	printf "${BOLD}##  __     __          _____   _    _   _____  _____    ##${CLEARct}\\n"
	printf "${BOLD}##  \ \   / /         |  __ \ | |  | | / ____||  __ \   ##${CLEARct}\\n"
	printf "${BOLD}##   \ \_/ /__ _  ____| |  | || |__| || |     | |__) |  ##${CLEARct}\\n"
	printf "${BOLD}##    \   // _  ||_  /| |  | ||  __  || |     |  ___/   ##${CLEARct}\\n"
	printf "${BOLD}##     | || (_| | / / | |__| || |  | || |____ | |       ##${CLEARct}\\n"
	printf "${BOLD}##     |_| \__,_|/___||_____/ |_|  |_| \_____||_|       ##${CLEARct}\\n"
	printf "${BOLD}##                                                      ##${CLEARct}\\n"
	printf "${BOLD}##              %9s on %-18s         ##${CLEARct}\n" "$SCRIPT_VERSION" "$ROUTER_MODEL"
	printf "${BOLD}##                                                      ##${CLEARct}\\n"
	printf "${BOLD}##         https://github.com/AMTM-OSR/YazDHCP          ##${CLEARct}\\n"
	printf "${BOLD}##    Forked from https://github.com/jackyaz/YazDHCP    ##${CLEARct}\\n"
	printf "${BOLD}##                                                      ##${CLEARct}\\n"
	printf "${BOLD}##########################################################${CLEARct}\\n"
	printf "\n"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jun-27] ##
##----------------------------------------##
MainMenu()
{
	printf "1.    Process ${GRNct}${SCRIPT_CONF}${CLRct}\n\n"

	if CheckForCustomIconFiles || CheckForSavedIconFiles
	then
		printf "2.    Save/Restore custom user icons found in the ${GRNct}${userIconsDIRpath}${CLRct} directory.\n\n"
	fi

	showexport="true"
	if [ "$(nvram get dhcp_staticlist | wc -m)" -le 1 ]; then
		showexport="false"
	fi
	if [ "$(Firmware_Version_Number "$fwInstalledBranchVer")" -lt "$(Firmware_Version_Number "3004.386.4")" ]
	then
		if [ -f /jffs/nvram/dhcp_hostnames ]; then
			if [ "$(wc -m < /jffs/nvram/dhcp_hostnames)" -le 1 ]; then
				showexport="false"
			fi
		elif [ "$(nvram get dhcp_hostnames | wc -m)" -le 1 ]; then
			showexport="false"
		fi
	fi
	if [ "$showexport" = "true" ]; then
		printf "x.    Export DHCP assignments from NVRAM to %s\n\n" "$SCRIPT_NAME"
	fi
	printf "u.    Check for updates\\n"
	printf "uf.   Update %s with latest version (force update)\n\n" "$SCRIPT_NAME"
	printf "e.    Exit %s\\n\\n" "$SCRIPT_NAME"
	printf "z.    Uninstall %s\\n" "$SCRIPT_NAME"
	printf "\n"
	printf "${BOLD}##########################################################${CLEARct}\\n"
	printf "\n"

	while true; do
		printf "Choose an option:    "
		read -r menu
		case "$menu" in
			1)
				printf "\\n"
				if Check_Lock menu; then
					Menu_ProcessDHCPClients
				fi
				PressEnter
				break
			;;
			2)
				if "$iconsFound" || "$backupsFound"
				then
					printf "\n"
					if Check_Lock menu; then
						Menu_CustomUserIconsOps
					else
						PressEnter
					fi
					break
				else
					printf "\nPlease choose a valid option\n\n"
				fi
			;;
			x)
				if "$showexport"
				then
					printf "\\n"
					if Check_Lock menu; then
						Export_FW_DHCP_JFFS
					fi
					PressEnter
					break
				else
					printf "\nPlease choose a valid option\n\n"
				fi
			;;
			u)
				printf "\\n"
				if Check_Lock menu; then
					Menu_Update
				fi
				PressEnter
				break
			;;
			uf)
				printf "\\n"
				if Check_Lock menu; then
					Menu_ForceUpdate
				fi
				PressEnter
				break
			;;
			e)
				ScriptHeader
				printf "\\n${BOLD}Thanks for using %s!${CLEARct}\\n\\n\\n" "$SCRIPT_NAME"
				exit 0
			;;
			z)
				while true; do
					printf "\\n${BOLD}Are you sure you want to uninstall %s? (y/n)${CLEARct}\\n" "$SCRIPT_NAME"
					read -r confirm
					case "$confirm" in
						y|Y)
							Menu_Uninstall
							exit 0
						;;
						*)
							break
						;;
					esac
				done
				break
			;;
			*)
				printf "\nPlease choose a valid option\n\n"
			;;
		esac
	done

	ScriptHeader
	MainMenu
}

##----------------------------------------##
## Modified by Martinski W. [2025-Mar-16] ##
##----------------------------------------##
Menu_Install()
{
	ScriptHeader
	Print_Output true "Welcome to $SCRIPT_NAME $SCRIPT_VERSION, a script by JackYaz" "$PASS"
	sleep 1

	Print_Output true "Checking if your router meets the requirements for $SCRIPT_NAME" "$PASS"

	if ! Check_Requirements
	then
		Print_Output true "Requirements for $SCRIPT_NAME not met, please see above for the reason(s)" "$CRIT"
		PressEnter
		Clear_Lock
		rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
		exit 1
	fi

	Create_Dirs
	Set_Version_Custom_Settings local
	Set_Version_Custom_Settings server "$SCRIPT_VERSION"
	Create_Symlinks

	httpStr="https"
	portStr=":$(nvram get https_lanport)"

	if [ "$(nvram get http_enable)" -eq 0 ]
	then
		httpStr="http"
		portStr=""
	fi
	printf "%s will backup NVRAM/JFFS DHCP data as part of the export,\nbut you may wish to screenshot the following WebUI page:" "$SCRIPT_NAME"
	printf "\n\n${GRNct}%s://%s%s/Advanced_DHCP_Content.asp${CLEARct}\n" "$httpStr" "$(nvram get lan_ipaddr)" "$portStr"
	printf "\n${BOLD}If you wish to screenshot, please do so now before the WebUI page is updated by %s${CLEARct}.\n" "$SCRIPT_NAME"
	printf "\n${BOLD}Press the <Enter> key when you are ready to continue...${CLEARct}\n"
	while true
	do
		read -rs key
		case "$key" in
			*) break ;;
		esac
	done

	Update_File Advanced_DHCP_Content.asp
	Update_File shared-jy.tar.gz
	Auto_Startup create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Auto_DNSMASQ create 2>/dev/null
	Shortcut_Script create

	echo "MAC,IP,HOSTNAME,DNS" > "$SCRIPT_CONF"

	Export_FW_DHCP_JFFS

	Print_Output true "$SCRIPT_NAME installed successfully!" "$PASS"

	Clear_Lock
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-26] ##
##----------------------------------------##
Menu_ProcessDHCPClients()
{
	if ProcessDHCPClients
	then service restart_dnsmasq >/dev/null 2>&1 ; fi
	Clear_Lock
}

##----------------------------------------##
## Modified by Martinski W. [2023-Jun-16] ##
##----------------------------------------##
Menu_Startup()
{
	inStartupMode=true
	Create_Dirs
	Set_Version_Custom_Settings "local"
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Auto_DNSMASQ create 2>/dev/null
	Shortcut_Script create
	Mount_WebUI
	Clear_Lock
}

Menu_Update(){
	Update_Version
	Clear_Lock
}

Menu_ForceUpdate(){
	Update_Version force
	Clear_Lock
}

##----------------------------------------##
## Modified by Martinski W. [2023-May-28] ##
##----------------------------------------##
Menu_Uninstall()
{
	Print_Output true "Removing $SCRIPT_NAME..." "$PASS"
	Auto_Startup delete 2>/dev/null
	Auto_ServiceEvent delete 2>/dev/null
	Auto_DNSMASQ delete 2>/dev/null
	Shortcut_Script delete
	umount /www/Advanced_DHCP_Content.asp 2>/dev/null
	rm -f "$SCRIPT_DIR/Advanced_DHCP_Content.asp"

	commitNVRAM=false
	max7daySecs=604800
	if [ "$(nvram get $DHCP_LEASE_KEYN)" -gt "$max7daySecs" ]
	then # Reset NVRAM variable to WebGUI maximum secs #
		nvram set ${DHCP_LEASE_KEYN}="$max7daySecs"
		commitNVRAM=true
	fi

	printf "\\n${BOLD}Do you want to restore the original NVRAM values from before %s was installed? (y/n):    ${CLEARct}" "$SCRIPT_NAME"
	read -r confirm
	case "$confirm" in
		y|Y)
			if [ -f "$SCRIPT_DIR/.nvram_jffs_dhcp_staticlist" ]; then
				nvram set dhcp_staticlist="$(cat "$SCRIPT_DIR/.nvram_jffs_dhcp_staticlist")"
				commitNVRAM=true
			fi

			if [ -f "$SCRIPT_DIR/.nvram_jffs_dhcp_hostnames" ]; then
				nvram set dhcp_hostnames="$(cat "$SCRIPT_DIR/.nvram_jffs_dhcp_hostnames")"
				commitNVRAM=true
			fi

			if [ -f "$SCRIPT_DIR/.nvram_dhcp_staticlist" ]; then
				nvram set dhcp_staticlist="$(cat "$SCRIPT_DIR/.nvram_dhcp_staticlist")"
				commitNVRAM=true
			fi

			if [ -f "$SCRIPT_DIR/.nvram_dhcp_hostnames" ]; then
				nvram set dhcp_hostnames="$(cat "$SCRIPT_DIR/.nvram_dhcp_hostnames")"
				commitNVRAM=true
			fi
		;;
		*)
			:
		;;
	esac
	if "$commitNVRAM" ; then nvram commit ; fi

	printf "\\n${BOLD}Do you want to delete %s DHCP clients and NVRAM backup files? (y/n):    ${CLEARct}" "$SCRIPT_NAME"
	read -r confirm
	case "$confirm" in
		y|Y)
			rm -rf "$SCRIPT_DIR" 2>/dev/null
		;;
		*)
			:
		;;
	esac

	rm -rf "$SCRIPT_WEB_DIR" 2>/dev/null
	rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
	Clear_Lock
	Print_Output true "Uninstall completed" "$PASS"

	if "$commitNVRAM"
	then
		Print_Output true "Restarting dnsmasq to restore DHCP settings." "$PASS"
		service restart_dnsmasq >/dev/null 2>&1
	fi
}

Check_Requirements()
{
	CHECKSFAILED="false"

	if [ "$(nvram get jffs2_scripts)" -ne 1 ]
	then
		nvram set jffs2_scripts=1
		nvram commit
		Print_Output true "Custom JFFS Scripts enabled" "$WARN"
	fi

	if ! Firmware_Version_Check
	then
		Print_Output true "Unsupported firmware version detected" "$ERR"
		Print_Output true "$SCRIPT_NAME requires Merlin 384.15/384.13_4 or Fork 43E5 (or later)" "$ERR"
		CHECKSFAILED="true"
	fi

	if [ "$CHECKSFAILED" = "false" ]; then
		return 0
	else
		return 1
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Jul-20] ##
##-------------------------------------##
Show_Help()
{
	printf "HELP ${MGNTct}${SCRIPT_VERS_INFO}${CLRct}\n"
	cat <<EOF
Available commands:
  $SCRIPT_NAME about            explains functionality
  $SCRIPT_NAME update           checks for updates
  $SCRIPT_NAME forceupdate      updates to latest version (force update)
  $SCRIPT_NAME startup force    runs startup actions such as mount WebUI tab
  $SCRIPT_NAME backupicons      backs up custom user icons from '/jffs/usericon/'
  $SCRIPT_NAME restoreicons     restores custom user icons to '/jffs/usericon/'
  $SCRIPT_NAME install          installs script
  $SCRIPT_NAME uninstall        uninstalls script
  $SCRIPT_NAME develop          switch to development branch version
  $SCRIPT_NAME stable           switch to stable/production branch version
EOF
	printf "\n"
}

##-------------------------------------##
## Added by Martinski W. [2025-Jul-20] ##
##-------------------------------------##
Show_About()
{
	printf "About ${MGNTct}${SCRIPT_VERS_INFO}${CLRct}\n"
	cat <<EOF
  $SCRIPT_NAME is a feature expansion of the manual DHCP IP assignments on
  AsusWRT-Merlin firmware to read and write DHCP IP address reservations,
  including optional hostname and DNS server, and to increase the limit
  of the maximum number of manually assigned reservations.

License
  $SCRIPT_NAME is free to use under the GNU General Public License
  version 3 (GPL-3.0) https://opensource.org/licenses/GPL-3.0

Help & Support
  https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=31

Source code
  https://github.com/AMTM-OSR/$SCRIPT_NAME
EOF
	printf "\n"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-26] ##
##----------------------------------------##
# Catch unexpected exit to release lock #
trap 'Clear_Lock; exit 10' EXIT HUP INT QUIT ABRT TERM

if [ "$SCRIPT_BRANCH" = "master" ]
then SCRIPT_VERS_INFO="[$branchx_TAG]"
else SCRIPT_VERS_INFO="[$version_TAG, $branchx_TAG]"
fi

if [ $# -eq 0 ] || [ -z "$1" ]
then
	Create_Dirs
	Set_Version_Custom_Settings local
	Create_Symlinks
	Auto_Startup create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	Auto_DNSMASQ create 2>/dev/null
	Shortcut_Script create
	_CheckFor_WebGUI_Page_
	ScriptHeader
	MainMenu
	exit 0
fi

case "$1" in
	install)
		Check_Lock
		Menu_Install
		exit 0
	;;
	startup)
		Check_Lock
		if [ $# -gt 1 ] && [ "$2" != "force" ]; then
			sleep 5
		fi
		Menu_Startup
		exit 0
	;;
	##----------------------------------------##
	## Modified by Martinski W. [2023-Apr-16] ##
	##----------------------------------------##
	service_event)
		if [ "$2" = "start" ]
		then
			case "$3" in
				"$SCRIPT_NAME")
						Conf_FromSettings
				;;
				"${SCRIPT_NAME}checkupdate")
						Update_Check
				;;
				"${SCRIPT_NAME}doupdate")
						Update_Version force unattended
				;;
				"${SCRIPT_NAME}checkIcons")
						CheckUserIconFiles
				;;
				"${SCRIPT_NAME}backupIcons")
						BackUpUserIconFiles
				;;
				"${SCRIPT_NAME}restoreIcons_reqList")
						GetSavedBackupFilesList
				;;
				"${SCRIPT_NAME}restoreIcons_reqNum_"*)
						RestoreUserIconFilesReq "$3"
				;;
			esac
		fi
		exit 0
	;;
	##----------------------------------------------##
	## Added/modified by Martinski W. [2023-Apr-15] ##
	##----------------------------------------------##
	backupicons)
		BackUpUserIconFiles
		exit 0
	;;
	restoreicons)
		option="$([ $# -gt 1 ] && [ "$2" = "true" ] && echo "$2" || echo false)"
		RestoreUserIconFiles "$option"
		exit 0
	;;
	update)
		Update_Version unattended
		exit 0
	;;
	forceupdate)
		Update_Version force unattended
		exit 0
	;;
	setversion)
		Set_Version_Custom_Settings local
		Set_Version_Custom_Settings server "$SCRIPT_VERSION"
		if [ -z "$2" ]; then
			exec "$0"
		fi
		exit 0
	;;
	checkupdate)
		Update_Check
		exit 0
	;;
	uninstall)
		Check_Lock
		Menu_Uninstall
		exit 0
	;;
	develop)
		SCRIPT_BRANCH="develop"
		SCRIPT_REPO="https://raw.githubusercontent.com/AMTM-OSR/$SCRIPT_NAME/$SCRIPT_BRANCH"
		Update_Version force
		exit 0
	;;
	stable)
		SCRIPT_BRANCH="master"
		SCRIPT_REPO="https://raw.githubusercontent.com/AMTM-OSR/$SCRIPT_NAME/$SCRIPT_BRANCH"
		Update_Version force
		exit 0
	;;
	about)
		ScriptHeader
		Show_About
		exit 0
	;;
	help)
		ScriptHeader
		Show_Help
		exit 0
	;;
	*)
		ScriptHeader
		Print_Output false "Parameter [$*] is NOT recognised." "$ERR"
		exit 1
	;;
esac
