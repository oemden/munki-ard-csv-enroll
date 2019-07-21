#!/bin/bash
## AutoEnroll Computers from CSV file(s) and Using ARD fields - Inspired by : munki-autoenroll-php script
/usr/bin/clear 2>/dev/null
##
## oem at oemden dot com
##
version="1.5.7" ## Option to get csv files fom USB key
############################# EDIT START ####################################################
## ---------------------------- Jungle Options  -------------------------------------- #
host_Id_Choice="CN" # SN ( Serial Number ) | MAC ( Mac Address ) | CN ( ComputerName ) ## the Name of the host's Manifest in Munki
host_display_name_Choice="CN" ##  # SN ( Serial Number ) | MAC ( Mac Address ) | CN ( ComputerName ) ## the Name of the host's display_name Manifest in Munki
BU_ARD_Choice="ARD1" # Used to match Sal key ! if empty sal will not be configured
GP_ARD_Choice="ARD2" # Used to match Sal key ! if empty sal will not be configured
## ---------------------------- Munki / Managed Software Center ---------------------- #
DomainName="hq.example.com"
MUNKI_REPO_URL="http://munki.${DomainName}"
reset_manifest=0 ## 1 ( if you want ) | 0 ( if you don't want ) to reset the Host Manifest in the Repo | WARNING ! For now script will replace Manifest !
munki_bootstrap=0 ## If you want to bootstrap munki at first boot.
AUTH="Authorization: Basic bXVua2k6bXVua2k=" ## Please refer to: https://github.com/munki/munki/wiki/Using-Basic-Authentication

## ---------------------------- CSV FILE(S) Names ------------------------------------ #
csv_field_SEPARATOR=";" ## Eventually Change to whatever separate field you want
csv_value_SEPARATOR=" " ## for multiple extra Manifests ( TODO: or catalogs).
csv_METHOD="HTTP" ## HTTP (csv files are in munki Repo enrolltothejungle) or USB (csv files are in the same folder of the script)

## ---------------------------- EVENTUALLY edit below -------------------------------- #
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
MUNKI_ENROLL_URL="${MUNKI_ENROLL_DIR}/index.php" ## Please Do Read ReadMe file 

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
cmd_curl="/usr/bin/HTTP"
cmd_echo="/bin/echo"
cmd_touch="/usr/bin/touch"
cmd_touch="/usr/bin/touch"
cmd_cp="/bin/cp"

#################################### prepare stuff ##########################################  
function UrlCheck() {
 # check url is reachable
   "${cmd_curl}" -H "${AUTH}" -Is "${1}" | head -n 1 | awk '{print $3}' | grep "OK"
  fi
}

function UrlsAvailability {
 echo " ------------------------------------------------------------------------"
 ## is munki_repo reachable ?
  munki_url_check=$( UrlCheck "${MUNKI_REPO_URL}" )
   if [[ "${munki_url_check}" =~ "OK" ]] ; then
    printf " munki Repo URL: ${MUNKI_REPO_URL} is reachable, \n checking munki enroll URL\n"
    munkienroll_url_check=$( UrlCheck "${MUNKI_ENROLL_URL}" )
      if [[ "${munkienroll_url_check}" =~ "OK" ]] ; then
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
  cmd_echoDebug " ------------------------------------------------------------------------"
}

function PrepareWorkingDirectory {
 mkdir -p "${WorkingDirectory}"
}

######################################## CSV PART ###########################################  
function GetCsvFiles {
 for csv in "${BU_CSV_FILES[@]}"
  do
  if [[ "${csv_METHOD}" == "CURL" ]] ; then
   	"${cmd_curl}" -H "${AUTH}" -s --fail "${MUNKI_ENROLL_DIR}/${csv}" --output "${WorkingDirectory}/${csv}"
  elif [[ "${csv_METHOD}" == "USB" ]] ; then
    cp "/Volumes/bootstrap/csv/${csv}" "${WorkingDirectory}/${csv}"
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
   cmd_echoDebug "  - The csv File \"$thefilename\" is here"
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
     cmd_echoDebug " csv_HostSerial: ${csv_HostSerial} matches Host_UNIQUE_ID: ${Host_UNIQUE_ID}"
    echo " ------------------------------------------------------------------------"
     ComputerMatch="1" ; cmd_echoDebug "ComputerMatch" ; cmd_echoDebug
     hostSerial="${Host_UNIQUE_ID}" ;  cmd_echoDebug "csv_HostSerial: $csv_HostSerial" ## this is the UNIQUE ID of the computer
     hostComputerName="${csv_ComputerName}" ; cmd_echoDebug "csv_ComputerName: ${csv_ComputerName}" ## this is the ComputerName for the computer
     hostMACAddress=$(echo "${csv_MACAddress}" | sed 's/://g') ; cmd_echoDebug "csv_MACAddress: ${csv_MACAddress}" ## this is the MAC ADDRESS of the computer
     host_ARD1="${csv_host_ARD1}" ; cmd_echoDebug "csv_host_ARD1: ${csv_host_ARD1}" ## BU_BusinessUnit
     host_ARD2="${csv_host_ARD2}" ; cmd_echoDebug "csv_host_ARD2: ${csv_host_ARD2}" ## GP_Group
     host_ARD3="${csv_host_ARD3}" ; cmd_echoDebug "csv_host_ARD3: ${csv_host_ARD3}" ## KD_KIND
     host_ARD4="${csv_host_ARD4}" ; cmd_echoDebug "csv_host_ARD4: ${csv_host_ARD4}" ## TP_TYPE
     HostDefaultCatalog="${csv_HostDefaultCatalog}" ; cmd_echoDebug "csv_HostDefaultCatalog: ${csv_HostDefaultCatalog}" ## this is the default catalog for the computer 
     MunkiRepoHostSubDir="${csv_MunkiHostSubDir}" ; cmd_echoDebug "csv_MunkiHostSubDir: ${csv_MunkiHostSubDir}" ## this is the Hosts Subdir in munki_repo
     BU_Site_default_manifest="${csv_Site_default}" ; cmd_echoDebug "csv_Site_default: ${csv_Site_default}" ## this is the default manifest for all hosts
     
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

     host_extraManifests="${csv_nestedManifests}" ; cmd_echoDebug "csv_nestedManifests: ${csv_nestedManifests}"
          
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
  cmd_echoDebug "extra_manifest: ${extra_manifest}"
  host_manifests+=("${extra_manifest}")
 done
 IFS="${OLDIFS2}"
  cmd_echoDebug " ------------------------------------------------------------------------"
 for host_manifest in "${host_manifests[@]}" ; do
  cmd_echoDebug "host_manifest: ${host_manifest}"
 done
  cmd_echoDebug " ------------------------------------------------------------------------"
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
     cmd_echoDebug " ------------------------------------------------------------------------"
     jungle_BUMatch="1" ; cmd_echoDebug "jungle_BUMatch" ; cmd_echoDebug
     jungle_BU="${csv_BU}" ; cmd_echoDebug "csv_BU: ${csv_BU}" ## this is the Business Unit
     jungle_munkiReportURL="${csv_munkiReportURL}" ; cmd_echoDebug "csv_munkiReportURL: ${csv_munkiReportURL}" ## this is munkireport URL
     jungle_SalURL="${csv_SalURL}" ; cmd_echoDebug "csv_SalURL: ${csv_SalURL}" ## this is SAL URL
     jungle_HelpURL="${csv_HelpURL}" ; cmd_echoDebug "csv_HelpURL: ${csv_HelpURL}" ## this is Munki's Help URL
     jungle_ASUSURL="${csv_ASUSURL}" ; cmd_echoDebug "csv_ASUSURL: ${csv_ASUSURL}"## this is Apple Software Update URL
     cmd_echoDebug " ------------------------------------------------------------------------"
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
  cmd_echoDebug " - Reading sal keys csv file..."
 while read csv_BU_id csv_GP_id csv_BU_key
  do  
   if [[ "${csv_BU_id}" == "${host_BUMaster}" ]] && [[ "${csv_GP_id}" == "${host_GPMaster}" ]] ; then
    SalkeyMatch="1"
    host_Sal_Key="${csv_BU_key}" ; cmd_echoDebug "host_Sal_Key: ${host_Sal_Key}" 
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
  cmd_echoDebug " - Reading MunkiReport keys csv file..."
 while read csv_BU_id csv_GP_id csv_BU_key
  do  
   if [[ "${csv_BU_id}" == "${host_BUMaster}" ]] && [[ "${csv_GP_id}" == "${host_GPMaster}" ]] ; then
    MRkeyMatch="1"
    host_MR_Key="${csv_BU_key}" ; cmd_echoDebug "host_MR_Key: ${host_MR_Key}" 
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
 munki_bootstap
 if [[ -n "${jungle_munkiReportURL}" ]] ; then
   cmd_echoDebug " --- munkireport URL"
  SetHostMunkiReportsPrefs
 fi
 if [[ -n "${jungle_SalURL}" ]] ; then
   cmd_echoDebug " --- SAL URL"
  SetHostSalPrefs
 fi
 if [[ -n "${jungle_ASUSURL}" ]] ; then
   cmd_echoDebug " --- ASUS URL"
  SetHostAppleSoftwareUpdateURLPrefs
 fi
 ##let's set AppleSetupDone
 "${cmd_touch}" "${AppleSetupDone_file}"
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
    included_manifests_ArrayCheck=$( CmdPlistBuddyCheckArray "${munki_host_manifest}" "included_manifests" "${manifest}" )
    for included_manifest_Checked in "${included_manifests_ArrayCheck[@]}" ; do
     if [[ "${included_manifest_Checked}" == "${manifest}" ]] ; then
      echo "included_manifest ${manifest} already set, skipping"
     else
      CmdPlistBuddyAddArray "${munki_host_manifest}" "included_manifests" "${manifest}"
     fi
    done
 done
 
 ## Adding display_name (string)
 display_name_StringCheck=$( CmdPlistBuddyCheckString "${munki_host_manifest}" "display_name" )
 if [[ "${display_name_StringCheck}" == "" ]] ; then
    echo " Display_name not set, writing it"
     cmd_echoDebug "display_name_StringCheck ${display_name_StringCheck}" ; cmd_echoDebug "host_display_name ${host_display_name}"
    CmdPlistBuddyAddString "${munki_host_manifest}" "display_name" "${host_display_name}"
 elif [[ "${display_name_StringCheck}" != "${host_display_name}" ]] ; then
    echo " Changing display_name to ${host_display_name}"
     cmd_echoDebug "display_name_StringCheck ${display_name_StringCheck}" ; cmd_echoDebug "host_display_name ${host_display_name}"
    CmdPlistBuddyDeleteString "${munki_host_manifest}" "display_name" 
    CmdPlistBuddyAddString "${munki_host_manifest}" "display_name" "${host_display_name}"
 elif [[ "${display_name_StringCheck}" == "${host_display_name}" ]] ; then
    echo " Display_name ${host_Id} is set, skipping"
     cmd_echoDebug "display_name_StringCheck ${display_name_StringCheck}" ; cmd_echoDebug "host_display_name ${host_display_name}"
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
 curl_fn="uploaded_file=@${munki_host_manifest}" ## stupid trick to get HTTP upload working with below command 
 "${cmd_curl}" -H "${AUTH}" -F "$curl_fn" -F hostdir="${MunkiRepoHostSubDir}" -F version="${version}" "${MUNKI_ENROLL_URL}" 
}

function CleanUp {
 echo " ------------------------------------------------------------------------"
 echo " Cleaning Up"
 rm -Rf "${WorkingDirectory}"
}

function cmd_echoDebug {
 if [[ "${echoDebug}" == 1 ]] ; then
  "${cmd_echo}" "${1}"
 fi
}

function DoIt {
 UrlsAvailability
 PrepareWorkingDirectory 
 GetCsvFiles 
 GetComputerInfoFromCsv 
 GetBUJungleOptionsFromCSV 
 WriteHostConfig 
 WriteHostManifest  
 UploadHostManifest 
 CleanUp
}

############################## ENROLL to the JUNGLE #########################################  
DoIt

exit 0

######################################## TODOS ##############################################  
## Put munki_bootstrap & reset_manifest Options in BU_Munki_Hosts.csv file. TODO
## Check Potential ARD fields conflict between BU & GP - aka if BU = ARD1 GP can not be ARD1. TODO
## Backup manifest in the repo. TODO - WARNING script Does not Backup nor Updte Manifest for now.
## Update Manifest in Repo. TODO
## allow multiple catalogs. TODO
## Verify if Client_ID is empty, if empty => use host_id. DONE 
## Verify if displayname is empty => use host_id (client_identifier). DONE
## munki first boot bootstrap Option. DONE.
## Check manifest subDir in repo. [in index.php]. TODO
## Create new Manifest Subdir in repo if not exist [in index.php]. TODO
## Managing MunkiReport Business Units. DONE
## Remove some Jungle Options: aka if munkireport or sal url are found, then equals option is set. DONE.
## Deal with Target $3 for pkg or $1 for bootstrappr or standalone script. DONE
## Inject the Hosts subdirectory as a variable in the php file. DONE
## Add options LOCAL vs HTTP. TODO
#############################################################################################  
