class JAMF {
    [pscredential]  $Credential
    [string]        $Token
    [uri]           $URL

    # Constructors
    JAMF ([string] $url, [securestring] $credstr) {
        $this.url = $url
        $this.Credential = $this.getCredString($credstr)
    }
    
    JAMF ([string] $url, [pscredential] $creds) {
        $this.url = $url
        $this.Credential = $creds
    }

    <#
    .SYNOPSIS    
        Expects secure string of utf8 base64 of plaintext credentials in this format:
            user|pass
    
    .EXAMPLE
        $userpass = 'user|P@$$w0rd!'
        $bytes = [System.Text.Encoding]::Utf8.GetBytes($userpass)
        $env:JAMFCreds = [Convert]::ToBase64String($bytes)

        getCredString((ConvertTo-SecureString $env:JAMFCreds -AsPlainText -Force))
    #> 
    [pscredential] getCredString([securestring] $credstr) {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credstr)
        $base64 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($base64))
        $p = $decoded.Split('|')[1..$decoded.Split('|').Count] -join '|'
        $creds = New-Object System.Management.Automation.PSCredential($decoded.Split('|')[0], (ConvertTo-SecureString $p -AsPlainText -Force))        
        return $creds
    }

    <#
    .SYNOPSIS    
        Get Rest Method Hashtable

    .EXAMPLE
        $restMethod = $this.getRestMethod('uapi/preview/computers')
    #>
    [hashtable] getRestMethod([string] $uri) {
        return $this.getRestMethod(@{
            Uri = $uri
            Method = 'GET'
            Auth = 'token'
        })
    }

    <#
    .SYNOPSIS    
        Get Rest Method Hashtable

    .EXAMPLE
        $restMethod = $this.getRestMethod('uapi/v1/computers', 'POST')
    #>
    [hashtable] getRestMethod([string] $uri, [string] $method) {
        return $this.getRestMethod(@{
            Uri = $uri
            Method = $method
            Auth = 'token'
        })
    }

    <#
    .SYNOPSIS    
        Get Rest Method Hashtable

    .EXAMPLE
        $restMethod = $this.getRestMethod(@{
            Uri = 'uapi/auth/tokens'
            Method = 'POST'
            Auth = 'basic'
        })
    #>
    [hashtable] getRestMethod([hashtable] $params) {
        [hashtable] $restMethod = $params

        if ('Uri' -notin $restMethod.Keys) { Throw [Management.Automation.ItemNotFoundException] ('Required Key (Uri) missing: {0}' -f ($restMethod | Out-String)) }
        if ('Method' -notin $restMethod.Keys) { Throw [Management.Automation.ItemNotFoundException] ('Required Key (Method) missing: {0}' -f ($restMethod | Out-String)) }
        if ('Auth' -notin $restMethod.Keys) { Throw [Management.Automation.ItemNotFoundException] ('Required Key (Auth) missing: {0}' -f ($restMethod | Out-String)) }

        $restMethod.Set_Item('Uri', ('{0}{1}' -f $this.URL.AbsoluteUri, $restMethod.Uri))

        switch ($restMethod.Auth) {
            'basic' {
                $restMethod.Set_Item('Authentication', 'Basic')
                $restMethod.Set_Item('Credential', $this.Credential)
                break
            }
            'token' {
                if (-not $this.Token) {
                    $this.getToken()
                }
                $restMethod.Set_Item('Headers', @{
                    Authorization = 'Bearer {0}' -f $this.Token
                })
                break
            }
            default {
                Throw [Management.Automation.ItemNotFoundException] ('Unsupported authentication method: {0}' -f $restMethod.Auth)
            }
        }
        $restMethod.Remove('Auth')

        return $restMethod
    }

    [void] getToken() {
        $restMethod = $this.getRestMethod(@{
            Uri = 'uapi/auth/tokens'
            Method = 'POST'
            Auth = 'basic'
        })
        $call = Invoke-RestMethod @restMethod
        $this.Token = $call.token
    }

    [psobject] getComputers() {
        $restMethod = $this.getRestMethod('uapi/preview/computers')
        $call = Invoke-RestMethod @restMethod
        Write-Verbose ('[JAMF getComputers] Computers Count: {0}' -f $call.totalCount)
        return $call.results
    }
    
    [psobject] getManagedComputers() {
        $computers = $this.getComputers()
        $computers = $computers | Where-Object { $_.isManaged }
        Write-Verbose ('[JAMF getComputers] Managed Computers Count: {0}' -f $computers.Count)
        return $computers
    }

    [psobject] getComputer([int] $id) {
        $restMethod = $this.getRestMethod("uapi/v1/computers-inventory/${id}")
        $call = Invoke-RestMethod @restMethod
        return $call
    }
    
    [psobject] getComputerExtensionAttribute([int] $id, [string] $attribute) {
        return $this.getComputerExtensionAttributes($id, @($attribute))
    }

    [psobject] getComputerExtensionAttributes([int] $id) {
        return $this.getComputer($id).general.extensionAttributes
    }

    [psobject] getComputerExtensionAttributes([int] $id, [string[]] $attributes) {
        return ($this.getComputer($id).general.extensionAttributes | Where-Object { $_.name -in $attributes })
    }
}
