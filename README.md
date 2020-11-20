# Usage

## Authentication

### Development

You probably want to authenticate with your server credentials:

```powershell
$jamf = [JAMF]::new('https://jamf.example.com', (Get-Credential))
```

### Production

You probably want the authenticate with an environment variable.
Here's how to create the environment variable:

```powershell
$userpass = 'user|P@$$w0rd!' # Pipe chars (|) are supported in the password but not the username.
$bytes = [System.Text.Encoding]::Utf8.GetBytes($userpass)
$env:JamfCreds = [Convert]::ToBase64String($bytes)
```

Here's how to use the environment variable:

```powershell
$jamf = [JAMF]::new('https://jamf.example.com', (ConvertTo-SecureString $env:JamfCreds -AsPlainText -Force))
```

## Get List of Computers

```powershell
$computers = $jamf.getComputers()
```

## Get List of Managed Computers

```powershell
$computers = $jamf.getManagedComputers()
```

## Get Extension Attributes from a Computer

```powershell
$computerId = 1142
$extensionAttributes = $jamf.getComputerExtensionAttributes($computerId)
```

## Get an Extension Attribute from a Computer

```powershell
$computerId = 1142
$extensionAttributes = $jamf.getComputerExtensionAttribute($computerId, 'lldp')
```

# Examples 

## Get LLDP Attribute from All Managed Computers

```powershell
$jamf = [JAMF]::new('https://jamf.example.com', (ConvertTo-SecureString $env:JamfCreds -AsPlainText -Force))

[Collections.ArrayList] $lldps = @()

foreach ($computer in $jamf.getManagedComputers()) {
    $lldps.Add(@{
        Id = $computer.id
        Name = $computer.Name
        LLDP = ([xml] $jamf.getComputerExtensionAttribute($computer.id, 'LLDP').values).lldp
    }) | Out-Null
}
```
