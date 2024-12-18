#!/bin/bash
## AutoEnroll Computers from CSV file(s) and Using ARD fields - Inspired by : munki-autoenroll-php script
## Clouflare Warp Version
/usr/bin/clear 2>/dev/null
##
## oem at oemden dot com
##
version="1.8.1" ## Modifications for Cloudflare Check/ new empty file "check" in munki root dir. - renamed enroll file: index.php  to enroll.php
############################# EDIT START ####################################################
## ---------------------------- Jungle Options  -------------------------------------- #
host_Id_Choice="SN" # SN ( Serial Number ) | MAC ( Mac Address ) | CN ( ComputerName ) ## the Name of the host's Manifest in Munki
host_display_name_Choice="CN" ##  # SN ( Serial Number ) | MAC ( Mac Address ) | CN ( ComputerName ) ## the Name of the host's display_name Manifest in Munki
BU_ARD_Choice="ARD1" # Used to match Sal key ! if empty sal will not be configured
GP_ARD_Choice="ARD2" # Used to match Sal key ! if empty sal will not be configured
AppleSetupDone="1" ## 1 will create the file (/var/db/.AppleSetupDone) - usefull if you create a local admin in your enroll workflow ! # Note: this option exist in MDS.
## ---------------------------- Munki / Managed Software Center ---------------------- #
DomainName="hq.example.com"
MUNKI_REPO_URL="http://munki.${DomainName}"
reset_manifest=0 ## 1 ( if you want ) | 0 ( if you don't want ) to reset the Host Manifest in the Repo | WARNING ! For now script will replace Manifest !
munki_bootstrap=0 ## If you want to bootstrap munki at first boot. Be carefull and test it.
reboot_after_enroll=0 # 1 ( if you want ) | 0 ( if you don't want ) to reboot after enrolment #TODO
AUTH="Authorization: Basic bXVua2k6bXVua2k=" ## Please refer to: https://github.com/munki/munki/wiki/Using-Basic-Authentication

## ------------------------------- Cloudflare ---------------------------------------- #
check_for_cloudflare=0 # 1 ( if you want ) | 0 ( if you don't want ) to Check Cloudflare Status before running the enrolment
cf_team_Name="my_cf_team" # Cloudflare team Name

## ------------------------------- CSV FILE(S) --------------------------------------- #
csv_field_SEPARATOR=";" ## Eventually Change to whatever separate field you want
csv_value_SEPARATOR=" " ## for multiple extra Manifests ( TODO: or catalogs).
csv_METHOD="HTTP" ## HTTP(s) (csv files are in munki Repo enrolltothejungle) or USB (csv files must be in csv folder on the same volume as bootstrappr (for now) /Volumes/bootstrap/csv/)
USB_Volume="bootstrap" ## IMPORTANT!: csv files must be located in a csv folder at the root of the Volume

## --------------------- EVENTUALLY edit csv filenames below ------------------------- #
BU_Munki_Hosts_FileName="BU_Munki_Hosts.csv" ## csv file with your computers infos
BU_Jungle_Options_FileName="BU_Jungle_Options.csv" ## csv file with sal, asus, mr URLs
BU_SalKeys_FileName="BU_SalKeys.csv" ## csv file for sal BU/GP keys
BU_MRKeys_FileName="BU_MRKeys.csv" ## csv files for Munkireport BU/GP keys.

echoDebug=0 # print extra feedback if set on 1. low feedback if set to 0

############################# EDIT STOP #####################################################
##! DON'T EDIT BELOW UNLESS YOU KNOW WHAT YOU'RE DOING !##
#############################################################################################

MUNKI_ENROLL_DIR="${MUNKI_REPO_URL}/enrolltothejungle" ## Please Do Read ReadMe file
#MUNKI_ENROLL_CSVDIR="${MUNKI_REPO_URL}/enrolltothejungle/csv" ## TODO
MUNKI_ENROLL_URL="${MUNKI_ENROLL_DIR}/enroll.php" ## Please Do Read ReadMe file
Host_UNIQUE_ID=`ioreg -l | grep IOPlatformSerialNumber | awk '{print $4}' | cut -d \" -f 2` ## for CSV match

####################################### Welcome ############################################
echo " ------------------------- Enroll To The Jungle -------------------------"
echo " ----------------------------- Version ${version} ---------------------------- "
#################################### Target Check ##########################################
## Trying to make script working either as a pkg postinstall, bootstrappr or standalone script
## borrowing munki/bootstrappr trick
ScriptTarget="${1##*/}"
EXTENSION="${ScriptTarget##*.}"
## Getting  the target
if [[ "${EXTENSION}" == "pkg" ]] ; then
 echo " This is a pkg, script is running as a postinstall script"
  if [[ "${3}" == "/" ]] ; then
  TARGET=""  ; echo "TARGET: /"
 else
  TARGET="${3}" ; echo "TARGET: ${TARGET}"
 fi
elif [[ ! "${1}" ]] ; then
 TARGET="" ; echo " This is a script running as standalone script "
else
    echo " This is a script running as a boostrappr script "
 TARGET="${1}" ; echo "TARGET: ${TARGET}"
 boostrappr=1
fi

##### WARNING TEST with MDS twocanoes !!!

## Setting up Variables depending on the Target
WorkingDirectory="${TARGET}/private/tmp/enrolltothejungle"
PreferencesPath="${TARGET}/Library/Preferences"
munki_preferences_plist="${PreferencesPath}/ManagedInstalls.plist"
munki_bootstrap_file="${TARGET}/Users/Shared/.com.googlecode.munki.checkandinstallatstartup"
munkireport_preferences_plist="${PreferencesPath}/MunkiReport.plist"
sal_preferences_plist="${PreferencesPath}/com.salsoftware.sal.plist"
AppleSoftwareUpdate_plist="${PreferencesPath}/com.apple.SoftwareUpdate.plist"
ARD_plist="${PreferencesPath}/com.apple.RemoteDesktop.plist"
AppleSetupDone_file="${TARGET}/var/db/.AppleSetupDone}"
SysConfig_preferences="${TARGET}/Library/Preferences/SystemConfiguration/preferences.plist"

BU_CSV_FILES=( "${BU_Munki_Hosts_FileName}" "${BU_Munki_Preferences_FileName}" "${BU_Jungle_Options_FileName}" "${BU_SalKeys_FileName}" "${BU_MRKeys_FileName}")

## OsX commands
cmd_defaults="/usr/bin/defaults"
cmd_PlistBuddy="/usr/libexec/PlistBuddy"
cmd_scutil="/usr/sbin/scutil"
cmd_curl="/usr/bin/curl"
cmd_echo="/bin/echo"
cmd_touch="/usr/bin/touch"
cmd_cp="/bin/cp"

############################# Warp Addon #####################################################
app_Name="Cloudflare WARP"
cf_team_URL="https://${cf_team_Name}.cloudflareaccess.com"
cmd_warpcli="/usr/local/bin/warp-cli"
#############################################################################################

#################################### prepare stuff ##########################################
function UrlCheck() {
 # check url is reachable
  "${cmd_curl}" -o /dev/null -H "${AUTH}" -sw "%{http_code}" "${1}" | grep '^[0-9]\+'
}

function munki_UrlsAvailability {
 echo " ------------------------------------------------------------------------"
 ## is munki_repo reachable ?
 ## requires an empty file 'check' in munki_repo root_dir
 munki_url_check=$( UrlCheck "${MUNKI_REPO_URL}/check" )
 if [[ "${munki_url_check}" =~ "200" ]] ; then
  printf " munki Repo URL: ${MUNKI_REPO_URL} is reachable, \n checking munki enroll URL\n"
   munkienroll_url_check=$( UrlCheck "${MUNKI_ENROLL_URL}" )
    if [[ "${munkienroll_url_check}" =~ "200" ]] ; then
     echo " munki ENROLL URL ${MUNKI_ENROLL_URL} is reachable, we can go on"
    else
     echo " munki ENROLL URL is NOT reachable"
     echo " please check your settings, exiting"
     exit 1
    fi
 else
     echo " munki REPO URL is NOT reachable"
     echo " please check your settings, exiting"
     exit 1
 fi
  echo_Debug " ------------------------------------------------------------------------"
}

function PrepareWorkingDirectory {
 mkdir -p "${WorkingDirectory}"
}

######################################## CSV PART ###########################################
function GetCsvFiles {
 for csv_file in "${BU_CSV_FILES[@]}"
  do
  if [[ "${csv_METHOD}" == "HTTP" ]] ; then
   	"${cmd_curl}" -H "${AUTH}" -s --fail "${MUNKI_ENROLL_DIR}/${csv_file}" --output "${WorkingDirectory}/${csv_file}"
  elif [[ "${csv_METHOD}" == "USB" ]] ; then
    cp "/Volumes/${USB_Volume}/csv/${csv_file}" "${WorkingDirectory}/${csv_file}"
  fi
  done
}

function VerifyLocalCSVexist {
 thefile="$1"
 ## if in Recovery no basename - using bootstrappr trick
# thefilename=$(basename "$1")
 thefilename="${1##*/}"
 if [[ ! -f "${thefile}" ]] ; then
  echo " ! Alert ! NO CSV file, exiting"
  exit 1
 else
   echo_Debug "  - The csv File \"$thefilename\" is here"
 fi
}

function GetComputerInfoFromCsv {
 ## Get Infos from csv
 VerifyLocalCSVexist "${WorkingDirectory}/${BU_Munki_Hosts_FileName}"
 OLDIFS=$IFS
 IFS="${csv_field_SEPARATOR}"
 echo " ------------------------------------------------------------------------"
 echo " Reading master computer csv file..."
 while read csv_HostSerial csv_ComputerName csv_MACAddress csv_host_ARD1 csv_host_ARD2 csv_host_ARD3 csv_host_ARD4 csv_HostDefaultCatalog csv_MunkiHostSubDir csv_Site_default csv_nestedManifests
  do
   if [[ "${csv_HostSerial}" == "${Host_UNIQUE_ID}" ]] ; then ## verify host SerialNumber of host is in the csv file
     echo_Debug " csv_HostSerial: ${csv_HostSerial} matches Host_UNIQUE_ID: ${Host_UNIQUE_ID}"
    echo " ------------------------------------------------------------------------"
     ComputerMatch="1" ; echo_Debug "ComputerMatch" ; echo_Debug
     hostSerial="${Host_UNIQUE_ID}" ;  echo_Debug "csv_HostSerial: $csv_HostSerial" ## this is the UNIQUE ID of the computer
     hostComputerName="${csv_ComputerName}" ; echo_Debug "csv_ComputerName: ${csv_ComputerName}" ## this is the ComputerName for the computer
     hostMACAddress=$(echo "${csv_MACAddress}" | sed 's/://g') ; echo_Debug "csv_MACAddress: ${csv_MACAddress}" ## this is the MAC ADDRESS of the computer
     host_ARD1="${csv_host_ARD1}" ; echo_Debug "csv_host_ARD1: ${csv_host_ARD1}" ## BU_BusinessUnit
     host_ARD2="${csv_host_ARD2}" ; echo_Debug "csv_host_ARD2: ${csv_host_ARD2}" ## GP_Group
     host_ARD3="${csv_host_ARD3}" ; echo_Debug "csv_host_ARD3: ${csv_host_ARD3}" ## KD_KIND
     host_ARD4="${csv_host_ARD4}" ; echo_Debug "csv_host_ARD4: ${csv_host_ARD4}" ## TP_TYPE
     HostDefaultCatalog="${csv_HostDefaultCatalog}" ; echo_Debug "csv_HostDefaultCatalog: ${csv_HostDefaultCatalog}" ## this is the default catalog for the computer
     MunkiRepoHostSubDir="${csv_MunkiHostSubDir}" ; echo_Debug "csv_MunkiHostSubDir: ${csv_MunkiHostSubDir}" ## this is the Hosts Subdir in munki_repo
     BU_Site_default_manifest="${csv_Site_default}" ; echo_Debug "csv_Site_default: ${csv_Site_default}" ## this is the default manifest for all hosts

     ## Get BU Master ARD field Choice for sal & and munkiReport keys
     if [[ "${BU_ARD_Choice}" == "ARD1" ]] ; then
      host_BUMaster="${host_ARD1}"
     elif [[ "${BU_ARD_Choice}" == "ARD2" ]] ; then
      host_BUMaster="${host_ARD2}"
     elif [[ "${BU_ARD_Choice}" == "ARD3" ]] ; then
      host_BUMaster="${host_ARD3}"
     elif [[ "${BU_ARD_Choice}" == "ARD4" ]] ; then
      host_BUMaster="${host_ARD4}"
     fi

     ## Get GP Master ARD field Choice (aka Main Nested manifest) for sal & and munkiReport keys
     if [[ "${GP_ARD_Choice}" == "ARD1" ]] ; then
      host_GPMaster="${host_ARD1}"
     elif [[ "${GP_ARD_Choice}" == "ARD2" ]] ; then
      host_GPMaster="${host_ARD2}"
     elif [[ "${GP_ARD_Choice}" == "ARD3" ]] ; then
      host_GPMaster="${host_ARD3}"
     elif [[ "${GP_ARD_Choice}" == "ARD4" ]] ; then
      host_GPMaster="${host_ARD4}"
     fi

     ## Get Host Id Choice (Client_Identifier)
     if [[ "${host_Id_Choice}" == "CN" ]] ; then
      host_Id="${hostComputerName}"
      echo "ClientIdentifier based on ComputerName, and is: ${host_Id}"
     elif [[ "${host_Id_Choice}" == "MAC" ]] ; then
      host_Id="${hostMACAddress}"
      echo "ClientIdentifier based on MACAddress" ; echo "host_Id: ${host_Id}"
     elif [[ "${host_Id_Choice}" == "SN" ]] ; then
      host_Id="${hostSerial}"
      echo "ClientIdentifier based on Serial Number" ; echo "host_Id: ${host_Id}"
     elif [[ "${host_Id_Choice}" == "" ]] ; then
      host_Id="${hostSerial}"
      echo "ClientIdentifier not set, Using Serial Number" ; echo "host_Id: ${host_Id}"
     fi
     munki_host_manifest="${WorkingDirectory}/${host_Id}" ## set the computerManifest filename

     ## Get Host display_name Choice
     if [[ "${host_display_name_Choice}" == "CN" ]] ; then
      host_display_name="${hostComputerName}"
      echo "Host Display Name based on ComputerName, and is: ${host_display_name}"
     elif [[ "${host_display_name_Choice}" == "MAC" ]] ; then
      host_display_name="${hostMACAddress}"
      echo "Host Display Name based on MACAddress and is: ${host_display_name}"
     elif [[ "${host_display_name_Choice}" == "SN" ]] ; then
      host_display_name="${hostSerial}"
      echo "Host Display Name based on Serial Number and is: ${host_display_name}"
     elif [[ "${host_display_name_Choice}" == "" ]] ; then
      host_display_name="${hostComputerName}"
      echo "Host Display Name not set, Using ComputerName: ${host_display_name}"
     fi
     munki_host_display_name="${host_display_name}" ## set the computerManifest filename

     host_extraManifests="${csv_nestedManifests}" ; echo_Debug "csv_nestedManifests: ${csv_nestedManifests}"

     ## are hosts Manifests in a sub dir on munki_Repo ?
     if [[ ! "${MunkiRepoHostSubDir}" ]] ; then
      host_ClientIdentifier="${host_Id}"
     else
      host_ClientIdentifier="${MunkiRepoHostSubDir}/${host_Id}"
     fi
    fi
  done < "${WorkingDirectory}/${BU_Munki_Hosts_FileName}" #ok

  if [[ "$ComputerMatch" != "1" ]] ; then
   echo "Computer not found, exiting"
   exit 1
  fi
 IFS="$OLDIFS"
 ComputeHostIncludedManifests
}

function ComputeHostIncludedManifests {
 echo " ------------------------------------------------------------------------"
 host_manifests=( "${host_ARD1}" "${host_ARD2}" "${host_ARD3}" "${host_ARD4}" "${BU_Site_default_manifest}" )
 host_extraManifests_array=($host_extraManifests)
 OLDIFS2="${IFS}"
 IFS="${csv_value_SEPARATOR}"
 for extra_manifest in "${host_extraManifests_array[@]}" ; do
  echo_Debug "extra_manifest: ${extra_manifest}"
  host_manifests+=("${extra_manifest}")
 done
 IFS="${OLDIFS2}"
  echo_Debug " ------------------------------------------------------------------------"
 for host_manifest in "${host_manifests[@]}" ; do
  echo_Debug "host_manifest: ${host_manifest}"
 done
  echo_Debug " ------------------------------------------------------------------------"
}

function GetBUJungleOptionsFromCSV {
 VerifyLocalCSVexist "${WorkingDirectory}/${BU_Jungle_Options_FileName}"
 OLDIFS=$IFS
 IFS="${csv_field_SEPARATOR}"
 echo " ------------------------------------------------------------------------"
 echo " Reading Munki BU preferences csv file..."
 while read csv_BU csv_munkiReportURL csv_SalURL csv_HelpURL csv_ASUSURL
  do
   if [[ "${csv_BU}" == "${host_BUMaster}" ]] ; then ## verify host SerialNumber of host is in the csv file
     echo_Debug " ------------------------------------------------------------------------"
     jungle_BUMatch="1" ; echo_Debug "jungle_BUMatch" ; echo_Debug
     jungle_BU="${csv_BU}" ; echo_Debug "csv_BU: ${csv_BU}" ## this is the Business Unit
     jungle_munkiReportURL="${csv_munkiReportURL}" ; echo_Debug "csv_munkiReportURL: ${csv_munkiReportURL}" ## this is munkireport URL
     jungle_SalURL="${csv_SalURL}" ; echo_Debug "csv_SalURL: ${csv_SalURL}" ## this is SAL URL
     jungle_HelpURL="${csv_HelpURL}" ; echo_Debug "csv_HelpURL: ${csv_HelpURL}" ## this is Munki's Help URL
     jungle_ASUSURL="${csv_ASUSURL}" ; echo_Debug "csv_ASUSURL: ${csv_ASUSURL}"## this is Apple Software Update URL
     echo_Debug " ------------------------------------------------------------------------"
   fi
  done < "${WorkingDirectory}/${BU_Jungle_Options_FileName}" #ok

  if [[ "${jungle_BUMatch}" != "1" ]] ; then
   echo "BusinessUnit Infos not found, skipping"
  fi
 IFS="$OLDIFS"
 GetSalKey
 GetMRKey
}

function GetSalKey {
 VerifyLocalCSVexist "${WorkingDirectory}/${BU_SalKeys_FileName}"
 OLDIFS=$IFS
 IFS="${csv_field_SEPARATOR}"
 echo " ------------------------------------------------------------------------"
  echo_Debug " - Reading sal keys csv file..."
 while read csv_BU_id csv_GP_id csv_BU_key
  do
   if [[ "${csv_BU_id}" == "${host_BUMaster}" ]] && [[ "${csv_GP_id}" == "${host_GPMaster}" ]] ; then
    SalkeyMatch="1"
    host_Sal_Key="${csv_BU_key}" ; echo_Debug "host_Sal_Key: ${host_Sal_Key}"
   fi
  done < "${WorkingDirectory}/${BU_SalKeys_FileName}"
  if [[ "$SalkeyMatch" != "1" ]] ; then
   echo "Sal BusinessUnit Infos not found, skipping"
  fi
 IFS="$OLDIFS"
}

function GetMRKey {
 VerifyLocalCSVexist "${WorkingDirectory}/${BU_MRKeys_FileName}"
 OLDIFS=$IFS
 IFS="${csv_field_SEPARATOR}"
 echo " ------------------------------------------------------------------------"
  echo_Debug " - Reading MunkiReport keys csv file..."
 while read csv_BU_id csv_GP_id csv_BU_key
  do
   if [[ "${csv_BU_id}" == "${host_BUMaster}" ]] && [[ "${csv_GP_id}" == "${host_GPMaster}" ]] ; then
    MRkeyMatch="1"
    host_MR_Key="${csv_BU_key}" ; echo_Debug "host_MR_Key: ${host_MR_Key}"
   fi
  done < "${WorkingDirectory}/${BU_MRKeys_FileName}"
  if [[ "$MRkeyMatch" != "1" ]] ; then
   echo "MunkiReport BusinessUnit Infos not found, skipping"
  fi
 IFS="$OLDIFS"
}

######################## macOs Commands #######################################
function CmdDefaultsWritePlist() {
 ## ONLY works if file ends with .plist - use PlistBuddy for Manifest file
 ##$1 is the preferences file
 ##$2 is the preferences Key
 ##$3 is the Key cond (bolean -integer...)
 ##$4 is the Key value
 if [[ ! "${4}" ]] ; then
  echo "Key \"${2}\" as no value for plist \"${1}\" skipping"  ## if the Key value is empty, skip.
 else
  "${cmd_defaults}" write "${1}" "${2}" "${3}" "${4}"
 fi
}

function CmdPlistBuddyCheckArray() {
 ## $1 manifest file
 ## $2 Key Name
 ## $3 Key Value
 ## add Key
 "${cmd_PlistBuddy}" -c "print :${2}" "${1}" | grep -Ev "{|}" | sed 's/ //g' | grep "${3}"
}

function CmdPlistBuddyCheckString() {
 ## $1 manifest file
 ## $2 Key Name
 ## check Key
 "${cmd_PlistBuddy}" -c "print ${2}" "${1}"  2>/dev/null
}

function CmdPlistBuddyAddArray() {
 ## $1 manifest file
 ## $2 Key Name
 ## $3 Key Value
 "${cmd_PlistBuddy}" -c "add :${2} array" "${1}" 2>/dev/null ## add Key
 "${cmd_PlistBuddy}" -c "add :${2}:1 string ${3}" "${1}"  ## add value
}

function CmdPlistBuddyAddString() {
 ## $1 manifest file
 ## $2 Key Name
 ## $3 Key Value
 "${cmd_PlistBuddy}" -c "add ${2} string ${3}" "${1}"
}

function CmdPlistBuddyDeleteString() {
 ## $1 manifest file
 ## $2 Key Name
 "${cmd_PlistBuddy}" -c "delete ${2}" "${1}"
}

###################### Set host Infos subfunctions ############################
## Set host ARD fields
function SetHostARDFields {
 echo "SetHostARDFields"
 "${cmd_defaults}" write "${ARD_plist}" Text1 "${host_ARD1}"
 "${cmd_defaults}" write "${ARD_plist}" Text2 "${host_ARD2}"
 "${cmd_defaults}" write "${ARD_plist}" Text3 "${host_ARD3}"
 "${cmd_defaults}" write "${ARD_plist}" Text4 "${host_ARD4}"
}

## set ComputerName, LocalHostName, HostName
function SetHostInfos {
 if [[ "${boostrappr}" == 1 ]] ; then

 ##### WARNING TEST with MDS twocanoes !!!

  ##scutil won't make it in recovery ; using defaults
  "${cmd_defaults}" write "${SysConfig_preferences}" "{System = {Network = {HostNames = {LocalHostName = '${hostComputerName}';};};System = {ComputerName = '${hostComputerName}';HostName = '${hostComputerName}.${DomainName}';};};}"
 else
  ## running as standalone script or postinstall script ## WARNING (for now) DO NOT USE this script as a bootstrappr postinstall pkg, only as a bootstrappr script!!
  "${cmd_scutil}" --set ComputerName "${hostComputerName}"
  "${cmd_scutil}" --set LocalHostName "${hostComputerName}"
  "${cmd_scutil}" --set HostName "${hostComputerName}.${DomainName}"
 fi
}

## Creating Host Munki Preferences
function SetHostMunkiPrefs {
 #Basic munki Settings
 echo "Writing munki Preferences..."
 echo " Writing munki ClientIdentifier"
 CmdDefaultsWritePlist "${munki_preferences_plist}" ClientIdentifier -string "${host_ClientIdentifier}"
 echo " Writing munki SoftwareRepoURL"
 CmdDefaultsWritePlist "${munki_preferences_plist}" SoftwareRepoURL -string "${MUNKI_REPO_URL}"
 if [[ -n "${AUTH}" ]] ; then
  echo " Writing munki http authentication"
  CmdDefaultsWritePlist "${munki_preferences_plist}" AdditionalHttpHeaders -string "${AUTH}"
 fi
 if [[ -n "${jungle_HelpURL}" ]] ; then
  echo " Writing munki HelpURL"
  CmdDefaultsWritePlist "${munki_preferences_plist}" HelpURL -string "${jungle_HelpURL}"
 fi
}

function SetHostMunkiReportsPrefs {
 #Basic Settings
 echo "Writing munkiReport Preferences"
 CmdDefaultsWritePlist "${munkireport_preferences_plist}" BaseUrl -string "${jungle_munkiReportURL}"
 CmdDefaultsWritePlist "${munkireport_preferences_plist}" Passphrase -string "${host_MR_Key}"
 if [[ -n "${AUTH}" ]] ; then
  CmdDefaultsWritePlist "${munkireport_preferences_plist}" UseMunkiAdditionalHttpHeaders -bool true
 fi
}

function SetHostSalPrefs {
 #Basic Settings
 echo "Writing sal Preferences"
 CmdDefaultsWritePlist "${sal_preferences_plist}" ServerURL -string "${jungle_SalURL}"
 CmdDefaultsWritePlist "${sal_preferences_plist}" key -string "${host_Sal_Key}"
}

function SetHostAppleSoftwareUpdateURLPrefs {
 #Basic Settings
 echo "Writing Apple Software Update Preferences"
 CmdDefaultsWritePlist "${AppleSoftwareUpdate_plist}" CatalogURL -string "${jungle_ASUSURL}"
}

### Write Host config
function WriteHostConfig {
 SetHostARDFields
 SetHostInfos
 SetHostMunkiPrefs
 munki_bootstap ## Maybe not a good idea in THIS script
 if [[ -n "${jungle_munkiReportURL}" ]] ; then
   echo_Debug " --- munkireport URL"
  SetHostMunkiReportsPrefs
 fi
 if [[ -n "${jungle_SalURL}" ]] ; then
   echo_Debug " --- SAL URL"
  SetHostSalPrefs
 fi
 if [[ -n "${jungle_ASUSURL}" ]] ; then
   echo_Debug " --- ASUS URL"
  SetHostAppleSoftwareUpdateURLPrefs
 fi
 ##let's set AppleSetupDone
 if [[ "${AppleSetupDone}" == 1 ]] ; then
  "${cmd_touch}" "${AppleSetupDone_file}"
 fi
}

function munki_bootstap {
 if [[ "${munki_bootstrap}" == 1 ]] ; then
  "${cmd_touch}" "${munki_bootstrap_file}"
 fi
}

######################### Host MANIFEST ( for MUNKI REPO ) ##################################
function WriteHostManifest {

 echo " Creating host munki Manifest for munki repo"
 CheckIfHostManifestExistOnMunkiRepo

 ## Adding catalog (Array)
 for catalog in "${HostDefaultCatalog[@]}" ; do
    catalog_ArrayCheck=$( CmdPlistBuddyCheckArray "${munki_host_manifest}" "catalogs" "${catalog}" )
    for catalog_Checked in "${catalog_ArrayCheck[@]}" ; do
     if [[ "${catalog_Checked}" == "${catalog}" ]] ; then
      echo " Catalog ${catalog} already set, skipping"
     else
      CmdPlistBuddyAddArray "${munki_host_manifest}" "catalogs" "${catalog}"
     fi
    done
 done

 ## Adding included_manifests (Array)
 for manifest in "${host_manifests[@]}" ; do
 	# check if the manifest variable is not empty
 	if [[ "${manifest}" != "" ]] ; then
     included_manifests_ArrayCheck=$( CmdPlistBuddyCheckArray "${munki_host_manifest}" "included_manifests" "${manifest}" )
     for included_manifest_Checked in "${included_manifests_ArrayCheck[@]}" ; do
      if [[ "${included_manifest_Checked}" == "${manifest}" ]] ; then
       echo "included_manifest ${manifest} already set, skipping"
      else
       CmdPlistBuddyAddArray "${munki_host_manifest}" "included_manifests" "${manifest}"
      fi
     done
    fi
 done

 ## Adding display_name (string)
 display_name_StringCheck=$( CmdPlistBuddyCheckString "${munki_host_manifest}" "display_name" )
 if [[ "${display_name_StringCheck}" == "" ]] ; then
    echo " Display_name not set, writing it"
     echo_Debug "display_name_StringCheck ${display_name_StringCheck}" ; echo_Debug "host_display_name ${host_display_name}"
    CmdPlistBuddyAddString "${munki_host_manifest}" "display_name" "${host_display_name}"
 elif [[ "${display_name_StringCheck}" != "${host_display_name}" ]] ; then
    echo " Changing display_name to ${host_display_name}"
     echo_Debug "display_name_StringCheck ${display_name_StringCheck}" ; echo_Debug "host_display_name ${host_display_name}"
    CmdPlistBuddyDeleteString "${munki_host_manifest}" "display_name"
    CmdPlistBuddyAddString "${munki_host_manifest}" "display_name" "${host_display_name}"
 elif [[ "${display_name_StringCheck}" == "${host_display_name}" ]] ; then
    echo " Display_name ${host_Id} is set, skipping"
     echo_Debug "display_name_StringCheck ${display_name_StringCheck}" ; echo_Debug "host_display_name ${host_display_name}"
 fi
}

function CheckIfHostManifestExistOnMunkiRepo {
##  check if Manifest already exist in munki repo to keep extra manifest customisation
 if [[ "${reset_manifest}" == 0 ]] && [[ "${munki_url_check}" =~ "OK" ]] ; then
   echo " Reset Manifest Option is FALSE, will update host manifest if it exist"
 munki_host_manifest_check=$( UrlCheck "${MUNKI_REPO_URL}/manifests/${host_ClientIdentifier}" )
  if [[ "${munki_host_manifest_check}" =~ "OK" ]] ; then
   echo " host manifest ${host_ClientIdentifier} exists in repo, downloading it"
   "${cmd_curl}" -H "${AUTH}" -s --fail "${MUNKI_REPO_URL}/manifests/${host_ClientIdentifier}" --output "${WorkingDirectory}/${host_Id}"
  fi
 elif [[ "${reset_manifest}" == 1 ]] ; then
  echo " Reset Manifest Option is TRUE, will replace host manifest"
 fi
}

function UploadHostManifest {
 echo " ------------------------------------------------------------------------"
 echo " Uploading host Manifest to munki_repo"
 curl_fn="uploaded_file=@${munki_host_manifest}" ## stupid trick to get curl upload working with below command
 "${cmd_curl}" -H "${AUTH}" -F "$curl_fn" -F hostdir="${MunkiRepoHostSubDir}" -F version="${version}" "${MUNKI_ENROLL_URL}"
}

function CleanUp {
 echo " ------------------------------------------------------------------------"
 echo " Cleaning Up"
 rm -Rf "${WorkingDirectory}"
}

function echo_Debug {
 if [[ "${echoDebug}" == 1 ]] ; then
  "${cmd_echo}" "${1}"
 fi
}

function EndIt {
 ## Source : https://technology.siprep.org/deploying-munki-with-mosyle-mdm/
 ## Wait until the setup assistant is done...
 until [ -f "/var/db/.AppleSetupDone" ]; do
  ## If it's not done yet, wait 2 seconds to check again
  sleep 2
 done

 ## Now that setup assistant is done, reboot the machine, since Munki requires a reboot after installation
 if [[ "${reboot_after_enroll}" == 1 ]]; then
  sleep 10
  echo "rebooting now"
  /sbin/shutdown -r now
 fi
}

################################ Cloudflare Warp CHECK ######################################
# Warp must be running for munki to be reacheable

function warp_App_Installation {
# if system_profiler SPApplicationsDataType | grep -iq "${app_Name}" ; then
 if system_profiler SPApplicationsDataType | grep -i "${app_Name}" ; then
  #echo_Debug " ${app_Name} is installed"
  App_installed="OK"
 else
  echo " ${app_Name} is Not installed"
 fi
}

function warp_UrlsAvailability {
 team_url_check=$( UrlCheck "${cf_team_URL}" )
 if [[ "${team_url_check}" == "200" ]] ; then
  #echo_Debug " Team URL: ${cf_team_Name} is reachable"
  team_url_access="OK"
 else
  echo " Team URL: ${cf_team_Name} is NOT reachable"
 fi
}

function check_warp_status() {
 #if "${cmd_warpcli}" status | grep -iq "Success" ; then
 if "${cmd_warpcli}" status | grep -i "Connected" ; then
  #echo_Debug " Warp Status is Connected"
  warp_status="OK"
 else
  echo " Warp Status is Disconnected"
 fi
}

function Cloudflare_Checked {
 if [[ "${check_for_cloudflare}" == 1 ]] ; then
  echo "Warp check requested"
  warp_App_Installation
  warp_UrlsAvailability
  check_warp_status
  if [[ "${App_installed}" == "OK" ]] && [[ "${team_url_access}" == "OK" ]] && [[ "${warp_status}" == "OK" ]] ; then
   echo " Warp Setup OK, Continuing to enroll in munki"
  else
   echo " Warp Setup KO, Can't continue to munki enrolment"
   exit 1
  fi
 fi
}

#############################################################################################

function DoIt {
 Cloudflare_Checked
 munki_UrlsAvailability
 PrepareWorkingDirectory
 GetCsvFiles
 GetComputerInfoFromCsv
 GetBUJungleOptionsFromCSV
 WriteHostConfig
 WriteHostManifest
 UploadHostManifest
 CleanUp
 EndIt
}

############################## ENROLL to the JUNGLE #########################################
DoIt

exit 0

######################################## TODOS ##############################################
## Check Warp Status before running. DONE
## Options yes or no SAL aka if no CSV don't fail
## Options reboot or not selon postinstll par ex.
## Put munki_bootstrap & reset_manifest Options in BU_Munki_Hosts.csv file. TODO
## Check Potential ARD fields conflict between BU & GP - aka if BU = ARD1 GP can not be ARD1. TODO
## Backup manifest in the repo. TODO - WARNING script Does not Backup nor Updte Manifest for now.
## Update Manifest in Repo. TODO
## allow multiple catalogs. TODO
## allow for alternate http server for the csv files. TODO
## Verify if Client_ID is empty, if empty => use host_id. DONE
## Verify if displayname is empty => use host_id (client_identifier). DONE
## munki first boot bootstrap Option. DONE.
## Check manifest subdir in repo. [in index.php]. TODO
## Create new Manifest Subdir in repo if not exist [in index.php]. TODO
## Managing MunkiReport Business Units. DONE
## Remove some Jungle Options: aka if munkireport or sal url are found, then equals option is set. DONE.
## Deal with Target $3 for pkg or $1 for bootstrappr or standalone script. DONE
## Inject the Hosts subdirectory as a variable in the php file. DONE
## Add options LOCAL vs CURL. ONGOING
## customize Volume Name in USB case TODO
#############################################################################################
