# munki-ard-csv-enroll 

##Enroll computers from csv files and using ARD fields


This script enrolls computers using csv files to extract host Enrollment options and matches ARD fields of the computer to some infos (included_manifests). Limited to 4 fields as there are only 4 available ARD fields.

The script will also create munki host Manifest file on the Host and then upload it to the munki_repo. Thus being able to use macOs "only" commands `defaults` or `PlistBuddy` and not depend on the server hosting the munki_repo.

it can be runned from ( the munki) bootstrappr as a script, as a postinstall script in a pkg, or directly from a computer and even as a nopkg in munki.

**2021 update**: 

I use this script for quite some time now ( 2019 ) and it works as expected

It works as a "Custom Command" in Mosyle. 

I decided to use it as a post_install script for an Install-PKG of the Munkitools-DEP install within Mosyle. Works super fine and I use for all my (re)enroll-deployments. 


**Apple Remote Desktop fields**

ARD fields can be usefull.

I use them to rapidly know host enrollment infos directly from a host (mainly Sal and/or MunkiReport Business Units & Groups),  

Or for sorting Computers in Remote Desktop or use ARD fields as munki conditions. 

For example, this is how I use the fields, to reflect host manifests.

- ARD1_KEY = "BU_BusinessUnit" # for example: BU_CompanyOne / BU_CompanyTwo
- ARD2_KEY = "GP_Group" # for example: GP_Graphics, GP_Accounting, etc ...
- ARD3_KEY = "KD_Kind" # for example: KD_Client / KD_Server, etc...
- ARD4_KEY = "TP_Type" # for example: TP_VM / TP_VIP etc....

BU_CompanyOne, GP_Graphics, KD_Client, TP_VM are munki's manifests names.


**csv files**

Why csv files ? 

Well I use csv files for inventory in wich I list all the computers and their informations. 

Basically, it was based on the DeployStudio csv model to import Computers. 

And csv files are Easy to maintain and modify.

**Background History**

Script was originally used in Deploy Studio Enroll and/or Deploy Workflows. 
It has worked seamlessly since 2015. 

I called it Deploy To The Jungle. 

The jungle for me, represents munki, munki-report, sal, reposado...

One (big) caveat of the script was that my munki_repo directory had to be reachable from the same Deploy Studio file Share. 

And as you may guess, munki was hosted in an OsXserver.

Deploy Studio and munki sitting in subfolders within it. Allowing write access to munki_repo from the DeployStudio Runtime mounted Volume.

That way, Deploy Studio Workflows could write hosts manifests in munkiRepo during enrollement using native macOs commands.

Csv files where sitting in DeployStudio directory.

As Apple is changing things (with T2 chips), relaying on Deploy Studio for munki Enrollment had to change. 

Relaying on macOsX Server web hosting services (or anything else) too.

Script now gets csv files from munki_repo, and does not rely anymore on DeployStudio.

**Script Workflow**

- Checks munki_repo URL and enrolltothejungle URL availabilty
- Download csv files from munki_repo/enrolltothejungle
- extract Computer's munki Settings
- extract Computer's Jungle Settings
- Configure munki ManagedInstalls.plist Preferences settings.
- Configure munki MunkiReport.plist Preferences settings.
- Configure com.salsoftware.sal.plist Preferences settings.
- Configure com.apple.SoftwareUpdate.plist CatalogURL Preference.
- Configure com.apple.RemoteDesktop.plist ARD fields Preference.
- Create the (munki) host manifest (compares it if exists on the repo).
- Upload host manifest on munki_repo. 


## Script Usage

You need to edit the script options. See below for available options.

Copy the `enrolltothejungle` directory in your munki_repo.

Edit the csv files, and the script as needed.

When done, place the script in the bootstrappr packages folder and follow bootstrappr instructions.

## Script Options


|Option|Value|Comment|
|---|---|---|
|host_Id_Choice|`SN` ( Serial Number ) - `MAC` ( Mac Address ) - `CN` ( ComputerName )| The Name of the host's `Manifest` in Munki|
|display_name| `SN` ( Serial Number ) - `MAC` ( Mac Address ) - `CN` ( ComputerName )| The `display_name` in the manifest of the host in Munki |
|BU_ARD_Choice|ARD1|Used to match Sal key ! if empty sal will not be configured|
|GP_ARD_Choice|ARD2|Used to match Sal key ! if empty sal will not be configured |
|DomainName|hq.example.com|The domain name|
|MUNKI_REPO_URL|http://munki.${DomainName} |munki_repo url|
|MUNKI_ENROLL_DIR|${MUNKI_REPO_URL}/enrolltothejungle |munki_enroll subdirectory url (containing csv files)|
|MUNKI_ENROLL_URL|${MUNKI_ENROLL_DIR}/index.php | munki_enroll upload php file (defaults to `index.php`).|
|reset_manifest|0| 1 ( if you want ) - 0 ( if you don't want ) to reset the Host Manifest in the Repo. Will be in csv soon.|
|munki_bootstrap|0| 1 ( if you want ) - 0 ( if you don't want ) If you want to bootstrap munki at first boot. Will be in csv soon.|
|AUTH|Authorization: Basic bXVua2k6bXVua2k	|munki_repo http basic authentification|"
|csv_SEPARATOR|; | the csv separator field used in the `BU_Munki_Hosts.csv`. Eventually Change to whatever separate field you use|
|value_SEPARATOR| | the field separator used in the `csv_nestedManifests` field in  `BU_Munki_Hosts.csv`. Eventually Change to whatever separate field you use|


