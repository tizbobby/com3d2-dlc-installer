## Usage

Drop this script into the directory of your DLC installation folders

The DLC installers need to be unzipped and thrown into this format:

![DLC folder format](https://user-images.githubusercontent.com/33788253/124402012-ad799980-dd03-11eb-82e1-0c27bb89a6d0.png)

Then just run the script with Powershell. The script will look for any DLC installers in folders and subfolders.

## Details

Some DLCs are in new CREdit format so they don't work with the bulk installer yet:

![New CREdit installer folders](https://user-images.githubusercontent.com/33788253/124401982-7d31fb00-dd03-11eb-8142-0e7954a90738.png)

You need to install these manually.

----

You can spot DLCs with issues from the WARNINGs in the PowerShell script.

![DLCs with issues](https://user-images.githubusercontent.com/33788253/124402006-a5b9f500-dd03-11eb-9ade-cfdba7ef3971.png)

You may need to install these manually.

## Credits

Original script is by [@lialosiu](https://github.com/lialosiu/com3d2-dlc-installer), I improved folder parsing and handling of invalid folders, and fixed update.lst writing corrupting the game installation.
