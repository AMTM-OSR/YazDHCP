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
# Last Modified: 2025-Oct-11
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
readonly SCRIPT_VERSION="v1.2.0"
readonly SCRIPT_VERSTAG="25101102"
SCRIPT_BRANCH="master"
SCRIPT_REPO="https://raw.githubusercontent.com/AMTM-OSR/$SCRIPT_NAME/$SCRIPT_BRANCH"
readonly SCRIPT_DIR="/jffs/addons/$SCRIPT_NAME.d"
readonly SCRIPT_CONF="$SCRIPT_DIR/DHCP_clients"
readonly SCRIPT_WEBPAGE_DIR="$(readlink -f /www/user)"
readonly SCRIPT_WEB_DIR="$SCRIPT_WEBPAGE_DIR/$SCRIPT_NAME"
readonly SHARED_DIR="/jffs/addons/shared-jy"
readonly SHARED_REPO="https://raw.githubusercontent.com/AMTM-OSR/shared-jy/master"
readonly SHARED_WEB_DIR="$SCRIPT_WEBPAGE_DIR/shared-jy"
readonly SHARED_CUSTOM_CONFIG_NAME="custom_settings.txt"
readonly SHARED_CUSTOM_CONFIG_FILE="/jffs/addons/$SHARED_CUSTOM_CONFIG_NAME"
readonly SHARED_CUSTOM_CONFIG_BACKUP="${SCRIPT_DIR}/${SHARED_CUSTOM_CONFIG_NAME}.BKUP"

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
readonly branchxStr_TAG="[Branch: $SCRIPT_BRANCH]"
readonly versionDev_TAG="${SCRIPT_VERSION}_${SCRIPT_VERSTAG}"
readonly versionMod_TAG="$SCRIPT_VERSION on $ROUTER_MODEL"

# Give higher priority to built-in binaries #
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:$PATH"

### End of router environment variables ###

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
readonly mainLAN_IFname="$(nvram get lan_ifname)"
readonly mainLAN_IPaddr="$(nvram get lan_ipaddr)"
readonly mainNET_IPmask="$(nvram get lan_netmask)"
readonly wifiIFnameList="$(nvram get wl_ifnames)"

# For Guest Network Virtual Interfaces #
readonly guestNetIFaces0RegExp="(wl[0-3][.][1-3]|br[1-9][0-9]?)"
readonly guestNetIFaces1RegExp="${guestNetIFaces0RegExp}[[:blank:]]* Link encap:"
readonly guestNetIFaces2RegExp="dev[[:blank:]]* ${guestNetIFaces0RegExp}[[:blank:]]* proto kernel"

# MAC addresses #
readonly MACaddr_RegEx="([a-fA-F0-9]{2}([:][a-fA-F0-9]{2}){5})"

# IPv4 addresses #
readonly IPv4octet_RegEx="([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])"
readonly IPv4addrs_RegEx="${IPv4octet_RegEx}([.]$IPv4octet_RegEx){3}"
readonly IPv4privt1_RegEx="10([.]$IPv4octet_RegEx){3}"
readonly IPv4privt2_RegEx="192[.]168([.]$IPv4octet_RegEx){2}"
readonly IPv4privt3_RegEx="172[.](1[6-9]|2[0-9]|3[01])([.]$IPv4octet_RegEx){2}"
readonly IPv4privtx_RegEx="($IPv4privt1_RegEx|$IPv4privt2_RegEx|$IPv4privt3_RegEx)"

# NVRAM IP Address Reservations #
readonly NVRAM_3004_DHCPvar_RegExp="dhcp_staticlist=[<]?${MACaddr_RegEx}>.+"
readonly NVRAM_3006_DHCPvar_RegExp0="dhcpres[1-9][0-9]?_rl="
readonly NVRAM_3006_DHCPvar_RegExp1="${NVRAM_3006_DHCPvar_RegExp0}<${MACaddr_RegEx}>.+"

readonly addnDHCP_HostNames=false
readonly guestNetInfoJSfileName="GuestNetworkSubnetInfo.js"
readonly guestNetInfoJSfilePath="${SCRIPT_DIR}/$guestNetInfoJSfileName"
readonly dhcpGuestNetAllowVarKey="allowGuestNet_IPaddr_Reservations"
readonly dhcpGuestNetConfigFName="DHCP_GuestNetInfo.conf"
readonly dhcpGuestNetConfigFPath="${SCRIPT_DIR}/$dhcpGuestNetConfigFName"
readonly guestNetCheckJSfileName="GuestNetCheckStatus.js"
readonly guestNetCheckJSfilePath="${SCRIPT_WEB_DIR}/$guestNetCheckJSfileName"

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
readonly JFFS_Dir="/jffs"
readonly JFFS_Configs_Dir="/jffs/configs"
readonly userIconsDIRname="usericon"
readonly userIconsDIRpath="${JFFS_Dir}/$userIconsDIRname"
readonly userIconsSavedFLEextn="tar.gzip"
readonly userIconsSavedFLEname="CustomUserIcons"
readonly userIconsSavedDIRname="SavedUserIcons"
readonly userIconsSavedCFGname="CustomUserIconsConfig"
readonly userIconsSavedSTAname="CustomUserIconsStatus"
readonly defUserIconsBackupDir="/opt/var/$userIconsSavedDIRname"
readonly altUserIconsBackupDir="${JFFS_Configs_Dir}/$userIconsSavedDIRname"
readonly userIconsVarPrefix="Icons_"
readonly savedFileDateTimeStr="%Y-%m-%d_%H-%M-%S"
readonly NVRAM_Folder="${JFFS_Dir}/nvram"
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
readonly GRAYct="\e[0;37m"
readonly GRAYEDct="\e[0;30;47m"
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

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
# Remove all "color escape sequences" from the system log file entries #
_RemoveColorEscapeSequences_()
{
    if [ $# -eq 0 ] || [ -z "$1" ] ; then echo ; return 0 ; fi
    echo "$1" | sed 's/\\e\[[0-1]m//g; s/\\e\[[3-4][0-9]m//g; s/\\e\[[0-1];[3-4][0-9]m//g; s/\\e\[30;10[1-9]m//g; s/\\n/ /g'
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
# $1 = print to syslog, $2 = message to print, $3 = log level
Print_Output()
{
	local prioStr  prioNum  logMsg
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
		logMsg="$(_RemoveColorEscapeSequences_ "$2")"
		printf "$logMsg" | logger -t "${SCRIPT_NAME}_[$$]" -p $prioNum
	fi
	printf "${BOLD}${3}${2}${CLRct}\n"
	if [ $# -lt 4 ] || [ "$4" != "oneline" ]
	then echo ; fi
}

Firmware_Version_Check()
{
	if nvram get rc_support | grep -qF "am_addons"
	then return 0
	else return 1
	fi
}

### Code for this function courtesy of https://github.com/decoderman- credit to @thelonelycoder ###
FirmwareVersionNum()
{ echo "$1" | awk -F. '{ printf("%d%03d%03d%02d\n", $1,$2,$3,$4); }' ; }

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
			if [ $# -eq 0 ] || [ -z "$1" ]
			then
				exit 1
			else
				if [ "$1" = "webui" ]
				then
					_Update_GuestNetCheck_Status_ LOCKED
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

Clear_Lock()
{
	rm -f "/tmp/$SCRIPT_NAME.lock" 2>/dev/null
	return 0
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-07] ##
##-------------------------------------##
_GetFileSizeBytes_()
{
    if [ $# -eq 0 ] || [ -z "$1" ] || [ ! -s "$1" ]
    then echo 0 ; return 0
    fi
    ls -1l "$1" | awk -F ' ' '{print $3}'
}

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
   NVRAM_LeaseTime="$(nvram get "$DHCP_LEASE_KEYN")"

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

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
BackUpConfigSettings()
{
	if [ -f "$SHARED_CUSTOM_CONFIG_FILE" ]
	then
		cp -fp "$SHARED_CUSTOM_CONFIG_FILE" "$SHARED_CUSTOM_CONFIG_BACKUP"
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Conf_FromSettings()
{
	SETTINGSFILE="$SHARED_CUSTOM_CONFIG_FILE"
	TEMP_FILE="/tmp/yazdhcp_clients.tmp"
	PARSED_FILE="/tmp/yazdhcp_clients_parsed.tmp"

	if [ -f "$SETTINGSFILE" ]
	then
		if [ "$(grep -cE "^(yazdhcp_client|$YazDHCP_LEASEtag)" $SETTINGSFILE)" -gt 0 ]
		then
			Print_Output true "Updated DHCP information from WebUI found, merging into $SCRIPT_CONF" "$PASS"
			cp -a "$SCRIPT_CONF" "${SCRIPT_CONF}.bak"
			grep -E "^(yazdhcp_client|$YazDHCP_LEASEtag)" "$SETTINGSFILE" > "$TEMP_FILE"
			sed -i "s/^yazdhcp_//g;s/ /=/g" "$TEMP_FILE"
			DHCPCLIENTS=""
			while IFS='' read -r line || [ -n "$line" ]
			do
				if echo "$line" | grep -q "^${YazDHCP_LEASEtag}="
				then
					LEASE_VALUE="$(echo "$line" | cut -d'=' -f2)"
					sed -i "s/DHCP_LEASE=.*/DHCP_LEASE=$LEASE_VALUE/" "$SCRIPT_DHCP_LEASE_CONF"
					continue
				fi
				DHCPCLIENTS="${DHCPCLIENTS}$(echo "$line" | cut -d'=' -f2)"
			done < "$TEMP_FILE"

			echo "$DHCPCLIENTS" | sed 's/|/:/g;s/></\n/g;s/>/ /g;s/<//g' > "$PARSED_FILE"

			grep -E '^yazdhcp_Vers[LS]' "$SETTINGSFILE" > "$TEMP_FILE"
			sed -i "\\~yazdhcp_~d" "$SETTINGSFILE"
			sed -i "\\~${YazDHCP_LEASEtag}~d" "$SETTINGSFILE"
			mv -f "$SETTINGSFILE" "${SETTINGSFILE}.bak"
			cat "${SETTINGSFILE}.bak" "$TEMP_FILE" > "$SETTINGSFILE"
			rm -f "${SETTINGSFILE}.bak" "$TEMP_FILE"

			LAN_SUBNET="$(echo "$mainLAN_IPaddr" | cut -d'.' -f1-3)"
			RESTART_DNSMASQ=false
			DO_NVRAM_COMMIT=false

			echo "MAC,IP,HOSTNAME,DNS" > "$SCRIPT_CONF"

			while IFS='' read -r theLine || [ -n "$theLine" ]
			do
				theLine="$(Check_IPv4_AddressValue "$theLine")"
				if ! CheckAgainstNVRAMvar "$theLine"
				then DO_NVRAM_COMMIT=true
				fi
				if [ "$(echo "$theLine" | wc -w)" -eq 4 ]
				then
					echo "$theLine" | awk -F' ' '{ print ""$1","$2","$3","$4""; }' >> "$SCRIPT_CONF"
				elif [ "$(echo "$theLine" | wc -w)" -gt 1 ]
				then
					if [ "$(echo "$theLine" | cut -d " " -f3 | wc -L)" -eq 0 ]
					then
						echo "$theLine" | awk -F' ' '{ print ""$1","$2","","$3""; }' >> "$SCRIPT_CONF"
					else
						printf "%s,\n" "$(echo "$theLine" | sed 's/ /,/g')" >> "$SCRIPT_CONF"
					fi
				fi
			done < "$PARSED_FILE"

			cp -fp "$SCRIPT_CONF" "${SCRIPT_CONF}.tmp"
			sort -t . -k 3,3n -k 4,4n "${SCRIPT_CONF}.tmp" > "$SCRIPT_CONF"
			rm -f "${SCRIPT_CONF}.tmp" "$PARSED_FILE"

			if [ -s "${SCRIPT_CONF}.bak" ] && \
			   ! diff "$SCRIPT_CONF" "${SCRIPT_CONF}.bak" >/dev/null 2>&1
			then RESTART_DNSMASQ=true
			else RESTART_DNSMASQ="$DO_NVRAM_COMMIT"
			fi
			Process_DHCP_Clients

			Check_DHCP_LeaseTime
			if "$DO_NVRAM_COMMIT" ; then nvram commit ; fi

			Print_Output true "Merge of updated DHCP client information from WebUI completed successfully" "$PASS"

			if "$RESTART_DNSMASQ"
			then
				Print_Output true "Restarting dnsmasq for new DHCP settings to take effect." "$PASS"
				## Delay restarting dnsmasq until the one from WebGUI is completed ##
				(sleep 3 ; service restart_dnsmasq >/dev/null 2>&1) &
			fi
		else
			Print_Output false "No updated DHCP information from WebUI found, no merge into $SCRIPT_CONF necessary" "$PASS"
		fi
		if [ -s "$SHARED_CUSTOM_CONFIG_BACKUP" ]
		then
			mv -f "$SHARED_CUSTOM_CONFIG_BACKUP" "$SHARED_CUSTOM_CONFIG_FILE"
		fi
		rm -f "$SHARED_CUSTOM_CONFIG_BACKUP"
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Set_Version_Custom_Settings()
{
	SETTINGSFILE="$SHARED_CUSTOM_CONFIG_FILE"
	case "$1" in
		local)
			if [ -s "$SETTINGSFILE" ]
			then
				if [ "$(grep -c "^yazdhcp_version_local" "$SETTINGSFILE")" -gt 0 ]
				then
					sed -i "s/^yazdhcp_version_local/yazdhcp_VersLocal/" "$SETTINGSFILE"
				fi
				if [ "$(grep -c "^yazdhcp_version_server" "$SETTINGSFILE")" -gt 0 ]
				then
					sed -i "s/^yazdhcp_version_server/yazdhcp_VersServer/" "$SETTINGSFILE"
				fi
				if [ "$(grep -c "^yazdhcp_VersLocal" "$SETTINGSFILE")" -gt 0 ]
				then
					if [ "$SCRIPT_VERSION" != "$(grep "^yazdhcp_VersLocal" "$SETTINGSFILE" | cut -d' ' -f2)" ]
					then
						sed -i "s/^yazdhcp_VersLocal.*/yazdhcp_VersLocal $SCRIPT_VERSION/" "$SETTINGSFILE"
					fi
				else
					echo "yazdhcp_VersLocal $SCRIPT_VERSION" >> "$SETTINGSFILE"
				fi
			else
				echo "yazdhcp_VersLocal $SCRIPT_VERSION" >> "$SETTINGSFILE"
			fi
		;;
		server)
			if [ -s "$SETTINGSFILE" ]
			then
				if [ "$(grep -c "^yazdhcp_version_server" "$SETTINGSFILE")" -gt 0 ]
				then
					sed -i "s/^yazdhcp_version_server/yazdhcp_VersServer/" "$SETTINGSFILE"
				fi
				if [ "$(grep -c "^yazdhcp_VersServer" "$SETTINGSFILE")" -gt 0 ]
				then
					if [ "$2" != "$(grep "^yazdhcp_VersServer" "$SETTINGSFILE" | cut -d' ' -f2)" ]
					then
						sed -i "s/^yazdhcp_VersServer.*/yazdhcp_VersServer $2/" "$SETTINGSFILE"
					fi
				else
					echo "yazdhcp_VersServer $2" >> "$SETTINGSFILE"
				fi
			else
				echo "yazdhcp_VersServer $2" >> "$SETTINGSFILE"
			fi
		;;
		delete)
			if [ -s "$SETTINGSFILE" ]
			then
				sed -i '/yazdhcp_VersLocal/d' "$SETTINGSFILE"
				sed -i '/yazdhcp_VersServer/d' "$SETTINGSFILE"
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Download_File()
{
	if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
	then return 1
	fi
	local tempFilePathDL="${2}.DWLD.TMP"

	curl -LSs --retry 4 --retry-delay 5 --retry-connrefused \
	     "$1" -o "$tempFilePathDL"
	if [ $? -ne 0 ] || [ ! -s "$tempFilePathDL" ] || \
	   grep -iq "^404: Not Found" "$tempFilePathDL"
	then
		Print_Output true "**ERROR**: Unable to download file [$2] for $SCRIPT_NAME." "$ERR"
		rm -f "$tempFilePathDL"
		return 1
	else
		mv -f "$tempFilePathDL" "$2"
		return 0
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Mar-16] ##
##----------------------------------------##
Update_Check()
{
	echo 'var updatestatus = "InProgress";' > "$SCRIPT_WEB_DIR/detect_update.js"
	doupdate="false"
	localVer="$(grep "SCRIPT_VERSION=" /jffs/scripts/"$SCRIPT_NAME" | grep -m1 -oE "$scriptVersRegExp")"
	curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep -qF "jackyaz" || \
	{ Print_Output true "404 error detected - stopping update" "$ERR" ; return 1 ; }
	serverVer="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE "$scriptVersRegExp")"
	if [ "$localVer" != "$serverVer" ]
	then
		doupdate="version"
		Set_Version_Custom_Settings server "$serverVer"
		echo 'var updatestatus = "'"$serverVer"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
	else
		localmd5="$(md5sum "/jffs/scripts/$SCRIPT_NAME" | awk '{print $1}')"
		remotemd5="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | md5sum | awk '{print $1}')"
		if [ "$localmd5" != "$remotemd5" ]
		then
			doupdate="md5"
			Set_Version_Custom_Settings server "${serverVer}-hotfix"
			echo 'var updatestatus = "'"${serverVer}-hotfix"'";'  > "$SCRIPT_WEB_DIR/detect_update.js"
		fi
	fi
	if [ "$doupdate" = "false" ]; then
		echo 'var updatestatus = "None";' > "$SCRIPT_WEB_DIR/detect_update.js"
	fi
	echo "$doupdate,$localVer,$serverVer"
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
		localVer="$(echo "$updatecheckresult" | cut -f2 -d',')"
		serverVer="$(echo "$updatecheckresult" | cut -f3 -d',')"

		if [ "$isupdate" = "version" ]
		then
			Print_Output true "New version of $SCRIPT_NAME available - updating to $serverVer" "$PASS"
		elif [ "$isupdate" = "md5" ]
		then
			Print_Output true "MD5 hash of $SCRIPT_NAME does not match - downloading updated $serverVer" "$PASS"
		fi

		Update_File shared-jy.tar.gz

		if [ "$isupdate" != "false" ]
		then
			Update_File Advanced_DHCP_Content.asp

			Download_File "$SCRIPT_REPO/$SCRIPT_NAME.sh" "/jffs/scripts/$SCRIPT_NAME" && \
			Print_Output true "$SCRIPT_NAME successfully updated" "$PASS"
			[ -s "/jffs/scripts/$SCRIPT_NAME" ] && chmod 0755 "/jffs/scripts/$SCRIPT_NAME"
			Clear_Lock
			if [ $# -eq 0 ] || [ -z "$1" ]
			then
				exec "$0" setversion
			elif [ "$1" = "unattended" ]
			then
				exec "$0" setversion unattended
			fi
			exit 0
		else
			Print_Output true "No new version - latest is $localVer" "$WARN"
			Clear_Lock
		fi
	fi

	if [ $# -gt 0 ] && [ "$1" = "force" ]
	then
		serverVer="$(curl -fsL --retry 4 --retry-delay 5 "$SCRIPT_REPO/$SCRIPT_NAME.sh" | grep "SCRIPT_VERSION=" | grep -m1 -oE "$scriptVersRegExp")"
		Print_Output true "Downloading latest version ($serverVer) of $SCRIPT_NAME" "$PASS"
		Update_File Advanced_DHCP_Content.asp
		Update_File shared-jy.tar.gz
		Download_File "$SCRIPT_REPO/$SCRIPT_NAME.sh" "/jffs/scripts/$SCRIPT_NAME" && \
		Print_Output true "$SCRIPT_NAME successfully updated" "$PASS"
		[ -s "/jffs/scripts/$SCRIPT_NAME" ] && chmod 0755 "/jffs/scripts/$SCRIPT_NAME"
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
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Update_File()
{
	if [ "$1" = "Advanced_DHCP_Content.asp" ]
	then
		webUIupdateOK=true
		local tmpfile="/tmp/$1"
		if [ -f "$SCRIPT_DIR/$1" ]
		then
			Download_File "$SCRIPT_REPO/$1" "$tmpfile"
			if ! diff -q "$tmpfile" "$SCRIPT_DIR/$1" >/dev/null 2>&1
			then
				Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1" && \
				Print_Output true "New version of $1 downloaded" "$PASS"
				Mount_WebUI
			fi
			rm -f "$tmpfile"
		else
			Download_File "$SCRIPT_REPO/$1" "$SCRIPT_DIR/$1" && \
			Print_Output true "New version of $1 downloaded" "$PASS"
			Mount_WebUI
		fi
	elif [ "$1" = "shared-jy.tar.gz" ]
	then
		if [ ! -f "$SHARED_DIR/${1}.md5" ]
		then
			Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
			Download_File "$SHARED_REPO/${1}.md5" "$SHARED_DIR/${1}.md5"
			tar -xzf "$SHARED_DIR/$1" -C "$SHARED_DIR"
			rm -f "$SHARED_DIR/$1"
			Print_Output true "New version of $1 downloaded" "$PASS"
		else
			localmd5="$(cat "$SHARED_DIR/${1}.md5")"
			remotemd5="$(curl -fsL --retry 4 --retry-delay 5 "$SHARED_REPO/${1}.md5")"
			if [ "$localmd5" != "$remotemd5" ]
			then
				Download_File "$SHARED_REPO/$1" "$SHARED_DIR/$1"
				Download_File "$SHARED_REPO/${1}.md5" "$SHARED_DIR/${1}.md5"
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

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_CheckForWirelessRadioEnabled_()
{
    local wifiRadioEnabled=false
    local wifiIFname  wifiRadioStatus

    if [ -z "$wifiIFnameList" ]
    then
        printf "\nWiFi Interface List *NOT* found.\n"
        return 1
    fi
    for wifiIFname in $wifiIFnameList
    do
        wifiRadioStatus="$(wl -i "$wifiIFname" bss 2>/dev/null)"
        if [ "$wifiRadioStatus" = "up" ]
        then
            wifiRadioEnabled=true
            break
        fi
    done
    "$wifiRadioEnabled" && return 0 || return 1
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Get_ActiveGuestNetwork_VirtualInterfaces_()
{
    local gnInfoStr1  gnInfoStr2  gnInfoNum1  gnInfoNum2
    gnListOfIFaces=""

    gnInfoStr1="$(ifconfig | grep -E "^$guestNetIFaces1RegExp")"
    gnInfoStr2="$(ip route show | grep -E "$guestNetIFaces2RegExp")"

    if ! _CheckForWirelessRadioEnabled_ && \
       [ "${#gnInfoStr1}" -eq 0 ] && [ "${#gnInfoStr2}" -eq 0 ]
    then return 1
    fi

    gnInfoNum1="$(echo "$gnInfoStr1" | wc -l)"
    gnInfoNum2="$(echo "$gnInfoStr2" | wc -l)"

    if [ "${#gnInfoStr1}" -gt 0 ] && \
       [ "${#gnInfoStr2}" -gt 0 ] && \
       [ "$gnInfoNum1" -eq "$gnInfoNum2" ]
    then
        gnListOfIFaces="$(echo "$gnInfoStr1" | awk -F' ' '{print $1}')"
    else
        gnListOfIFaces="$(echo "$gnInfoStr2" | awk -F' ' '{print $3}')"
    fi
    [ -n "$gnListOfIFaces" ] && return 0 || return 1
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Init_GuestNetworkAllow_VarsConfig_()
{
   echo "${dhcpGuestNetAllowVarKey}=false" > "$dhcpGuestNetConfigFPath"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Init_GuestNetCheck_Status_()
{
   echo "var guestNetCheckStatus = 'INIT';" > "$guestNetCheckJSfilePath"
}

##-------------------------------------##
## Added by Martinski W. [2025-Aug-30] ##
##-------------------------------------##
gnCheckCallLevel=0
gnCheckLastStatusID="INIT"

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Update_GuestNetCheck_Status_()
{
    if [ $# -eq 0 ] || [ -z "$1" ]
    then return 1
    fi
    if [ ! -s "$guestNetCheckJSfilePath" ]
    then
        _Init_GuestNetCheck_Status_
    fi

    case "$1" in
        DONE)
            [ "$gnCheckCallLevel" -gt 0 ] && \
            gnCheckCallLevel="$((gnCheckCallLevel - 1))"
            ;;
        InProgress)
            gnCheckCallLevel="$((gnCheckCallLevel + 1))"
            ;;
    esac

    if { [ "$1" = "DONE" ] && [ "$gnCheckCallLevel" -gt 0 ] ; } || \
       grep -qE "guestNetCheckStatus = '$1';" "$guestNetCheckJSfilePath" || \
       { [ "$1" = "INIT" ] && [ "$gnCheckLastStatusID" = "InProgress" ] ; }
    then return 0
    fi
    gnCheckLastStatusID="$1"
    echo "var guestNetCheckStatus = '$1';" > "$guestNetCheckJSfilePath"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Init_ActiveGuestNetwork_SubnetInfo_()
{
   {
      echo 'var foundActiveGuestNetworks = false;'
      echo 'var allowGuestNet_IP_Reservation = false;'
      echo 'var guestNetwork_SubnetInfoArray = [];' 
   } > "$guestNetInfoJSfilePath"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-06] ##
##-------------------------------------##
_Is_DHCP_Static_IPs_Enabled_()
{
   if [ "$(nvram get dhcp_static_x)" = "1" ]
   then
       echo "true" ; return 0
   else
       echo "false" ; return 1
   fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Set_FoundActiveGuestNetworks_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || \
      ! echo "$1" | grep -qE '^(true|false)$' || \
      [ ! -s "$guestNetInfoJSfilePath" ]
   then
       _Init_ActiveGuestNetwork_SubnetInfo_
       return 1
   fi

   if ! grep -qE '^var foundActiveGuestNetworks =' "$guestNetInfoJSfilePath"
   then
       sed -i "1 i var foundActiveGuestNetworks = ${1};" "$guestNetInfoJSfilePath"
   else
       sed -i "s/^var foundActiveGuestNetworks =.*/var foundActiveGuestNetworks = ${1};/" "$guestNetInfoJSfilePath"
   fi
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Set_AllowGuestNetwork_IP_Reservations_()
{
    if [ $# -eq 0 ] || [ -z "$1" ] || \
       ! echo "$1" | grep -qE '^(true|false)$' || \
       [ ! -s "$guestNetInfoJSfilePath" ]
    then
        _Init_ActiveGuestNetwork_SubnetInfo_
        return 1
    fi

    if ! grep -qE '^var allowGuestNet_IP_Reservation =' "$guestNetInfoJSfilePath"
    then
        sed -i "2 i var allowGuestNet_IP_Reservation = ${1};" "$guestNetInfoJSfilePath"
    else
        sed -i "s/^var allowGuestNet_IP_Reservation =.*/var allowGuestNet_IP_Reservation = ${1};/" "$guestNetInfoJSfilePath"
    fi

    if "$1"
    then _Check_ActiveGuestNetwork_SubnetInfo_
    fi
    return 0
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_AllowGuestNetwork_IP_Reservations_()
{
    if [ $# -eq 0 ] || [ -z "$1" ]
    then return 1
    fi
    local setVerboseMode=true  prevStatusFlag="NONE"

    [ "$1" != "check" ] && _Update_GuestNetCheck_Status_ INIT

    if [ $# -gt 1 ] && [ -n "$2" ] && \
       echo "$2" | grep -qE "^(true|false)$"
    then setVerboseMode="$2"
    fi

    if [ ! -s "$dhcpGuestNetConfigFPath" ] || \
       ! grep -qE "^${dhcpGuestNetAllowVarKey}=(true|false)$" "$dhcpGuestNetConfigFPath"
    then
        _Init_GuestNetworkAllow_VarsConfig_
    elif [ "$1" != "check" ]
    then
        prevStatusFlag="$(_AllowGuestNetwork_IP_Reservations_ check)"
    fi

    case "$1" in
        check)
            grep -E "^${dhcpGuestNetAllowVarKey}=.*" "$dhcpGuestNetConfigFPath" | cut -d'=' -f2
            ;;
        reset)
            echo "${dhcpGuestNetAllowVarKey}=false" > "$dhcpGuestNetConfigFPath"
            _Update_GuestNetCheck_Status_ InProgress
            _Set_AllowGuestNetwork_IP_Reservations_ false
            if [ "$prevStatusFlag" != "false" ] || \
               ! "$(_Is_DHCP_Static_IPs_Enabled_)"
            then Process_DHCP_Clients true
            fi
            _Update_GuestNetCheck_Status_ DONE
            ;;
        enable)
            sed -i "s/^${dhcpGuestNetAllowVarKey}=.*/${dhcpGuestNetAllowVarKey}=true/" "$dhcpGuestNetConfigFPath"
            _Update_GuestNetCheck_Status_ InProgress
            _Set_AllowGuestNetwork_IP_Reservations_ true
            if [ "$prevStatusFlag" != "true" ]
            then Process_DHCP_Clients true
            fi
            _Update_GuestNetCheck_Status_ DONE
            ;;
        disable)
            sed -i "s/^${dhcpGuestNetAllowVarKey}=.*/${dhcpGuestNetAllowVarKey}=false/" "$dhcpGuestNetConfigFPath"
            _Update_GuestNetCheck_Status_ InProgress
            _Set_AllowGuestNetwork_IP_Reservations_ false
            if [ "$prevStatusFlag" != "false" ] || \
               ! "$(_Is_DHCP_Static_IPs_Enabled_)"
            then Process_DHCP_Clients true
            fi
            _Update_GuestNetCheck_Status_ DONE
            ;;
    esac

    return 0
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Get_DHCP_NetworkTagStr_()
{
    if [ $# -eq 0 ] || [ -z "$1" ]
    then echo ; return 1
    fi
    local dnsmasqFileStr="/etc/dnsmasq.conf"  theIPaddr3
    local dhcpOptionStr  dhcpRangeStr  dhcpNoIFaceID

    if [ "$fwInstalledBaseVers" -ge 3006 ] && \
       { [ $# -lt 2 ] || [ "$2" != "MainLAN" ] ; }
    then dnsmasqFileStr="/etc/dnsmasq*.conf"
    fi
    dnsmasqIndxNum=""
    dhcpNetwkTagID=""
    theIPaddr3="$(echo "$1" | cut -d'.' -f1-3)"

    for dnsmasqFile in $(ls -1 $dnsmasqFileStr 2>/dev/null)
    do
        dhcpRangeStr="$(grep -E "^dhcp-range=.*,${theIPaddr3}[.].*," "$dnsmasqFile")"
        dhcpOptionStr="$(grep -E "^dhcp-option=.*,(3|option:router),$1" "$dnsmasqFile")"
        dhcpNoIFaceID="$(grep -E "^no-dhcp-interface=$2" "$dnsmasqFile")"
        if [ -z "$dhcpOptionStr" ] && [ -z "$dhcpRangeStr" ] && [ -z "$dhcpNoIFaceID" ]
        then continue
        fi
        if [ -n "$dhcpOptionStr" ]
        then
            dhcpNetwkTagID="$(echo "$dhcpOptionStr" | cut -d'=' -f2 | cut -d',' -f1)"
            if echo "$dhcpNetwkTagID" | grep -qE "^tag:.*"
            then
                dhcpNetwkTagID="$(echo "$dhcpNetwkTagID" | cut -d':' -f2)"
            fi
        fi
        if [ -z "$dhcpNetwkTagID" ] && [ -n "$dhcpRangeStr" ]
        then
            dhcpNetwkTagID="$(echo "$dhcpRangeStr" | cut -d'=' -f2 | cut -d',' -f1)"
            if echo "$dhcpNetwkTagID" | grep -qE "^set:.*"
            then
                dhcpNetwkTagID="$(echo "$dhcpNetwkTagID" | cut -d':' -f2)"
            fi
        fi
        if echo "$dnsmasqFile" | grep -qE '/etc/dnsmasq-[1-9][0-9]?.conf'
        then
            dnsmasqIndxNum="$(echo "$dnsmasqFile" | cut -d'-' -f2 | cut -d'.' -f1)"
        fi
        if [ -z "$dhcpNetwkTagID" ] && [ -n "$dhcpNoIFaceID" ]
        then
            [ "$fwInstalledBaseVers" -ge 3006 ] && \
            dhcpNetwkTagID="$(echo "$dhcpNoIFaceID" | cut -d'=' -f2)"
            ##OFF## dnsmasqIndxNum=ZERO  #*WITHOUT* DHCP Server??#
        fi
    done

    [ -z "$dhcpNetwkTagID" ] && dhcpNetwkTagID=NONE
    [ -z "$dnsmasqIndxNum" ] && dnsmasqIndxNum=ZERO
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Add_GuestNetwork_SubnetInfo_()
{
    local gnIFaceVarStr="GNIFACE_${gnIFaceName}"
    local gnIFaceInfoDef  dhcpNetwkTagID=NONE  dnsmasqIndxNum=ZERO

    _Get_DHCP_NetworkTagStr_ "$gnStartIPadd" "$gnIFaceName"
    gnIFaceInfoDef="${gnIFaceVarStr}=${gnStartIPadd},${gnSubnetMask},${gnSubnetCIDR},${dhcpNetwkTagID},${dnsmasqIndxNum}"

    if [ "$dhcpNetwkTagID" = "NONE" ] || \
       { [ "$fwInstalledBaseVers" -ge 3006 ] && [ "$dnsmasqIndxNum" = "ZERO" ] ; }
    then
        if grep -qE "^${gnIFaceVarStr}=.*" "$dhcpGuestNetConfigFPath" 
        then
            sed -i "/^${gnIFaceVarStr}=.*/d" "$dhcpGuestNetConfigFPath"
        fi
        return 1
    fi
    if grep -qE "^${gnIFaceInfoDef}$" "$dhcpGuestNetConfigFPath"
    then return 0
    fi
    if ! grep -qE "^${gnIFaceVarStr}=.*" "$dhcpGuestNetConfigFPath" 
    then
        echo "$gnIFaceInfoDef" >> "$dhcpGuestNetConfigFPath"
    else
        sed -i "s~^${gnIFaceVarStr}=.*~${gnIFaceInfoDef}~" "$dhcpGuestNetConfigFPath"
    fi
    return 0
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-06] ##
##-------------------------------------##
_Reset_GuestNetwork_SubnetInfo_()
{
    if [ ! -s "$dhcpGuestNetConfigFPath" ] || \
       ! grep -qE "^GNIFACE_${guestNetIFaces0RegExp}=" "$dhcpGuestNetConfigFPath"
    then return 0
    fi
    sed -i '/^GNIFACE_.*=.*/d' "$dhcpGuestNetConfigFPath"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Get_GuestNetwork_SubnetInfo_()
{
    if [ ! -s "$dhcpGuestNetConfigFPath" ] || \
       ! grep -qE "^GNIFACE_${guestNetIFaces0RegExp}=" "$dhcpGuestNetConfigFPath"
    then echo ; return 1
    fi
    grep -E "^GNIFACE_${guestNetIFaces0RegExp}=.*" "$dhcpGuestNetConfigFPath"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
Create_DHCP_GuestNetworkConfig()
{
    if [ ! -s "$dhcpGuestNetConfigFPath" ] || \
       ! grep -qE "^${dhcpGuestNetAllowVarKey}=(true|false)$" "$dhcpGuestNetConfigFPath"
    then
        _Init_GuestNetworkAllow_VarsConfig_
    fi
    if [ ! -s "$guestNetInfoJSfilePath" ]
    then
        _Init_ActiveGuestNetwork_SubnetInfo_
    fi
    if [ ! -s "$guestNetCheckJSfilePath" ]
    then
        _Init_GuestNetCheck_Status_
    fi
    ln -sf "$guestNetInfoJSfilePath" "${SCRIPT_WEB_DIR}/$guestNetInfoJSfileName" 2>/dev/null
}

##----------------------------------------##
## Modified by Martinski W. [2023-May-28] ##
##----------------------------------------##
Create_DHCP_LeaseConfig()
{
    Check_DHCP_LeaseTime && nvram commit
    ln -sf "$SCRIPT_DHCP_LEASE_CONF" "${SCRIPT_WEB_DIR}/${DHCP_LEASE_FILE}.htm" 2>/dev/null
}

##----------------------------------------##
## Modified by Martinski W. [2023-Apr-16] ##
##----------------------------------------##
Create_CustomUserIconsConfig()
{
    Check_CustomUserIconsConfig
    ln -sf "$SCRIPT_USER_ICONS_CONFIG" "${SCRIPT_WEB_DIR}/${userIconsSavedCFGname}.htm" 2>/dev/null
    ln -sf "$SCRIPT_USER_ICONS_STATUS" "${SCRIPT_WEB_DIR}/${userIconsSavedSTAname}.htm" 2>/dev/null
    ln -sf "$SCRIPT_USER_ICONS_BKPLST" "${SCRIPT_WEB_DIR}/${userIconsSavedBKPList}.htm" 2>/dev/null
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Create_Symlinks()
{
	rm -rf "${SCRIPT_WEB_DIR:?}/"* 2>/dev/null

	ln -s "$SCRIPT_CONF" "$SCRIPT_WEB_DIR/DHCP_clients.htm" 2>/dev/null
	Create_DHCP_LeaseConfig
	Create_CustomUserIconsConfig
	Create_DHCP_GuestNetworkConfig

	if [ ! -d "$SHARED_WEB_DIR" ]; then
		ln -s "$SHARED_DIR" "$SHARED_WEB_DIR" 2>/dev/null
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Aug-23] ##
##----------------------------------------##
Auto_ServiceEvent()
{
	local theScriptFilePath="/jffs/scripts/$SCRIPT_NAME"
	case "$1" in
		create)
			if [ -f /jffs/scripts/service-event ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)"
				STARTUPLINECOUNTEX="$(grep -cx 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'" || { \[ "$1" = "restart" \] && \[ "$2" = "wireless" \]; }; then { '"$theScriptFilePath"' service_event "$@" & }; fi # '"$SCRIPT_NAME" /jffs/scripts/service-event)"

				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]
				then
					{
					   echo 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'" || { [ "$1" = "restart" ] && [ "$2" = "wireless" ]; }; then { '"$theScriptFilePath"' service_event "$@" & }; fi # '"$SCRIPT_NAME"
					} >> /jffs/scripts/service-event
				fi
			else
				{
				   echo "#!/bin/sh" ; echo
				   echo 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'" || { [ "$1" = "restart" ] && [ "$2" = "wireless" ]; }; then { '"$theScriptFilePath"' service_event "$@" & }; fi # '"$SCRIPT_NAME"
				   echo
				} > /jffs/scripts/service-event
				chmod 0755 /jffs/scripts/service-event
			fi
		;;
		delete)
			if [ -f /jffs/scripts/service-event ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)"
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
			if [ -f /jffs/scripts/services-start ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)"
				STARTUPLINECOUNTEX="$(grep -cx "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME" /jffs/scripts/services-start)"

				if [ "$STARTUPLINECOUNT" -gt 1 ] || { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ]; }
				then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
				fi
			else
				{
				   echo "#!/bin/sh" ; echo
				   echo "/jffs/scripts/$SCRIPT_NAME startup"' "$@" & # '"$SCRIPT_NAME"
				   echo
				} > /jffs/scripts/services-start
				chmod 0755 /jffs/scripts/services-start
			fi
		;;
		delete)
			if [ -f /jffs/scripts/services-start ]
			then
				STARTUPLINECOUNT="$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)"
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
			fi
		;;
	esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Auto_DNSMASQ_Handler()
{
	if [ $# -eq 0 ] || [ -z "$1" ]
	then return 1
	fi
	local theCommenTagStr  configAddFileTEMP  configAddFileORIG
	configAddFileORIG="${configAddFilePath}.ORIG.BKUP"

	case $1 in
		create)
			configAddFileTEMP="${configAddFilePath}.TEMP.BKUP"

			if [ -s "$configAddFileORIG" ]
			then
				cp -fp "$configAddFileORIG" "$configAddFileTEMP"
				#---------------------------------------------------------------------------#
				theCommenTagStr="# $ADDN_HostsComntTag"
				STARTUPLINECOUNT="$(grep -c "$theCommenTagStr" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e "/${theCommenTagStr}/d" "$configAddFileORIG"
				fi
				theCommenTagStr="#${ADDN_HostsComntTag}#"
				STARTUPLINECOUNT="$(grep -c "$theCommenTagStr" "$configAddFileORIG")"
				STARTUPLINECOUNTEX="$(grep -cx "$ADDN_HostsDirctive" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNT" -gt 1 ] || \
				   { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; } || \
				   { [ ! -s "$ADDN_HostsFilePath" ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; }
				then
					sed -i -e "/${theCommenTagStr}/d" "$configAddFileORIG"
				fi
				STARTUPLINECOUNTEX="$(grep -cx "$ADDN_HostsDirctive" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ -s "$ADDN_HostsFilePath" ]
				then
					echo "$ADDN_HostsDirctive" >> "$configAddFileORIG"
					dnsmasqConfigCHANGED=true
				fi

				#---------------------------------------------------------------------------#
				theCommenTagStr="# $DHCP_HostsComntTag"
				STARTUPLINECOUNT="$(grep -c "$theCommenTagStr" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e "/${theCommenTagStr}/d" "$configAddFileORIG"
				fi
				theCommenTagStr="#${DHCP_HostsComntTag}#"
				STARTUPLINECOUNT="$(grep -c "$theCommenTagStr" "$configAddFileORIG")"
				STARTUPLINECOUNTEX="$(grep -cx "$DHCP_HostsDirctive" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNT" -gt 1 ] || \
				   { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; } || \
				   { [ ! -s "$DHCP_HostsFilePath" ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; }
				then
					sed -i -e "/${theCommenTagStr}/d" "$configAddFileORIG"
				fi
				STARTUPLINECOUNTEX="$(grep -cx "$DHCP_HostsDirctive" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ -s "$DHCP_HostsFilePath" ]
				then
					echo "$DHCP_HostsDirctive" >> "$configAddFileORIG"
					dnsmasqConfigCHANGED=true
				fi

				#---------------------------------------------------------------------------#
				theCommenTagStr="# $DHCP_OptnsComntTag"
				STARTUPLINECOUNT="$(grep -c "$theCommenTagStr" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e "/${theCommenTagStr}/d" "$configAddFileORIG"
				fi
				theCommenTagStr="#${DHCP_OptnsComntTag}#"
				STARTUPLINECOUNT="$(grep -c "$theCommenTagStr" "$configAddFileORIG")"
				STARTUPLINECOUNTEX="$(grep -cx "$DHCP_OptnsDirctive" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNT" -gt 1 ] || \
				   { [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; } || \
				   { [ ! -s "$DHCP_OptnsFilePath" ] && [ "$STARTUPLINECOUNT" -gt 0 ] ; }
				then
					sed -i -e "/${theCommenTagStr}/d" "$configAddFileORIG"
				fi
				STARTUPLINECOUNTEX="$(grep -cx "$DHCP_OptnsDirctive" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNTEX" -eq 0 ] && [ -s "$DHCP_OptnsFilePath" ]
				then
					echo "$DHCP_OptnsDirctive" >> "$configAddFileORIG"
					dnsmasqConfigCHANGED=true
				fi
				#---------------------------------------------------------------------------#
				if [ ! -s "$configAddFileORIG" ] || \
				   ! diff "$configAddFileTEMP" "$configAddFileORIG" >/dev/null 2>&1
				then
					dnsmasqConfigCHANGED=true
				fi
				[ -s "$configAddFileORIG" ] && \
				mv -f "$configAddFileORIG" "$configAddFilePath" 2>/dev/null
				rm -f "$configAddFileTEMP" "$configAddFileORIG"
			else
				{
				   [ -s "$ADDN_HostsFilePath" ] && echo "$ADDN_HostsDirctive"
				   [ -s "$DHCP_HostsFilePath" ] && echo "$DHCP_HostsDirctive"
				   [ -s "$DHCP_OptnsFilePath" ] && echo "$DHCP_OptnsDirctive"
				} > "$configAddFilePath"
				if [ -s "$configAddFilePath" ]
				then 
					dnsmasqConfigCHANGED=true
					chmod 0644 "$configAddFilePath"
				fi
			fi
			[ ! -s "$configAddFilePath" ] && rm -f "$configAddFilePath"
		;;
		delete)
			if [ -s "$configAddFileORIG" ]
			then
				theCommenTagStr="#${ADDN_HostsComntTag}#"
				STARTUPLINECOUNT="$(grep -c "$theCommenTagStr" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e "/${theCommenTagStr}/d" "$configAddFileORIG"
					dnsmasqConfigCHANGED=true
				fi
				theCommenTagStr="# $ADDN_HostsComntTag"
				STARTUPLINECOUNT="$(grep -c "$theCommenTagStr" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e "/${theCommenTagStr}/d" "$configAddFileORIG"
					dnsmasqConfigCHANGED=true
				fi

				#-------------------------------------------------------------------------#
				theCommenTagStr="#${DHCP_HostsComntTag}#"
				STARTUPLINECOUNT="$(grep -c "$theCommenTagStr" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e "/${theCommenTagStr}/d" "$configAddFileORIG"
					dnsmasqConfigCHANGED=true
				fi
				theCommenTagStr="# $DHCP_HostsComntTag"
				STARTUPLINECOUNT="$(grep -c "$theCommenTagStr" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e "/${theCommenTagStr}/d" "$configAddFileORIG"
					dnsmasqConfigCHANGED=true
				fi

				#-------------------------------------------------------------------------#
				theCommenTagStr="#${DHCP_OptnsComntTag}#"
				STARTUPLINECOUNT="$(grep -c "$theCommenTagStr" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e "/${theCommenTagStr}/d" "$configAddFileORIG"
					dnsmasqConfigCHANGED=true
				fi
				theCommenTagStr="# $DHCP_OptnsComntTag"
				STARTUPLINECOUNT="$(grep -c "$theCommenTagStr" "$configAddFileORIG")"
				if [ "$STARTUPLINECOUNT" -gt 0 ]
				then
					sed -i -e "/${theCommenTagStr}/d" "$configAddFileORIG"
					dnsmasqConfigCHANGED=true
				fi
				[ -s "$configAddFileORIG" ] && \
				mv -f "$configAddFileORIG" "$configAddFilePath" 2>/dev/null
				rm -f "$configAddFileORIG"
			fi
			[ ! -s "$configAddFilePath" ] && rm -f "$configAddFilePath"
		;;
	esac
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-13] ##
##-------------------------------------##
_SetUp_DNSMasqConfigAddFiles_()
{
    if [ "$fwInstalledBaseVers" -lt 3006 ]
    then return
    fi
    local configAddRegExp  configAddFPath  theFName

    configAddRegExp="${JFFS_Configs_Dir}/dnsmasq-*.conf.add"
    for configAddFPath in $(ls -1 $configAddRegExp 2>/dev/null)
    do
        theFName="$(basename "$configAddFPath")"
        if ! echo "$theFName" | grep -qE '^dnsmasq-[1-9]+[0-9]?.conf.add'
        then continue
        fi
        [ -s "$configAddFPath" ] && \
        mv -f "$configAddFPath" "${configAddFPath}.ORIG.BKUP"
        rm -f "$configAddFPath"
    done
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-14] ##
##-------------------------------------##
_CleanUp_DNSMasqConfigFiles_()
{
    if [ "$fwInstalledBaseVers" -lt 3006 ]
    then return
    fi
    local gnInfoStr  gnListOfIFaces  gnIFaceName
    local staticAddRegExp  optionAddRegExp  configAddPrefix
    local confAddFBKUP  configFName  configAddFile

    configAddPrefix="${JFFS_Configs_Dir}/dnsmasq-"
    staticAddRegExp="dhcp-hostsfile=${SCRIPT_DIR}/.staticlist_"
    optionAddRegExp="dhcp-optsfile=${SCRIPT_DIR}/.optionslist_"

    _MoveOrDeleteFile_()
    {
        if [ -n "$configAddFile" ] && \
           [ "$(_GetFileSizeBytes_ "$1")" -ge 3 ]
        then
            mv -f "$1" "$configAddFile"
        fi
        rm -f "$1"
    }

    for confAddFBKUP in $(ls -1 ${configAddPrefix}*.conf.add.ORIG.BKUP 2>/dev/null)
    do
        configFName="$(basename "$confAddFBKUP")"
        if ! echo "$configFName" | grep -qE '^dnsmasq-[1-9]+[0-9]?.conf.add.ORIG.BKUP'
        then continue
        fi
        configAddFile="$(echo "$confAddFBKUP" | grep -oE "${configAddPrefix}.*.conf.add")"
        if ! grep -qE "^($staticAddRegExp|$optionAddRegExp).*" "$confAddFBKUP"
        then
            _MoveOrDeleteFile_ "$confAddFBKUP"
            continue
        fi
        ## Remove unused YazDHCP custom lines ##
        sed -i "\\~^${staticAddRegExp}.*~d" "$confAddFBKUP"
        sed -i "\\~^${optionAddRegExp}.*~d" "$confAddFBKUP"
        _MoveOrDeleteFile_ "$confAddFBKUP"
        dnsmasqConfigCHANGED=true
    done

    gnInfoStr="$(_Get_GuestNetwork_SubnetInfo_)"
    if [ "${#gnInfoStr}" -eq 0 ]
    then return 1
    fi
    gnListOfIFaces="$(echo "$gnInfoStr" | cut -d'=' -f1 | cut -d'_' -f2)"
    if [ -z "$gnListOfIFaces" ]
    then return 1
    fi

    for configFPATH in $(ls -1 /etc/dnsmasq-*.conf 2>/dev/null)
    do
        configFName="$(basename "$configFPATH")"
        if ! echo "$configFName" | grep -qE '^dnsmasq-[1-9]+[0-9]?.conf'
        then continue
        fi
        configAddFile="${JFFS_Configs_Dir}/${configFName}.add"
        if [ ! -s "$configAddFile" ] || \
           ! grep -qE "^($staticAddRegExp|$optionAddRegExp).*" "$configAddFile"
        then
            ## Remove unused YazDHCP custom lines ##
            sed -i "\\~^${staticAddRegExp}.*~d" "$configFPATH"
            sed -i "\\~^${optionAddRegExp}.*~d" "$configFPATH"
            continue
        fi
        isConfigAddFileOK=false
        for gnIFaceName in $gnListOfIFaces
        do
            if grep -qE "^($staticAddRegExp|$optionAddRegExp)$gnIFaceName #" "$configAddFile"
            then
                isConfigAddFileOK=true ; break
            fi
        done
        "$isConfigAddFileOK" && continue
        ## Remove unused YazDHCP custom lines ##
        sed -i "\\~^${staticAddRegExp}.*~d" "$configFPATH"
        sed -i "\\~^${optionAddRegExp}.*~d" "$configFPATH"
        dnsmasqConfigCHANGED=true
    done
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-14] ##
##----------------------------------------##
Auto_DNSMASQ()
{
	if [ $# -eq 0 ] || [ -z "$1" ]
	then return 1
	fi
	local doIFaceAction  doIFaceDel
	local gnInfoStr  gnListOfIFaces  gnIFaceVarStr
	local gnIFaceName  gnNetwrkTagID  gnNetIndexNum
	local configAddFilePath  dnsmasqConfigCHANGED  dnsmasqRESTART
	local ADDN_HostsComntTag  ADDN_HostsFilePath  ADDN_HostsDirctive
	local DHCP_HostsComntTag  DHCP_HostsFilePath  DHCP_HostsDirctive
	local DHCP_OptnsComntTag  DHCP_OptnsFilePath  DHCP_OptnsDirctive

	if [ $# -gt 1 ] && [ "$2" = "true" ]
	then dnsmasqRESTART=true
	else dnsmasqRESTART=false
	fi
	doIFaceAction="$1"
	dnsmasqConfigCHANGED=false

	_Restart_DNSMASQ_()
	{
		if "$dnsmasqConfigCHANGED" || "$dnsmasqRESTART"
		then
			Print_Output true "Restarting dnsmasq for new DHCP settings to take effect." "$WARN"
			service restart_dnsmasq >/dev/null 2>&1
		fi
	}

	if ! "$(_Is_DHCP_Static_IPs_Enabled_)"
	then doIFaceDel=true
	else doIFaceDel=false
	fi

	if [ "$1" = "create" ] && "$doIFaceDel"
	then doIFaceAction=delete
	fi

	#----------#
	# Main LAN #
	#----------#
	configAddFilePath="${JFFS_Configs_Dir}/dnsmasq.conf.add"

	#----------------#
	# DHCP Hostnames #
	#----------------#
	ADDN_HostsFilePath="$SCRIPT_DIR/.hostnames"
	ADDN_HostsComntTag="${SCRIPT_NAME}_hostnames"
	ADDN_HostsDirctive="addn-hosts=$ADDN_HostsFilePath #${ADDN_HostsComntTag}#"
	if ! "$addnDHCP_HostNames" || "$doIFaceDel"
	then rm -f "$ADDN_HostsFilePath"
	fi
	#-----------------------------------------#
	# DHCP Hosts with IP Address Reservations #
	#-----------------------------------------#
	DHCP_HostsFilePath="$SCRIPT_DIR/.staticlist"
	DHCP_HostsComntTag="${SCRIPT_NAME}_staticlist"
	DHCP_HostsDirctive="dhcp-hostsfile=$DHCP_HostsFilePath #${DHCP_HostsComntTag}#"
	if "$doIFaceDel"
	then rm -f "$DHCP_HostsFilePath"
	fi
	#--------------#
	# DHCP Options #
	#--------------#
	DHCP_OptnsFilePath="$SCRIPT_DIR/.optionslist"
	DHCP_OptnsComntTag="${SCRIPT_NAME}_optionslist"
	DHCP_OptnsDirctive="dhcp-optsfile=$DHCP_OptnsFilePath #${DHCP_OptnsComntTag}#"
	if "$doIFaceDel"
	then rm -f "$DHCP_OptnsFilePath"
	fi

	[ -s "$configAddFilePath" ] && \
	mv -f "$configAddFilePath" "${configAddFilePath}.ORIG.BKUP"
	rm -f "$configAddFilePath"

	Auto_DNSMASQ_Handler "$doIFaceAction"

	if [ "$fwInstalledBaseVers" -lt 3006 ]
	then
		_Restart_DNSMASQ_
		return 0
	fi

	gnInfoStr="$(_Get_GuestNetwork_SubnetInfo_)"
	if [ "${#gnInfoStr}" -eq 0 ]
	then
		_Restart_DNSMASQ_
		return 0
	fi
	gnListOfIFaces="$(echo "$gnInfoStr" | cut -d'=' -f1 | cut -d'_' -f2)"
	if [ -z "$gnListOfIFaces" ]
	then
		_Restart_DNSMASQ_
		return 0
	fi

	if ! "$(_Is_DHCP_Static_IPs_Enabled_)" || \
	   ! "$(_AllowGuestNetwork_IP_Reservations_ check)"
	then doIFaceDel=true
	else doIFaceDel=false
	fi
	if [ "$1" = "create" ] && "$doIFaceDel"
	then doIFaceAction=delete
	fi

	#----------------#
	# Guest Networks #
	#----------------#
	_SetUp_DNSMasqConfigAddFiles_

	for gnIFaceName in $gnListOfIFaces
	do
		ADDN_HostsFilePath="$SCRIPT_DIR/.hostnames_$gnIFaceName"
		DHCP_HostsFilePath="$SCRIPT_DIR/.staticlist_$gnIFaceName"
		DHCP_OptnsFilePath="$SCRIPT_DIR/.optionslist_$gnIFaceName"

		# Get dnsmasq instance number #
		gnIFaceVarStr="GNIFACE_${gnIFaceName}="
		gnNetwrkTagID="$(echo "$gnInfoStr" | grep -E "^${gnIFaceVarStr}.*" | cut -d'=' -f2 | cut -d',' -f4)"
		gnNetIndexNum="$(echo "$gnInfoStr" | grep -E "^${gnIFaceVarStr}.*" | cut -d'=' -f2 | cut -d',' -f5)"
		if [ -z "$gnNetIndexNum" ] || [ "$gnNetIndexNum" = "ZERO" ]
		then
			rm -f "$ADDN_HostsFilePath" "$DHCP_HostsFilePath" "$DHCP_OptnsFilePath"
			continue
		fi
		configAddFilePath="${JFFS_Configs_Dir}/dnsmasq-${gnNetIndexNum}.conf.add"

		#----------------#
		# DHCP Hostnames #
		#----------------#
		ADDN_HostsComntTag="${SCRIPT_NAME}_hostnames_$gnIFaceName"
		ADDN_HostsDirctive="addn-hosts=$ADDN_HostsFilePath #${ADDN_HostsComntTag}#"
		if ! "$addnDHCP_HostNames" || "$doIFaceDel"
		then rm -f "$ADDN_HostsFilePath"
		fi
		#-----------------------------------------#
		# DHCP Hosts with IP Address Reservations #
		#-----------------------------------------#
		DHCP_HostsComntTag="${SCRIPT_NAME}_staticlist_$gnIFaceName"
		DHCP_HostsDirctive="dhcp-hostsfile=$DHCP_HostsFilePath #${DHCP_HostsComntTag}#"
		if "$doIFaceDel"
		then rm -f "$DHCP_HostsFilePath"
		fi
		#--------------#
		# DHCP Options #
		#--------------#
		DHCP_OptnsComntTag="${SCRIPT_NAME}_optionslist_$gnIFaceName"
		DHCP_OptnsDirctive="dhcp-optsfile=$DHCP_OptnsFilePath #${DHCP_OptnsComntTag}#"
		if "$doIFaceDel"
		then rm -f "$DHCP_OptnsFilePath"
		fi

		Auto_DNSMASQ_Handler "$doIFaceAction"
	done

	_CleanUp_DNSMasqConfigFiles_
	_Restart_DNSMASQ_
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Mount_WebUI()
{
	Print_Output true "Mounting WebUI tab for ${SCRIPT_NAME}..." "$PASS"
	umount /www/Advanced_DHCP_Content.asp 2>/dev/null
	if [ -s "$SCRIPT_DIR/Advanced_DHCP_Content.asp" ]
	then
		webUIupdateOK=true
		mount -o bind "$SCRIPT_DIR/Advanced_DHCP_Content.asp" /www/Advanced_DHCP_Content.asp
		Print_Output true "WebUI tab for $SCRIPT_NAME was mounted." "$PASS"
		return 0
	else
		webUIupdateOK=false
		Print_Output true "**ERROR**: WebUI file for $SCRIPT_NAME is NOT found." "$ERR"
		return 1
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Mar-17] ##
##-------------------------------------##
_CheckFor_WebGUI_Page_()
{
	if [ "$(grep -c 'YazDHCP' /www/Advanced_DHCP_Content.asp)" -ge 8 ]
	then return 0
	fi
	Mount_WebUI
	return "$?"
}

Shortcut_Script()
{
	case $1 in
		create)
			if [ -d /opt/bin ] && [ ! -f "/opt/bin/$SCRIPT_NAME" ] && [ -f "/jffs/scripts/$SCRIPT_NAME" ]
			then
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
   then   ## Update to the MOST recent backup file ##
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
   if ! tar -czf "$theFilePath" -C "$JFFS_Dir" "./$userIconsDIRname"
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

   if ! tar -xzf "$theFilePath" -C "$JFFS_Dir"
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

   if ! tar -xzf "$theFilePath" -C "$JFFS_Dir"
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
   if tar -tzf "$theFilePath" -C "$JFFS_Dir"
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
          printf "Choose an option:  " ; read -r userOption
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

##----------------------------------------------------##
## Added by Martinski W. [2025-Sep-05]
##----------------------------------------------------##
## ARG #1 "$line" has the following format:
## "{MAC_address} {IP_address} {Hostname} {DNS_IP}"
## "$line" comes from new DHCP Clients config file
## so we'll check if the IP address has the octets.
## If only one add prepend rest from LAN IP address.
##------------------------------------------------------
Check_IPv4_AddressValue()
{
    if [ $# -eq 0 ] || [ -z "$1" ]
    then echo ; return 1
    fi
    local MACx_Addrs  IPv4_Addrs  theRestStr

    MACx_Addrs="$(echo "$1" | cut -d' ' -f1)"
    IPv4_Addrs="$(echo "$1" | cut -d' ' -f2)"
    theRestStr="$(echo "$1" | cut -d' ' -f3-4)"

    if [ "$(echo "$IPv4_Addrs" | awk -F'.' '{print NF-1}')" -eq 0 ]
    then
        IPv4_Addrs="${LAN_SUBNET}.$IPv4_Addrs"
    fi
    echo "$MACx_Addrs $IPv4_Addrs $theRestStr"
}

##----------------------------------------------------##
## Modified by Martinski W. [2025-Sep-05]
##----------------------------------------------------##
## ARG #1 "$line" has the following format:
## "{MAC_address} {IP_address} {Hostname} {DNS_IP}"
## "$line" comes from new DHCP Clients config file
## so we'll check for NVRAM variable conflicts.
## If conflicts are found, NVRAM var is modified.
## NVRAM variable entry has the following format:
## "<{MAC_address}>{IP_address}>{DNS_IP}>{Hostname}[<]?"
##------------------------------------------------------
CheckAgainstNVRAMvar()
{
    if [ $# -eq 0 ] || [ -z "$1" ]
    then return 0
    fi
    local theKeyVal  keyEntry  retCode
    local IPv4_Addrs  theRegExp1
    local MACx_Addrs  theRegExp2

    if [ ! -s /jffs/nvram/dhcp_staticlist ]
    then theKeyVal="$(nvram get dhcp_staticlist)"
    else theKeyVal="$(cat /jffs/nvram/dhcp_staticlist)"
    fi
    if [ -z "$theKeyVal" ]
    then return 0
    fi
    if ! echo "$theKeyVal" | grep -qE "^<.*"
    then theKeyVal="<$theKeyVal"
    fi

    retCode=0
    MACx_Addrs="$(echo "$1" | awk -F ' ' '{print $1}')"
    IPv4_Addrs="$(echo "$1" | awk -F ' ' '{print $2}')"
    theRegExp1="<${MACaddr_RegEx}>${IPv4_Addrs}>[^<]*"
    theRegExp2="<${MACx_Addrs}>${IPv4privtx_RegEx}>[^<]*"
    keyEntry=""

    if echo "$theKeyVal" | grep -qE "$theRegExp1"
    then
        keyEntry="$(echo "$theKeyVal" | grep -oE "$theRegExp1")"
    elif echo "$theKeyVal" | grep -qiE "$theRegExp2"
    then
        keyEntry="$(echo "$theKeyVal" | grep -oiE "$theRegExp2")"
    fi
    if [ -n "$keyEntry" ]
    then
        tempFile="/tmp/yazdhcp_nvramStr.tmp"
        echo "$theKeyVal" | sed "s/${keyEntry}//g" | sed '/^$/d' > "$tempFile"
        nvram set dhcp_staticlist="$(cat "$tempFile")"
        rm -f "$tempFile"
        retCode=1
    fi
    return "$retCode"
}

##------------------------------------------------##
## Modified by Martinski W. [2025-Sep-05]
##------------------------------------------------##
## ARG #1 "$line" has the following format:
## "{MAC_address}|{IP_address}|{DNS_IP}|{Hostname}"
## "$line" comes from exported NVRAM variable so
## we'll check for possible duplicate entries.
## If duplicates found, NVRAM entry is ignored.
##--------------------------------------------------
Validate_NVRAM_IPaddr_Reservation()
{
    if [ $# -eq 0 ] || [ -z "$1" ] || \
       ! echo "$1" | grep -q "|"
    then return 1
    fi
    local MACx_Addrs  dupInfoMsg=""  retCode=0
    local IPv4_Addr4  IPv4_Addr3  theClientX  theClientY

    MACx_Addrs="$(echo "$1" | awk -F '|' '{print $1}')"
    IPv4_Addr4="$(echo "$1" | awk -F '|' '{print $2}')"
    IPv4_Addr3="$(echo "$IPv4_Addr4" | cut -d'.' -f1-3)"
    theClientX="${MACx_Addrs},${IPv4_Addr4}"
    theClientY="${MACx_Addrs},${IPv4_Addr3}"
    theClientZ="${MACaddr_RegEx},${IPv4_Addr4}"

    if grep -qi "^${theClientX}," "$SCRIPT_CONF"
    then
        dupInfoMsg="Client IP address reservation [${REDct}${theClientX}${WARN}] is already assigned"
    elif grep -qiE "^${theClientY}[.]${IPv4octet_RegEx}," "$SCRIPT_CONF"
    then
        dupInfoMsg="Client IP address reservation [${REDct}${theClientY}.*${WARN}] within the same subnet already assigned"
    elif grep -qE "^${theClientZ}," "$SCRIPT_CONF"
    then
        dupInfoMsg="Client IP address reservation [${REDct}${IPv4_Addr4}${WARN}] has already been assigned to another client"
    fi

    if [ -n "$dupInfoMsg" ]
    then
        Print_Output true "$dupInfoMsg in $SCRIPT_NAME clients file" "$WARN" oneline
        Print_Output true "The NVRAM entry will be skipped/ignored." "$WARN"
        retCode=1
    fi
    return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_CheckFor_NVRAM_DHCP_Assignments_3004_()
{
	if [ -s /jffs/nvram/dhcp_staticlist ] || \
	   nvram show 2>/dev/null | grep -qE "^$NVRAM_3004_DHCPvar_RegExp"
	then return 0
	else return 1
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-06] ##
##-------------------------------------##
_CheckFor_NVRAM_DHCP_Assignments_3006_()
{
	if [ "$fwInstalledBaseVers" -ge 3006 ] && \
	   nvram show 2>/dev/null | grep -qE "^$NVRAM_3006_DHCPvar_RegExp1"
	then return 0
	else return 1
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_CheckForSaved_NVRAM_DHCP_Assignments_3004_()
{
	if [ -f "${SCRIPT_DIR}/.nvram_dhcp_staticlist" ] || \
	   [ -f "${SCRIPT_DIR}/.nvram_jffs_dhcp_staticlist" ]
	then return 0
	else return 1
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Restore_NVRAM_DHCP_Assignments_3004_()
{
	if [ -f "${SCRIPT_DIR}/.nvram_jffs_dhcp_staticlist" ]
	then
		nvram set dhcp_staticlist="$(cat "${SCRIPT_DIR}/.nvram_jffs_dhcp_staticlist")"
		doCommitNVRAM=true ; restoredOK=true
	fi
	if [ -f "${SCRIPT_DIR}/.nvram_dhcp_staticlist" ]
	then
		nvram set dhcp_staticlist="$(cat "${SCRIPT_DIR}/.nvram_dhcp_staticlist")"
		doCommitNVRAM=true ; restoredOK=true
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Export_NVRAM_DHCP_Assignments_3004_()
{
	if [ $# -eq 0 ] || [ -z "$1" ] || [ ! -f "$1" ]
	then return 1
	fi
	local nvramKeyVal

	if [ -s /jffs/nvram/dhcp_staticlist ]
	then
		cp -f /jffs/nvram/dhcp_staticlist "${SCRIPT_DIR}/.nvram_jffs_dhcp_staticlist"
		sed 's/</\n/g;s/>/|/g;s/<//g' /jffs/nvram/dhcp_staticlist | sed '/^$/d' > "$1"
		echo >> "$1"
	fi

	nvramKeyVal="$(nvram get dhcp_staticlist)"
	if [ -n "$nvramKeyVal" ]
	then
		echo "$nvramKeyVal" | sed 's/</\n/g;s/>/|/g;s/<//g' | sed '/^$/d' > "$1"
		# Make sure key value has the initial angle bracket #
		if ! echo "$nvramKeyVal" | grep -qE "^<.*"
		then nvramKeyVal="<$nvramKeyVal"
		fi
		echo "$nvramKeyVal" > "${SCRIPT_DIR}/.nvram_dhcp_staticlist"
		nvram unset dhcp_staticlist
		doCommitNVRAM=true
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-06] ##
##-------------------------------------##
_CheckForSaved_NVRAM_DHCP_Assignments_3006_()
{
	if [ "$fwInstalledBaseVers" -lt 3006 ]
	then return 1
	fi
	local nvramSavedFiles  theSavedFile

	nvramSavedFiles="$(ls -1 "${SCRIPT_DIR}"/.nvram_dhcp_dhcpres* 2>/dev/null)"
	if [ "${#nvramSavedFiles}" -eq 0 ]
	then return 1
	else return 0
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-06] ##
##-------------------------------------##
_Restore_NVRAM_DHCP_Assignments_3006_()
{
	if [ "$fwInstalledBaseVers" -lt 3006 ]
	then return 1
	fi
	local nvramSavedFiles  theSavedFile  nvramKeyName

	nvramSavedFiles="$(ls -1 "${SCRIPT_DIR}"/.nvram_dhcp_dhcpres* 2>/dev/null)"
	if [ "${#nvramSavedFiles}" -eq 0 ]
	then return 1
	fi
	for theSavedFile in $nvramSavedFiles
	do
		if echo "$theSavedFile" | grep -qE "^${SCRIPT_DIR}/.nvram_dhcp_dhcpres[1-9][0-9]?_rl$"
		then
			nvramKeyName="$(basename "$theSavedFile" | cut -d'_' -f3-)"
			if [ -n "$nvramKeyName" ]
			then
				nvram set ${nvramKeyName}="$(cat "$theSavedFile")"
				doCommitNVRAM=true ; restoredOK=true
			fi
		fi
	done
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-06] ##
##-------------------------------------##
_Export_NVRAM_DHCP_Assignments_3006_()
{
	if [ "$fwInstalledBaseVers" -lt 3006 ] || \
	   [ $# -eq 0 ] || [ -z "$1" ] || [ ! -f "$1" ]
	then return 1
	fi
	local dhcpNVRAMvarKeyList  nvramVarKeyStr  nvramVarKey  nvramKeyVal

	dhcpNVRAMvarKeyList="$(nvram show 2>/dev/null | grep -oE "^$NVRAM_3006_DHCPvar_RegExp0" | sort -u)"
	if [ "${#dhcpNVRAMvarKeyList}" -eq 0 ]
	then return 1
	fi
	for nvramVarKeyStr in $dhcpNVRAMvarKeyList
	do
		nvramVarKey="$(echo "$nvramVarKeyStr" | cut -d'=' -f1)"
		nvramKeyVal="$(nvram get "$nvramVarKey")"
		if [ -n "$nvramKeyVal" ]
		then
			echo "$nvramKeyVal" > "$SCRIPT_DIR/.nvram_dhcp_$nvramVarKey"
			echo "$nvramKeyVal" | sed 's/</\n/g;s/>/|/g;s/<//g' | sed '/^$/d' >> "$1"
			nvram unset "$nvramVarKey"
			doCommitNVRAM=true
		fi
	done
}

##----------------------------------------------##
## OLDER F/W < "3004.386.4" NO LONGER SUPPORTED
## [3004.386.4 F/W was released on 2022-Jan-01]
##----------------------------------------------##
## Modified by Martinski W. [2025-Sep-05]
##----------------------------------------------##
_Export_DHCP_NVRAM_OLD_FW_Versions_()
{
	if false   ##[ "$(FirmwareVersionNum "3004.386.4")" ]##
	then
		if [ -f /jffs/nvram/dhcp_hostnames ]
		then
			if [ "$(wc -m < /jffs/nvram/dhcp_hostnames)" -le 1 ]
			then
				Print_Output true "DHCP hostnames NOT exported from NVRAM, no data found" "$PASS"
				Clear_Lock
				return 1
			fi
		elif [ "$(nvram get dhcp_hostnames | wc -m)" -le 1 ]
		then
			Print_Output true "DHCP hostnames NOT exported from NVRAM, no data found" "$PASS"
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
	fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Oct-10] ##
##-------------------------------------##
_CheckFor_UserCustom_IPaddr_Reservations_()
{
    local retCode=1  configAddRegExp  configAddFPath

    configAddRegExp="${JFFS_Configs_Dir}/dnsmasq*.conf.add"
    for configAddFPath in $(ls -1 $configAddRegExp 2>/dev/null)
    do
        if [ -s "$configAddFPath" ] && \
           grep -qE "^dhcp-host=.*${IPv4privtx_RegEx}" "$configAddFPath"
        then retCode=0 ; break
        fi
    done
    return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2025-Oct-10] ##
##-------------------------------------##
_NoticeFor_UserCustom_IPaddr_Reservations_()
{
	if _CheckFor_UserCustom_IPaddr_Reservations_
	then
		printf "\n${WarnBYLWct}*NOTE*:${CLRct}\n"
		printf "${BOLD}YazDHCP will *NOT* transfer any IP address reservations found in\n"
		printf "user-supplied custom files (e.g. ${WARN}/jffs/configs/dnsmasq*.conf.add${CLRct}).\n"
		printf "If you have such files, you will need to manually transfer all the\n"
		printf "IP address reservations to YazDHCP and then remove the entries from\n"
		printf "your custom files to prevent dnsmasq from getting duplicates.${CLRct}\n"
		if [ $# -gt 0 ] && [ "$1" = "true" ]
		then echo ; PressEnter ; echo ; fi
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Oct-10] ##
##----------------------------------------##
Export_FW_DHCP_NVRAM_JFFS()
{
	printf "\n${BOLD}Do you want to export DHCP IP address assignments and hostnames"
	printf "\nfrom NVRAM to %s internal client files?\n" "$SCRIPT_NAME"
	printf "\n%s will make backups of all the existing NVRAM DHCP data" "$SCRIPT_NAME"
	printf "\nas part of this export process.${CLRct}\n"

	_NoticeFor_UserCustom_IPaddr_Reservations_

	printf "\n${BOLD}Confirm export from NVRAM? (y|n):${CLEARct}  "
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
	echo

	if ! _CheckFor_NVRAM_DHCP_Assignments_3004_ && \
	   ! _CheckFor_NVRAM_DHCP_Assignments_3006_
	then
		Print_Output true "DHCP IP address assignments NOT exported from NVRAM. No NVRAM settings found." "$PASS"
		Clear_Lock
		return 1
	fi

	local doCommitNVRAM  retStatus=false
	local yazdhcpExportFile="/tmp/yazdhcp_EXPORT.tmp"

	doCommitNVRAM=false
	touch "$yazdhcpExportFile"
	if _CheckFor_NVRAM_DHCP_Assignments_3004_
	then
		_Export_NVRAM_DHCP_Assignments_3004_  "$yazdhcpExportFile"
	fi
	if _CheckFor_NVRAM_DHCP_Assignments_3006_
	then
		_Export_NVRAM_DHCP_Assignments_3006_  "$yazdhcpExportFile"
	fi
	"$doCommitNVRAM" && nvram commit

	if [ ! -s "$SCRIPT_CONF" ]
	then echo "MAC,IP,HOSTNAME,DNS" > "$SCRIPT_CONF"
	fi
	sort -t . -k 3,3n -k 4,4n "$yazdhcpExportFile" > /tmp/yazdhcp_SORTED.tmp

	while IFS='' read -r line || [ -n "$line" ]
	do
		if ! Validate_NVRAM_IPaddr_Reservation "$line"
		then continue
		fi
		echo "$line" | awk 'FS="|" { print ""$1","$2","$4","$3""; }' >> "$SCRIPT_CONF"
	done < /tmp/yazdhcp_SORTED.tmp

	if [ -s "$yazdhcpExportFile" ]
	then
		retStatus=true
		Print_Output true "DHCP settings were successfully exported from NVRAM" "$PASS"
	fi
	rm -f "$yazdhcpExportFile" /tmp/yazdhcp_SORTED.tmp

	"$retStatus" && _Check_ActiveGuestNetwork_SubnetInfo_

	if ! Process_DHCP_Clients && "$retStatus"
	then
		Print_Output true "Restarting dnsmasq for exported DHCP settings to take effect." "$PASS"
		service restart_dnsmasq >/dev/null 2>&1
	fi

	Clear_Lock
	"$retStatus" && return 0 || return 1
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Update_Hostnames_MainLAN()
{
	local theMACaddr  theIPaddr4  theHostName  theDNSaddr  theIPaddr3
	local LAN_IPaddr3="$(echo "$mainLAN_IPaddr" | cut -d'.' -f1-3)"

	while IFS=',' read -r theMACaddr theIPaddr4 theHostName theDNSaddr
	do
		if [ "$theMACaddr" = "MAC" ] || \
             [ -z "$theHostName" ] || [ -z "$theIPaddr4" ]
		then continue
		fi
		theIPaddr3="$(echo "$theIPaddr4" | cut -d'.' -f1-3)"
		if [ "$theIPaddr3" = "$LAN_IPaddr3" ]
		then
			echo "$theIPaddr4 $theHostName" >> "$hostNamesFilePATH"
		fi
	done < "$SCRIPT_CONF"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
Update_Hostnames_GuestNet()
{
	local gnExistingMD5  gnUpdatedMD5  theIPaddr3
	local gnInfoStr  gnListOfIFaces  gnIFaceVarStr
	local gnIFaceName  gnStartIPaddr4  gnStartIPaddr3
	local theMACaddr  theIPaddr4  theHostName  theDNSaddr
	local hostNamesFileGNET  hostNamesFileBKUP  gnIFaceDelEntry

	gnInfoStr="$(_Get_GuestNetwork_SubnetInfo_)"
	if [ "${#gnInfoStr}" -eq 0 ]
	then return 1
	fi
	gnListOfIFaces="$(echo "$gnInfoStr" | cut -d'=' -f1 | cut -d'_' -f2)"
	if [ -z "$gnListOfIFaces" ]
	then return 1
	fi

	if ! "$(_AllowGuestNetwork_IP_Reservations_ check)"
	then gnIFaceDelEntry=true
	else gnIFaceDelEntry=false
	fi

	for gnIFaceName in $gnListOfIFaces
	do
		gnExistingMD5=""  gnUpdatedMD5=""
		hostNamesFileGNET="${hostNamesFilePATH}_${gnIFaceName}"
		hostNamesFileBKUP="${hostNamesFileGNET}.BKUP"

		if "$gnIFaceDelEntry"
		then
			if [ -s "$hostNamesFileGNET" ]
			then
				Print_Output true "DHCP hostname list for Guest Network [$gnIFaceName] was removed" "$WARN" oneline
				if [ "$fwInstalledBaseVers" -ge 3006 ]
				then RESTART_DNSMASQ=true
				fi
			fi
			rm -f "$hostNamesFileGNET" "$hostNamesFileBKUP"
			continue
		fi
		if [ -s "$hostNamesFileGNET" ]
		then
			gnExistingMD5="$(md5sum "$hostNamesFileGNET" | awk '{print $1}')"
			mv -f "$hostNamesFileGNET" "$hostNamesFileBKUP"
		fi
		printf "" > "$hostNamesFileGNET"

		gnIFaceVarStr="GNIFACE_${gnIFaceName}="
		gnStartIPaddr4="$(echo "$gnInfoStr" | grep -E "^${gnIFaceVarStr}.*" | cut -d'=' -f2 | cut -d',' -f1)"
		gnStartIPaddr3="$(echo "$gnStartIPaddr4" | cut -d'.' -f1-3)"

		while IFS=',' read -r theMACaddr theIPaddr4 theHostName theDNSaddr
		do
			if [ "$theMACaddr" = "MAC" ] || \
			   [ -z "$theHostName" ] || [ -z "$theIPaddr4" ]
			then continue
			fi
			theIPaddr3="$(echo "$theIPaddr4" | cut -d'.' -f1-3)"
			if [ "$theIPaddr3" = "$gnStartIPaddr3" ]
			then
				echo "$theIPaddr4 $theHostName" >> "$hostNamesFileGNET"
			fi
		done < "$SCRIPT_CONF"

		if [ -s "$hostNamesFileGNET" ]
		then
			gnUpdatedMD5="$(md5sum "$hostNamesFileGNET" | awk '{print $1}')"
		fi
		if [ -n "$gnUpdatedMD5" ] && [ "$gnExistingMD5" != "$gnUpdatedMD5" ]
		then
			Print_Output true "DHCP hostname list for Guest Network [$gnIFaceName] updated successfully" "$PASS" oneline
			if [ "$fwInstalledBaseVers" -ge 3006 ]
			then RESTART_DNSMASQ=true
			fi
		elif [ -z "$gnUpdatedMD5" ]
		then
			if [ -s "$hostNamesFileBKUP" ]
			then
				Print_Output true "DHCP hostname list for Guest Network [$gnIFaceName] was removed." "$WARN" oneline
				if [ "$fwInstalledBaseVers" -ge 3006 ]
				then RESTART_DNSMASQ=true
				fi
			fi
		else
			if [ -s "$hostNamesFileBKUP" ]
			then cp -fp "$hostNamesFileBKUP" "$hostNamesFileGNET"
			fi
			Print_Output true "DHCP hostname list for Guest Network [$gnIFaceName] remains unchanged" "$PASS" oneline
		fi
		if [ "$fwInstalledBaseVers" -lt 3006 ] && [ -s "$hostNamesFileGNET" ]
		then
			cat "$hostNamesFileGNET" >> "$hostNamesFilePATH"
		fi
		"$delBkupCopy" && rm -f "$hostNamesFileBKUP"
	done
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Update_StaticList_MainLAN()
{
	local theMACaddr  theIPaddr4  theHostName  theDNSaddr
	local hostNameEntry  dhcpNetwkTagID  dhcpNetTagStr  theIPaddr3
	local LAN_IPaddr3="$(echo "$mainLAN_IPaddr" | cut -d'.' -f1-3)"

	_Get_DHCP_NetworkTagStr_ "$mainLAN_IPaddr" MainLAN

	while IFS=',' read -r theMACaddr theIPaddr4 theHostName theDNSaddr
	do
		if [ "$theMACaddr" = "MAC" ] || \
		   [ -z "$theMACaddr" ] || [ -z "$theIPaddr4" ]
		then continue
		fi
		if [ -z "$theHostName" ]
		then hostNameEntry=""
		else hostNameEntry=",$theHostName"
		fi
		if [ -z "$dhcpNetwkTagID" ] || [ "$dhcpNetwkTagID" = "NONE" ]
		then dhcpNetTagStr=""
		else dhcpNetTagStr="set:${dhcpNetwkTagID},"
		fi

		theIPaddr3="$(echo "$theIPaddr4" | cut -d'.' -f1-3)"
		if [ "$theIPaddr3" = "$LAN_IPaddr3" ]
		then
			{
			    echo "${dhcpNetTagStr}${theMACaddr},set:${theMACaddr},${theIPaddr4}${hostNameEntry}" 
			} >> "$staticListFilePATH"
		fi
	done < "$SCRIPT_CONF"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
Update_StaticList_GuestNet()
{
	local gnExistingMD5  gnUpdatedMD5  theIPaddr3
	local gnInfoStr  gnListOfIFaces  gnIFaceVarStr
	local gnIFaceName  gnStartIPaddr4  gnStartIPaddr3
	local theMACaddr  theIPaddr4  theHostName  theDNSaddr
	local hostNameEntry  dhcpNetwkTagID  dhcpNetTagStr  retCode
	local staticListFileGNET  staticListFileBKUP  gnIFaceDelEntry

	gnInfoStr="$(_Get_GuestNetwork_SubnetInfo_)"
	if [ "${#gnInfoStr}" -eq 0 ]
	then return 1
	fi
	gnListOfIFaces="$(echo "$gnInfoStr" | cut -d'=' -f1 | cut -d'_' -f2)"
	if [ -z "$gnListOfIFaces" ]
	then return 1
	fi

	if ! "$(_AllowGuestNetwork_IP_Reservations_ check)"
	then gnIFaceDelEntry=true
	else gnIFaceDelEntry=false
	fi
	retCode=1

	for gnIFaceName in $gnListOfIFaces
	do
		gnExistingMD5=""  gnUpdatedMD5=""
		staticListFileGNET="${staticListFilePATH}_${gnIFaceName}"
		staticListFileBKUP="${staticListFileGNET}.BKUP"

		if "$gnIFaceDelEntry"
		then
			if [ -s "$staticListFileGNET" ]
			then
				retCode=0
				Print_Output true "DHCP IP address reservation list for Guest Network [$gnIFaceName] was removed" "$WARN" oneline
				if [ "$fwInstalledBaseVers" -ge 3006 ]
				then RESTART_DNSMASQ=true
				fi
			fi
			rm -f "$staticListFileGNET" "$staticListFileBKUP"
			continue
		fi
		if [ -s "$staticListFileGNET" ]
		then
			gnExistingMD5="$(md5sum "$staticListFileGNET" | awk '{print $1}')"
			mv -f "$staticListFileGNET" "$staticListFileBKUP"
		fi
		printf "" > "$staticListFileGNET"

		gnIFaceVarStr="GNIFACE_${gnIFaceName}="
		gnStartIPaddr4="$(echo "$gnInfoStr" | grep -E "^${gnIFaceVarStr}.*" | cut -d'=' -f2 | cut -d',' -f1)"
		gnStartIPaddr3="$(echo "$gnStartIPaddr4" | cut -d'.' -f1-3)"
		dhcpNetwkTagID="$(echo "$gnInfoStr" | grep -E "^${gnIFaceVarStr}.*" | cut -d'=' -f2 | cut -d',' -f4)"

		while IFS=',' read -r theMACaddr theIPaddr4 theHostName theDNSaddr
		do
			if [ "$theMACaddr" = "MAC" ] || \
			   [ -z "$theMACaddr" ] || [ -z "$theIPaddr4" ]
			then continue
			fi
			if [ -z "$theHostName" ]
			then hostNameEntry=""
			else hostNameEntry=",$theHostName"
			fi
			if [ -z "$dhcpNetwkTagID" ] || [ "$dhcpNetwkTagID" = "NONE" ]
			then dhcpNetTagStr=""
			else dhcpNetTagStr="set:${dhcpNetwkTagID},"
			fi

			theIPaddr3="$(echo "$theIPaddr4" | cut -d'.' -f1-3)"
			if [ "$theIPaddr3" = "$gnStartIPaddr3" ]
			then
				{
				    echo "${dhcpNetTagStr}${theMACaddr},set:${theMACaddr},${theIPaddr4}${hostNameEntry}" 
				} >> "$staticListFileGNET"
			fi
		done < "$SCRIPT_CONF"

		if [ "$(_GetFileSizeBytes_ "$staticListFileGNET")" -ge 3 ]
		then
			gnUpdatedMD5="$(md5sum "$staticListFileGNET" | awk '{print $1}')"
		fi
		if [ -n "$gnUpdatedMD5" ] && [ "$gnExistingMD5" != "$gnUpdatedMD5" ]
		then
			retCode=0
			Print_Output true "DHCP IP address reservation list for Guest Network [$gnIFaceName] updated successfully" "$PASS" oneline
			if [ "$fwInstalledBaseVers" -ge 3006 ]
			then RESTART_DNSMASQ=true
			fi
		elif [ -z "$gnUpdatedMD5" ]
		then
			if [ -s "$staticListFileBKUP" ]
			then
				retCode=0
				Print_Output true "DHCP IP address reservation list for Guest Network [$gnIFaceName] was removed." "$WARN" oneline
				if [ "$fwInstalledBaseVers" -ge 3006 ]
				then RESTART_DNSMASQ=true
				fi
			fi
		else
			if [ -s "$staticListFileBKUP" ]
			then cp -fp "$staticListFileBKUP" "$staticListFileGNET"
			fi
			Print_Output true "DHCP IP address reservation list for Guest Network [$gnIFaceName] remains unchanged" "$PASS" oneline
		fi
		if [ "$fwInstalledBaseVers" -lt 3006 ] && [ -s "$staticListFileGNET" ]
		then
			cat "$staticListFileGNET" >> "$staticListFilePATH"
		fi
		"$delBkupCopy" && rm -f "$staticListFileBKUP"
		if [ "$(_GetFileSizeBytes_ "$staticListFileGNET")" -lt 3 ]
		then rm -f "$staticListFileGNET"
		fi
	done

	CleanUp_StaticList_GuestNet
	return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-13] ##
##-------------------------------------##
CleanUp_StaticList_GuestNet()
{
	local gnInfoStr  gnListOfIFaces  gnIFaceName
	local staticListRegExp  staticListFPath

	gnInfoStr="$(_Get_GuestNetwork_SubnetInfo_)"
	if [ "${#gnInfoStr}" -eq 0 ]
	then return 1
	fi
	gnListOfIFaces="$(echo "$gnInfoStr" | cut -d'=' -f1 | cut -d'_' -f2)"
	if [ -z "$gnListOfIFaces" ]
	then return 1
	fi

	staticListRegExp="${SCRIPT_DIR}/.staticlist_*"
	for staticListFPath in $(ls -1 $staticListRegExp 2>/dev/null)
	do
		gnIFaceName="$(basename "$staticListFPath" | cut -d'_' -f2)"
		if ! echo "$gnIFaceName" | grep -qE "^${guestNetIFaces0RegExp}$" || \
		   echo "$gnListOfIFaces" | grep -qw "$gnIFaceName"
		then continue
		fi
		rm -f "$staticListFPath"
	done
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Update_OptionsList_MainLAN()
{
	local theMACaddr  theIPaddr4  theHostName  theDNSaddr
	local dhcpNetwkTagID  dhcpNetTagStr  theIPaddr3
	local LAN_IPaddr3="$(echo "$mainLAN_IPaddr" | cut -d'.' -f1-3)"

	_Get_DHCP_NetworkTagStr_ "$mainLAN_IPaddr" MainLAN

	while IFS=',' read -r theMACaddr theIPaddr4 theHostName theDNSaddr
	do
		if [ "$theMACaddr" = "MAC" ] || \
		   [ -z "$theDNSaddr" ] || [ -z "$theIPaddr4" ]
		then continue
		fi
		if [ -z "$dhcpNetwkTagID" ] || [ "$dhcpNetwkTagID" = "NONE" ]
		then dhcpNetTagStr=""
		else dhcpNetTagStr="tag:${dhcpNetwkTagID},"
		fi

		theIPaddr3="$(echo "$theIPaddr4" | cut -d'.' -f1-3)"
		if [ "$theIPaddr3" = "$LAN_IPaddr3" ]
		then
			{
			    echo "${dhcpNetTagStr}tag:${theMACaddr},6,$theDNSaddr" 
			} >> "$optionsListFilePATH"
		fi
	done < "$SCRIPT_CONF"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
Update_OptionsList_GuestNet()
{
	local gnExistingMD5  gnUpdatedMD5  theIPaddr3
	local gnInfoStr  gnListOfIFaces  gnIFaceVarStr
	local gnIFaceName  gnStartIPaddr4  gnStartIPaddr3
	local theMACaddr  theIPaddr4  theHostName  theDNSaddr
	local dhcpNetwkTagID  dhcpNetTagStr  gnIFaceDelEntry
	local optionsListFileGNET  optionsListFileBKUP  retCode

	gnInfoStr="$(_Get_GuestNetwork_SubnetInfo_)"
	if [ "${#gnInfoStr}" -eq 0 ]
	then return 1
	fi
	gnListOfIFaces="$(echo "$gnInfoStr" | cut -d'=' -f1 | cut -d'_' -f2)"
	if [ -z "$gnListOfIFaces" ]
	then return 1
	fi

	if ! "$(_AllowGuestNetwork_IP_Reservations_ check)"
	then gnIFaceDelEntry=true
	else gnIFaceDelEntry=false
	fi
	retCode=1

	for gnIFaceName in $gnListOfIFaces
	do
		gnExistingMD5=""  gnUpdatedMD5=""
		optionsListFileGNET="${optionsListFilePATH}_${gnIFaceName}"
		optionsListFileBKUP="${optionsListFileGNET}.BKUP"

		if "$gnIFaceDelEntry"
		then
			if [ -s "$optionsListFileGNET" ]
			then
				retCode=0
				Print_Output true "DHCP options list for Guest Network [$gnIFaceName] was removed" "$WARN" oneline
				if [ "$fwInstalledBaseVers" -ge 3006 ]
				then RESTART_DNSMASQ=true
				fi
			fi
			rm -f "$optionsListFileGNET" "$optionsListFileBKUP"
			continue
		fi
		if [ -s "$optionsListFileGNET" ]
		then
			gnExistingMD5="$(md5sum "$optionsListFileGNET" | awk '{print $1}')"
			mv -f "$optionsListFileGNET" "$optionsListFileBKUP"
		fi
		printf "" > "$optionsListFileGNET"

		gnIFaceVarStr="GNIFACE_${gnIFaceName}="
		gnStartIPaddr4="$(echo "$gnInfoStr" | grep -E "^${gnIFaceVarStr}.*" | cut -d'=' -f2 | cut -d',' -f1)"
		gnStartIPaddr3="$(echo "$gnStartIPaddr4" | cut -d'.' -f1-3)"
		dhcpNetwkTagID="$(echo "$gnInfoStr" | grep -E "^${gnIFaceVarStr}.*" | cut -d'=' -f2 | cut -d',' -f4)"

		while IFS=',' read -r theMACaddr theIPaddr4 theHostName theDNSaddr
		do
			if [ "$theMACaddr" = "MAC" ] || \
			   [ -z "$theDNSaddr" ] || [ -z "$theIPaddr4" ]
			then continue
			fi
			if [ -z "$dhcpNetwkTagID" ] || [ "$dhcpNetwkTagID" = "NONE" ]
			then dhcpNetTagStr=""
			else dhcpNetTagStr="tag:${dhcpNetwkTagID},"
			fi

			theIPaddr3="$(echo "$theIPaddr4" | cut -d'.' -f1-3)"
			if [ "$theIPaddr3" = "$gnStartIPaddr3" ]
			then
				{
				    echo "${dhcpNetTagStr}tag:${theMACaddr},6,$theDNSaddr" 
				} >> "$optionsListFileGNET"
			fi
		done < "$SCRIPT_CONF"

		if [ "$(_GetFileSizeBytes_ "$optionsListFileGNET")" -ge 3 ]
		then
			gnUpdatedMD5="$(md5sum "$optionsListFileGNET" | awk '{print $1}')"
		fi
		if [ -n "$gnUpdatedMD5" ] && [ "$gnExistingMD5" != "$gnUpdatedMD5" ]
		then
			retCode=0
			Print_Output true "DHCP options list for Guest Network [$gnIFaceName] updated successfully" "$PASS" oneline
			if [ "$fwInstalledBaseVers" -ge 3006 ]
			then RESTART_DNSMASQ=true
			fi
		elif [ -z "$gnUpdatedMD5" ]
		then
			if [ -s "$optionsListFileBKUP" ]
			then
				retCode=0
				Print_Output true "DHCP options list for Guest Network [$gnIFaceName] was removed." "$WARN" oneline
				if [ "$fwInstalledBaseVers" -ge 3006 ]
				then RESTART_DNSMASQ=true
				fi
			fi
		else
			if [ -s "$optionsListFileBKUP" ]
			then cp -fp "$optionsListFileBKUP" "$optionsListFileGNET"
			fi
			Print_Output true "DHCP options list for Guest Network [$gnIFaceName] remains unchanged" "$PASS" oneline
		fi
		if [ "$fwInstalledBaseVers" -lt 3006 ] && [ -s "$optionsListFileGNET" ]
		then
			cat "$optionsListFileGNET" >> "$optionsListFilePATH"
		fi
		"$delBkupCopy" && rm -f "$optionsListFileBKUP"
		if [ "$(_GetFileSizeBytes_ "$optionsListFileGNET")" -lt 3 ]
		then rm -f "$optionsListFileGNET"
		fi
	done

	CleanUp_OptionsList_GuestNet
	return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-13] ##
##-------------------------------------##
CleanUp_OptionsList_GuestNet()
{
	local gnInfoStr  gnListOfIFaces  gnIFaceName
	local optionsListRegExp  optionsListFPath

	gnInfoStr="$(_Get_GuestNetwork_SubnetInfo_)"
	if [ "${#gnInfoStr}" -eq 0 ]
	then return 1
	fi
	gnListOfIFaces="$(echo "$gnInfoStr" | cut -d'=' -f1 | cut -d'_' -f2)"
	if [ -z "$gnListOfIFaces" ]
	then return 1
	fi

	optionsListRegExp="${SCRIPT_DIR}/.optionslist_*"
	for optionsListFPath in $(ls -1 $optionsListRegExp 2>/dev/null)
	do
		gnIFaceName="$(basename "$optionsListFPath" | cut -d'_' -f2)"
		if ! echo "$gnIFaceName" | grep -qE "^${guestNetIFaces0RegExp}$" || \
		   echo "$gnListOfIFaces" | grep -qw "$gnIFaceName"
		then continue
		fi
		rm -f "$optionsListFPath"
	done
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Update_Hostnames()
{
	local lanExistingMD5=""  lanUpdatedMD5=""  msgTagStr=""
	local hostNamesFilePATH="$SCRIPT_DIR/.hostnames"
	local hostNamesFileORIG="${hostNamesFilePATH}.BKUP"

	#-----------------------------------------------------------------
	# The Hostnames file is no longer needed because the information 
     # is now included/embedded in the "staticlist" file.
	#-----------------------------------------------------------------
	if ! "$addnDHCP_HostNames"
	then
		rm -f "$hostNamesFilePATH" "$hostNamesFileORIG"
		return 0
	fi

	if [ -s "$hostNamesFilePATH" ]
	then
		lanExistingMD5="$(md5sum "$hostNamesFilePATH" | awk '{print $1}')"
		mv -f "$hostNamesFilePATH" "$hostNamesFileORIG"
	fi
	printf "" > "$hostNamesFilePATH"

	Update_Hostnames_MainLAN
	##OFF## Update_Hostnames_GuestNet ##OFF##

	if [ -s "$hostNamesFilePATH" ]
	then
		lanUpdatedMD5="$(md5sum "$hostNamesFilePATH" | awk '{print $1}')"
	fi

	if "$(_AllowGuestNetwork_IP_Reservations_ check)"
	then msgTagStr="for main LAN [$mainLAN_IFname] "
	fi

	if [ -n "$lanUpdatedMD5" ] && [ "$lanExistingMD5" != "$lanUpdatedMD5" ]
	then
		Print_Output true "DHCP hostname list ${msgTagStr}updated successfully" "$PASS" oneline
		RESTART_DNSMASQ=true
	elif [ -n "$lanUpdatedMD5" ]
	then
		if [ -s "$hostNamesFileORIG" ]
		then cp -fp "$hostNamesFileORIG" "$hostNamesFilePATH"
		fi
		"$verboseMode" && \
		Print_Output true "DHCP hostname list ${msgTagStr}remains unchanged" "$PASS" oneline
	fi
	"$delBkupCopy" && rm -f "$hostNamesFileORIG"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Update_StaticList()
{
	local lanExistingMD5=""  lanUpdatedMD5=""  msgTagStr=""
	local staticListFilePATH="$SCRIPT_DIR/.staticlist"
	local staticListFileBKUP="${staticListFilePATH}.BKUP"

	if [ -s "$staticListFilePATH" ]
	then
		lanExistingMD5="$(md5sum "$staticListFilePATH" | awk '{print $1}')"
		mv -f "$staticListFilePATH" "$staticListFileBKUP"
	fi
	printf "" > "$staticListFilePATH"

	Update_StaticList_MainLAN
	Update_StaticList_GuestNet
	if [ $? -eq 0 ] || "$(_AllowGuestNetwork_IP_Reservations_ check)"
	then msgTagStr="for main LAN [$mainLAN_IFname] "
	fi

	if [ "$(_GetFileSizeBytes_ "$staticListFilePATH")" -ge 3 ]
	then
		lanUpdatedMD5="$(md5sum "$staticListFilePATH" | awk '{print $1}')"
	fi
	if [ -n "$lanUpdatedMD5" ] && [ "$lanExistingMD5" != "$lanUpdatedMD5" ]
	then
		Print_Output true "DHCP IP address reservation list ${msgTagStr}updated successfully" "$PASS" oneline
		RESTART_DNSMASQ=true
	elif [ -n "$lanUpdatedMD5" ]  #NO Change#
	then
		if [ "$(_GetFileSizeBytes_ "$staticListFileBKUP")" -ge 3 ]
		then cp -fp "$staticListFileBKUP" "$staticListFilePATH"
		fi
		"$verboseMode" && \
		Print_Output true "DHCP IP address reservation list ${msgTagStr}remains unchanged" "$PASS" oneline
	fi
	"$delBkupCopy" && rm -f "$staticListFileBKUP"
	if [ "$(_GetFileSizeBytes_ "$staticListFilePATH")" -lt 3 ]
	then rm -f "$staticListFilePATH"
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Update_OptionsList()
{
	local lanExistingMD5=""  lanUpdatedMD5=""  msgTagStr=""
	local optionsListFilePATH="$SCRIPT_DIR/.optionslist"
	local optionsListFileBKUP="${optionsListFilePATH}.BKUP"

	if [ -s "$optionsListFilePATH" ]
	then
		lanExistingMD5="$(md5sum "$optionsListFilePATH" | awk '{print $1}')"
		mv -f "$optionsListFilePATH" "$optionsListFileBKUP"
	fi
	printf "" > "$optionsListFilePATH"

	Update_OptionsList_MainLAN
	Update_OptionsList_GuestNet
	if [ $? -eq 0 ] || "$(_AllowGuestNetwork_IP_Reservations_ check)"
	then msgTagStr="for main LAN [$mainLAN_IFname] "
	fi

	if [ -s "$optionsListFilePATH" ]
	then
		lanUpdatedMD5="$(md5sum "$optionsListFilePATH" | awk '{print $1}')"
	fi
	if [ -n "$lanUpdatedMD5" ] && [ "$lanExistingMD5" != "$lanUpdatedMD5" ]
	then
		Print_Output true "DHCP options list ${msgTagStr}updated successfully" "$PASS" oneline
		RESTART_DNSMASQ=true
	elif [ -n "$lanUpdatedMD5" ]  #NO Change#
	then
		if [ "$(_GetFileSizeBytes_ "$optionsListFileBKUP")" -ge 3 ]
		then cp -fp "$optionsListFileBKUP" "$optionsListFilePATH"
		fi
		"$verboseMode" && \
		Print_Output true "DHCP options list ${msgTagStr}remains unchanged" "$PASS" oneline
	fi
	"$delBkupCopy" && rm -f "$optionsListFileBKUP"
	if [ "$(_GetFileSizeBytes_ "$optionsListFilePATH")" -lt 3 ]
	then rm -f "$optionsListFilePATH"
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Process_DHCP_Clients()
{
	local retCode=1  delBkupCopy=true  verboseMode
	if [ $# -gt 0 ] && { [ "$1" = "true" ] || [ "$1" = "false" ] ; }
	then RESTART_DNSMASQ="$1"
	else RESTART_DNSMASQ=false
	fi

	if [ ! -s "$SCRIPT_CONF" ] || \
	   ! grep -qv "MAC,IP,HOSTNAME,DNS" "$SCRIPT_CONF"
	then
		Print_Output true "No DHCP client IP address assignments were found." "$WARN"
		return 1
	fi

	verboseMode="${setVerboseMode:=true}"
	Update_Hostnames
	Update_StaticList
	Update_OptionsList

	if "$RESTART_DNSMASQ"
	then
		retCode=0
		Auto_DNSMASQ create true
	fi
	return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_CenterTextStr_()
{
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] || \
       ! echo "$2" | grep -qE "^[1-9][0-9]+$"
    then echo ; return 1
    fi
    local stringLen="${#1}"
    local space1Len="$((($2 - stringLen)/2))"
    local space2Len="$space1Len"
    local totalLen="$((space1Len + stringLen + space2Len))"

    if [ "$totalLen" -lt "$2" ]
    then space2Len="$((space2Len + 1))"
    elif [ "$totalLen" -gt "$2" ]
    then space1Len="$((space1Len - 1))"
    fi
    if [ "$space1Len" -gt 0 ] && [ "$space2Len" -gt 0 ]
    then printf "%*s%s%*s" "$space1Len" '' "$1" "$space2Len" ''
    else printf "%s" "$1"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-06] ##
##----------------------------------------##
ScriptHeader()
{
	clear
	local spaceLen=52  colorCT
	[ "$SCRIPT_BRANCH" = "master" ] && colorCT="$GRNct" || colorCT="$MGNTct"
	echo
	printf "${BOLD}##########################################################${CLEARct}\n"
	printf "${BOLD}##                                                      ##${CLEARct}\n"
	printf "${BOLD}##  __     __          _____   _    _   _____  _____    ##${CLEARct}\n"
	printf "${BOLD}##  \ \   / /         |  __ \ | |  | | / ____||  __ \   ##${CLEARct}\n"
	printf "${BOLD}##   \ \_/ /__ _  ____| |  | || |__| || |     | |__) |  ##${CLEARct}\n"
	printf "${BOLD}##    \   // _  ||_  /| |  | ||  __  || |     |  ___/   ##${CLEARct}\n"
	printf "${BOLD}##     | || (_| | / / | |__| || |  | || |____ | |       ##${CLEARct}\n"
	printf "${BOLD}##     |_| \__,_|/___||_____/ |_|  |_| \_____||_|       ##${CLEARct}\n"
	printf "${BOLD}##                                                      ##${CLEARct}\n"
	printf "${BOLD}## ${GRNct}%s${CLRct}${BOLD} ##${CLRct}\n" "$(_CenterTextStr_ "$versionMod_TAG" "$spaceLen")"
	printf "${BOLD}## ${colorCT}%s${CLRct}${BOLD} ##${CLRct}\n" "$(_CenterTextStr_ "$branchxStr_TAG" "$spaceLen")"
	printf "${BOLD}##                                                      ##${CLEARct}\n"
	printf "${BOLD}##         https://github.com/AMTM-OSR/YazDHCP          ##${CLEARct}\n"
	printf "${BOLD}##    Forked from https://github.com/jackyaz/YazDHCP    ##${CLEARct}\n"
	printf "${BOLD}##                                                      ##${CLEARct}\n"
	printf "${BOLD}##########################################################${CLEARct}\n\n"
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
_Check_ActiveGuestNetwork_SubnetInfo_()
{
   local gnListOfIFaces=""  gnIFaceName  gnInfoStr1  gnInfoStr2
   local gnSubnetCIDR  gnSubnetMask  gnStartIPadd  gnIFaceCount

   _Update_GuestNetCheck_Status_ InProgress

   _Get_ActiveGuestNetwork_VirtualInterfaces_
   if [ -z "$gnListOfIFaces" ]
   then
       _Init_ActiveGuestNetwork_SubnetInfo_
       _AllowGuestNetwork_IP_Reservations_ reset false
       _Update_GuestNetCheck_Status_ DONE
       return 1
   fi

   {
      echo 'var foundActiveGuestNetworks = true;'
      echo 'var allowGuestNet_IP_Reservation = true;'
      printf 'var guestNetwork_SubnetInfoArray ='
   } > "$guestNetInfoJSfilePath"

   _Reset_GuestNetwork_SubnetInfo_

   gnIFaceCount=0
   gnListOfIFaces="$(echo "$gnListOfIFaces" | sort -i)"

   for gnIFaceName in $gnListOfIFaces
   do
       gnInfoStr1="$(ifconfig "$gnIFaceName" | grep -E -A1 "^$guestNetIFaces1RegExp")"
       gnInfoStr2="$(ip route show | grep -E "dev[[:blank:]]* ${gnIFaceName}[[:blank:]]* proto kernel")"
       if [ "${#gnInfoStr1}" -eq 0 ] || [ "${#gnInfoStr2}" -eq 0 ]
       then
           Print_Output true "Guest Network Interface [$gnIFaceName] was NOT found." "$ERR"
           continue
       fi
       gnSubnetCIDR="$(echo "$gnInfoStr2" | awk -F' ' '{print $1}')"
       gnSubnetMask="$(echo "$gnInfoStr1" | grep -oE " Mask:${IPv4addrs_RegEx}" | awk -F':' '{print $2}')"
       gnStartIPadd="$(echo "$gnInfoStr1" | grep -oE " inet addr:${IPv4privtx_RegEx}" | awk -F':' '{print $2}')"

       if [ -z "$gnSubnetCIDR" ] || [ -z "$gnSubnetMask" ] || [ -z "$gnStartIPadd" ]
       then
           Print_Output true "Guest Network Interface [$gnIFaceName] info NOT found." "$ERR"
           continue
       fi
       if ! _Add_GuestNetwork_SubnetInfo_
       then continue
       fi
       if [ "$gnIFaceCount" -gt 0 ]
       then printf ',\n'   >> "$guestNetInfoJSfilePath"
       else printf '\n[\n' >> "$guestNetInfoJSfilePath"
       fi
       {
           printf "   { GN_IFACE: '${gnIFaceName}',\n"
           printf "     START_IP: '${gnStartIPadd}',\n"
           printf "     NET_MASK: '${gnSubnetMask}',\n"
           printf "     NET_CIDR: '${gnSubnetCIDR}'\n"
           printf '   }'
       } >> "$guestNetInfoJSfilePath"
       gnIFaceCount="$((gnIFaceCount + 1))"
   done

   if [ "$gnIFaceCount" -eq 0 ]
   then
       printf ' [];\n' >> "$guestNetInfoJSfilePath"
       _Set_FoundActiveGuestNetworks_ false
       _AllowGuestNetwork_IP_Reservations_ reset false
   else
       printf '\n];\n' >> "$guestNetInfoJSfilePath"
       if ! "$(_Is_DHCP_Static_IPs_Enabled_)" || \
          ! "$(_AllowGuestNetwork_IP_Reservations_ check)"
       then
           _AllowGuestNetwork_IP_Reservations_ disable false
       fi
   fi
   _Update_GuestNetCheck_Status_ DONE
}

##----------------------------------------##
## Modified by Martinski W. [2025-Aug-23] ##
##----------------------------------------##
MainMenu()
{
	local showexport  menuOption  srMenuOptStr  gnMenuOptStr  dhcpStaticIPsOK
	local allowGuestNetIPaddrReservations  gnAllowReservationsMenuSetting

	_HandleInvalidOption_()
	{
		[ -n "$menuOption" ] && \
		printf "\n${REDct}INVALID input [$menuOption]${CLRct}"
		printf "\nPlease choose a valid option.\n\n"
		PressEnter
	}

	printf "  ${GRNct}1${CLRct}.  Process ${GRNct}${SCRIPT_CONF}${CLRct}\n\n"

	srMenuOptStr="Save/Restore custom user icons"
	if CheckForCustomIconFiles || CheckForSavedIconFiles
	then
		printf "  ${GRNct}2${CLRct}.  ${srMenuOptStr} found in the ${GRNct}${userIconsDIRpath}${CLRct} directory\n\n"
	else
		printf "  ${GRAYEDct}2${CLRct}.  ${GRAYct}${srMenuOptStr}${CLRct}\n"
		printf "      ${GRAYct}[Currently: ${GRAYEDct} UNAVAILABLE ${CLRct}${GRAYct}]${CLRct}\n\n"
	fi

	dhcpStaticIPsOK="$(_Is_DHCP_Static_IPs_Enabled_)"
	allowGuestNetIPaddrReservations="$(_AllowGuestNetwork_IP_Reservations_ check)"
	if "$dhcpStaticIPsOK" && "$allowGuestNetIPaddrReservations"
	then gnAllowReservationsMenuSetting="${GRNct}ENABLED${CLRct}"
	else gnAllowReservationsMenuSetting="${MGNTct}DISABLED${CLRct}"
	fi

	gnMenuOptStr="Allow Guest Network Client DHCP IP Address Reservations"
	if "$dhcpStaticIPsOK" && _Get_ActiveGuestNetwork_VirtualInterfaces_
	then
		printf " ${GRNct}gn${CLRct}.  ${gnMenuOptStr}\n"
		printf "      [Currently: $gnAllowReservationsMenuSetting]\n\n"
	else
		printf " ${GRAYEDct}gn${CLRct}.  ${GRAYct}${gnMenuOptStr}${CLRct}\n"
		printf "      ${GRAYct}[Currently: ${GRAYEDct} UNAVAILABLE ${CLRct}${GRAYct}]${CLRct}\n\n"
	fi

	if _CheckFor_NVRAM_DHCP_Assignments_3004_ || \
	   _CheckFor_NVRAM_DHCP_Assignments_3006_
	then showexport=true
	else showexport=false
	fi
	if "$showexport"
	then
		printf "  ${GRNct}x${CLRct}.  Export DHCP IP address assignments from NVRAM to %s\n\n" "$SCRIPT_NAME"
	fi
	printf "  ${GRNct}u${CLRct}.  Check for updates\n"
	printf " ${GRNct}uf${CLRct}.  Update %s with latest version (force update)\n\n" "$SCRIPT_NAME"
	printf "  ${GRNct}e${CLRct}.  Exit %s\n\n" "$SCRIPT_NAME"
	printf "  ${GRNct}z${CLRct}.  Uninstall %s\n\n" "$SCRIPT_NAME"
	printf "${BOLD}##########################################################${CLEARct}\n\n"

	while true
	do
		printf "Choose an option:  "
		read -r menuOption
		case "$menuOption" in
			1)
				printf "\n"
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
				else
					_HandleInvalidOption_
				fi
				break
			;;
			x)
				if "$showexport"
				then
					printf "\n"
					if Check_Lock menu
					then
						if ! Export_FW_DHCP_NVRAM_JFFS
						then
							_Check_ActiveGuestNetwork_SubnetInfo_
						fi
					fi
					PressEnter
				else
					_HandleInvalidOption_
				fi
				break
			;;
			u)
				printf "\n"
				if Check_Lock menu; then
					Menu_Update
				fi
				PressEnter
				break
			;;
			uf)
				printf "\n"
				if Check_Lock menu; then
					Menu_ForceUpdate
				fi
				PressEnter
				break
			;;
			gn)
				printf "\nPlease wait...\n"
				if "$dhcpStaticIPsOK" && _Get_ActiveGuestNetwork_VirtualInterfaces_
				then
					if ! "$allowGuestNetIPaddrReservations"
					then
						_NoticeFor_UserCustom_IPaddr_Reservations_ true
						_AllowGuestNetwork_IP_Reservations_ enable
					else
						_AllowGuestNetwork_IP_Reservations_ disable
					fi
					echo
				elif "$dhcpStaticIPsOK"
				then
					printf "\n${WARN}No available Guest Network with a subnet range separate from the main LAN subnet was found.${CLEARct}\n\n"
				else
					printf "\n${WARN}The feature to manually assigned DHCP IP address reservations is NOT enabled on the webUI page.${CLEARct}\n\n"
				fi
				PressEnter
				break
			;;
			e)
				ScriptHeader
				printf "\n${BOLD}Thanks for using %s!${CLEARct}\n\n\n" "$SCRIPT_NAME"
				exit 0
			;;
			z)
				while true
				do
					printf "\n${BOLD}Are you sure you want to uninstall %s? (y/n)${CLEARct}\n" "$SCRIPT_NAME"
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
				_HandleInvalidOption_
				break
			;;
		esac
	done

	ScriptHeader
	MainMenu
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
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
	printf "%s will back up DHCP IP address assignments from NVRAM during installation," "$SCRIPT_NAME"
	printf "\nbut first you may wish to take screenshots of the following WebUI page:"
	printf "\n\n${GRNct}%s://%s%s/Advanced_DHCP_Content.asp${CLEARct}\n" "$httpStr" "$mainLAN_IPaddr" "$portStr"
	printf "\n${BOLD}If you wish to take screenshots, please do so now before the WebUI page\nis updated by %s${CLEARct}.\n" "$SCRIPT_NAME"
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
	Shortcut_Script create

	echo "MAC,IP,HOSTNAME,DNS" > "$SCRIPT_CONF"
	if ! Export_FW_DHCP_NVRAM_JFFS
	then
		_Check_ActiveGuestNetwork_SubnetInfo_
	fi
	Auto_DNSMASQ create

	if "$webUIupdateOK"
	then
		Print_Output true "$SCRIPT_NAME was installed successfully!" "$PASS"
	else
		Print_Output true "A problem was found when installing $SCRIPT_NAME!" "$ERR"
	fi
	Clear_Lock
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-26] ##
##----------------------------------------##
Menu_ProcessDHCPClients()
{
	printf "\nPlease wait...\n"
	if ! Process_DHCP_Clients
	then
		Print_Output true "Restarting dnsmasq for new DHCP settings to take effect." "$WARN"
		service restart_dnsmasq >/dev/null 2>&1
		echo
	fi
	Clear_Lock
}

##-------------------------------------##
## Added by Martinski W. [2025-Sep-05] ##
##-------------------------------------##
NTP_Ready()
{
	local theSleepDelay=15  ntpMaxWaitSecs=600  ntpWaitSecs

	[ "$(nvram get ntp_ready)" -eq 1 ] && return 0

	Check_Lock
	ntpWaitSecs=0
	Print_Output true "Waiting for NTP to sync..." "$WARN"

	while [ "$(nvram get ntp_ready)" -eq 0 ] && [ "$ntpWaitSecs" -lt "$ntpMaxWaitSecs" ]
	do
		sleep "$theSleepDelay"
		ntpWaitSecs="$((ntpWaitSecs + theSleepDelay))"
		if [ "$((ntpWaitSecs % 30))" -eq 0 ]
		then
			Print_Output true "Waiting for NTP to sync [$ntpWaitSecs secs]..." "$WARN"
		fi
	done

	if [ "$(nvram get ntp_ready)" -eq 1 ]
	then
		Print_Output true "NTP has synced [$ntpWaitSecs secs]. $SCRIPT_NAME will now continue." "$PASS"
	else
		Print_Output true "NTP failed to sync after 10 minutes. $SCRIPT_NAME will continue anyway." "$WARN"
	fi
	Clear_Lock
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Menu_Startup()
{
	NTP_Ready
	Check_Lock

	if [ $# -eq 0 ] || [ "$1" != "force" ]
	then sleep 5
	fi
	inStartupMode=true
	Create_Dirs
	Set_Version_Custom_Settings local
	Create_Symlinks 2>/dev/null
	Auto_Startup create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	_Update_GuestNetCheck_Status_ INIT
	_Check_ActiveGuestNetwork_SubnetInfo_
	Auto_DNSMASQ create 2>/dev/null
	Shortcut_Script create
	Mount_WebUI
	Clear_Lock
}

Menu_Update()
{
	Update_Version
	Clear_Lock
}

Menu_ForceUpdate()
{
	Update_Version force
	Clear_Lock
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
_Restore_NVRAM_DHCP_IP_Assignments_()
{
	if ! _CheckForSaved_NVRAM_DHCP_Assignments_3004_ && \
	   ! _CheckForSaved_NVRAM_DHCP_Assignments_3006_
	then return 0
	fi
	local restoredOK=false

	printf "\n${BOLD}Do you want to restore the original NVRAM DHCP assignments from before %s was installed? (y/n):${CLEARct}  " "$SCRIPT_NAME"
	read -r confirm
	case "$confirm" in
		y|Y)
			_Restore_NVRAM_DHCP_Assignments_3004_
			_Restore_NVRAM_DHCP_Assignments_3006_
		;;
	esac

	if "$doCommitNVRAM"
	then nvram commit
	fi
	if "$doCommitNVRAM" && "$restoredOK"
	then Print_Output true "The original NVRAM DHCP assignments were restored." "$PASS"
	else Print_Output true "The original NVRAM DHCP assignments were NOT restored." "$WARN"
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Menu_Uninstall()
{
	Print_Output true "Removing $SCRIPT_NAME..." "$PASS"
	Auto_Startup delete 2>/dev/null
	Auto_ServiceEvent delete 2>/dev/null
	Auto_DNSMASQ delete
	Shortcut_Script delete
	umount /www/Advanced_DHCP_Content.asp 2>/dev/null
	rm -f "$SCRIPT_DIR/Advanced_DHCP_Content.asp"
	rm -f "$guestNetInfoJSfilePath" "$dhcpGuestNetConfigFPath"

	# Maximum LEASE time in secs to store in NVRAM #
	local max7daySecs=604800
	local doCommitNVRAM=false

	if [ "$(nvram get "$DHCP_LEASE_KEYN")" -gt "$max7daySecs" ]
	then
		nvram set ${DHCP_LEASE_KEYN}="$max7daySecs"
		doCommitNVRAM=true
	fi

	_Restore_NVRAM_DHCP_IP_Assignments_

	printf "\n${BOLD}Do you want to delete %s DHCP clients and NVRAM backup files? (y/n):${CLEARct}  " "$SCRIPT_NAME"
	read -r confirm
	case "$confirm" in
		y|Y)
			rm -rf "$SCRIPT_DIR" 2>/dev/null
		;;
		*)
			:
		;;
	esac

	Set_Version_Custom_Settings delete
	rm -rf "$SCRIPT_WEB_DIR" 2>/dev/null
	rm -f "/jffs/scripts/$SCRIPT_NAME" 2>/dev/null
	Clear_Lock
	Print_Output true "Uninstall completed" "$PASS"

	if "$doCommitNVRAM"
	then
		Print_Output true "Restarting dnsmasq to restore DHCP settings." "$PASS"
		service restart_dnsmasq >/dev/null 2>&1
	fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
Check_Requirements()
{
	CHECKSFAILED="false"

	if [ "$(nvram get jffs2_scripts)" -ne 1 ]
	then
		nvram set jffs2_scripts=1
		nvram commit
		Print_Output true "Custom JFFS Scripts enabled" "$WARN"
	fi

	if ! Firmware_Version_Check || \
	   [ "$(FirmwareVersionNum "$fwInstalledBranchVer")" -lt "$(FirmwareVersionNum "3004.386.4")" ]
	then
		Print_Output true "Unsupported firmware version detected" "$ERR"
		Print_Output true "$SCRIPT_NAME requires Merlin F/W 3004.386.4 version (or later)" "$ERR"
		CHECKSFAILED="true"
	fi

	if [ "$CHECKSFAILED" = "false" ]
	then return 0
	else return 1
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
trap 'Clear_Lock; exit 10' HUP INT QUIT ABRT TERM

if [ $# -eq 1 ] && [ "$1" = "resetLock" ]
then Clear_Lock ; exit 0
fi

if [ "$SCRIPT_BRANCH" = "master" ]
then SCRIPT_VERS_INFO=""
else SCRIPT_VERS_INFO="[$versionDev_TAG]"
fi

##----------------------------------------##
## Modified by Martinski W. [2025-Sep-05] ##
##----------------------------------------##
if [ $# -eq 0 ] || [ -z "$1" ]
then
	Create_Dirs
	Set_Version_Custom_Settings local
	Create_Symlinks 2>/dev/null
	Auto_Startup create 2>/dev/null
	Auto_ServiceEvent create 2>/dev/null
	_Update_GuestNetCheck_Status_ INIT
	_Check_ActiveGuestNetwork_SubnetInfo_
	Auto_DNSMASQ create
	Shortcut_Script create
	if _CheckFor_WebGUI_Page_
	then
		ScriptHeader
		MainMenu
	else
		printf "${REDct}Exiting...${CLRct}\n\n"
	fi
	exit 0
fi

case "$1" in
	install)
		Check_Lock
		Menu_Install
		exit 0
	;;
	uninstall)
		Check_Lock
		Menu_Uninstall
		exit 0
	;;
	startup)
		shift
		Menu_Startup "$@"
		exit 0
	;;
	##----------------------------------------##
	## Modified by Martinski W. [2025-Sep-05] ##
	##----------------------------------------##
	service_event)
		if [ "$2" = "restart" ] && [ "$3" = "wireless" ]
		then
			NTP_Ready
			Print_Output true "Wireless restarted. Checking for available Guest Networks in 20 secs...." "$PASS"
			Check_Lock
			sleep 20
			_Update_GuestNetCheck_Status_ INIT
			_Check_ActiveGuestNetwork_SubnetInfo_
			Process_DHCP_Clients
			Clear_Lock
		elif [ "$2" = "start" ]
		then
			case "$3" in
				"$SCRIPT_NAME")
					Conf_FromSettings
				;;
				"${SCRIPT_NAME}backupconfig")
					BackUpConfigSettings
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
				"${SCRIPT_NAME}checkGuestNetReservations")
					_Update_GuestNetCheck_Status_ INIT
					_Check_ActiveGuestNetwork_SubnetInfo_
					Process_DHCP_Clients
				;;
				"${SCRIPT_NAME}enableGuestNetReservations")
					_AllowGuestNetwork_IP_Reservations_ enable
				;;
				"${SCRIPT_NAME}disableGuestNetReservations")
					_AllowGuestNetwork_IP_Reservations_ disable
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
		if [ $# -lt 2 ] || [ -z "$2" ]
          then
			exec "$0"
		fi
		exit 0
	;;
	checkupdate)
		Update_Check
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
