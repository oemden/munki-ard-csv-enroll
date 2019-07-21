# munki-ard-csv-enroll 

##CSV Files templates & options

Details and fields explained.

### BU_Munki_Hosts.csv

**This file is mandatory, the whole script relies on it ;)**

|Field|Value|Example|Comment|
|---|---|---|---|
|HostSerial|ABCDEF12345|Host Serial Number. This is the Unique Id to match the computer| Mandatory|
|ComputerName|Computer01|the Computer Name| Mandatory|
|MAC|AA:00:BB:11:CC:22|the Computer Mac address | Only if you plan to use it as Client_id|
|ARD1|BU_BusinessUnit| BU_HeadQuarter,BU_GeneralQuarter, etc... |
|ARD2|GP_Group|GP_Graphics, GP_Accounting, etc ...|
|ARD3|KD_Kind|KD_Client - KD_Server, etc...|
|ARD4|TP_Type|TP_VM - TP_VIP etc....|
|HostDefaultCatalog|production|manifest (main) catalog|string for now, array to come|
|MunkiHostSubDir|HOSTS|If like me you put your hosts manifests in a subfolder in the munki_repo.| if set, manifest file will be uploaded in the manifets subdirectory. If not set manifest file will be uploaded in manifests directory.|
|Site_default_manifest|BU_site_default|a default manifest you may want to add to all computers. |can be empty|
|csv_nestedManifests|customManifest1 customManifest2|extra(s) manifest(s) you may want to add to all computers. |can be empty. separator as to be set in script Options.|


[**Computers informations BU_Munki_Hosts.csv template**](enrolltothejungle/BU_Munki_Hosts.csv)

--

### BU_Jungle_Options.csv

This file (or field) is optionnal. 

If the file exists, you can let some field empty and option will not be set.
You have to set the Business Unit, if using any field.

Those settings can also be set later on by other ways, like when installing munki report or sal client packages

|Field|Value|Comment|
|---|---|---|
|BU|BU_HQ|used to match the Business Unit of the host aka BU_ARD_Choice script option 
|munkiReportURL|http://mr.hq.example.com| munki-report url
|SalURL|http://sal.hq.example.com|sal url
|HelpURL|http://help.hq.example.com|munki help url
|ASUSURL|http://rsu.hq.example.com/index.sucatalog|Apple Software Update - Pref not set in munki

[**BU_Jungle_Options.csv template**](enrolltothejungle/BU_Jungle_Options.csv)

--

### BU_SalKeys.csv

This file is optionnal - If not present, Sal Business Unit  & Group Preferences won't be set. 

|sal Business Unit|sal BU Group|sal Key|
|---|---|---|
|BU_HQ|GP_ACCOUNTING|jj5tghhmlsemqzy5kb4zk4up7l5pzaq7w4tlezvd73z9qfgkfgkfgdsudd5y3neiuop0mmyn5gnhark9n8lmx7|
|BU_HQ|GP_DESIGN|eac7ztlezvd7364qwybv3jj5tghhmlseorzy5kb4zk4up7l5pzaq7kukruop0mmyn5gnhark9n8lmx0|
|BU_GQ|GP_CREA|jj5tghhmlszzqzy5kb4zk4up7l5pzaq7w4tlezvd73z9qfgkfgkfgdsudd5y3neiuop0mmyn5gnhark9n8l100|
|BU_GQ|GP_DESIGN|eac7ztlezvd0000qwybv3jj5tghhmlseorzy5kb4zk4up7l5pzaq7kukruop0mmyn5gnhark9n8lmx8|

[**BU_SalKeys.csv template**](enrolltothejungle/BU_SalKeys.csv) 

--

### BU_MRKeys.csv

This file is optionnal - If not present, MunkiReport Business Unit  & Group Preferences won't be set.

|MunkiReport Business Unit| MunkiReport BU Group| MunkiReport Key|
|---|---|---|
|BU_HQ|GP_ACCOUNTING| 96523A7B-C3AD-491E-BE67-53C2298858A1|
|BU_HQ|GP_DESIGN| 96523A7C-C3AD-491E-BE67-53C2298858A2 |
|BU_GQ|GP_CREA| 96523A7D-C3AD-491E-BE67-53C2298858A3 |
|BU_GQ|GP_DESIGN| 96523A7E-C3AD-491E-BE67-53C2298858A4 |

**[BU_MRKeys.csv template](enrolltothejungle/BU_MRKeys.csv)** 

--




