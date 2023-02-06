Function Connect-VPlus {
    <#
        .NOTES
        ===========================================================================
        Created by:    William Lam
        Date:          02/06/2023
        Organization:  VMware
        Blog:          http://www.williamlam.com
        Twitter:       @lamw
        ===========================================================================
        .SYNOPSIS
            Acquire CSP Access Token to interact with vSphere+/vSAN+ Cloud Service
        .DESCRIPTION
            This cmdlet creates $global:vplusConnection object containing the vSphere+/vSAN+ URL along with CSP Token
        .EXAMPLE
            Connect-VPlus -RefreshToken $RefreshToken -OrgName $OrgName
    #>
    Param (
        [Parameter(Mandatory=$true)][String]$RefreshToken,
        [Parameter(Mandatory=$true)][String]$OrgId,
        [Parameter(Mandatory=$false)][String]$CSPServer="console.cloud.vmware.com",
        [Parameter(Mandatory=$false)][String]$VMCServer="vmc.vmware.com"
    )

    $requests = Invoke-WebRequest -Uri "https://${CSPServer}/csp/gateway/am/api/auth/api-tokens/authorize" -Method POST -ContentType "application/x-www-form-urlencoded" -Body "refresh_token=$REFRESH_TOKEN&grant_type=refresh_token"
    if($requests.StatusCode -ne 200) {
        Write-Host -ForegroundColor Red "Failed to retrieve Access Token, please ensure your VMC Refresh Token is valid and try again"
        break
    }
    $accessToken = ($requests | ConvertFrom-Json).access_token

    $headers = @{
        "csp-auth-token"="$accessToken"
        "Content-Type"="application/json"
        "Accept"="application/json"
    }

    $global:vplusConnection = new-object PSObject -Property @{
        'csp_server' = $CSPServer
        'vmc_server' = $VMCServer
        'org_id' = $OrgId
        'headers' = $headers
    }
    $global:vplusConnection
}

Function Get-VPlusDeployment {
    <#
        .NOTES
        ===========================================================================
        Created by:    William Lam
        Date:          02/05/2023
        Organization:  VMware
        Blog:          http://www.williamlam.com
        Twitter:       @lamw
        ===========================================================================
        .SYNOPSIS
            List all vSphere+/vSAN+ Deployments
        .DESCRIPTION
            List all vSphere+/vSAN+ Deployments
        .EXAMPLE
            Get-VPlusDeployment
                .EXAMPLE
            Get-VPlusDeployment -DeploymentName vc1.onprem.local
    #>
    Param (
        [Parameter(Mandatory=$False)][String]$DeploymentName,
        [Parameter(Mandatory=$False)][Boolean]$DemoMode=$false,
        [Switch]$Troubleshoot
    )

    If (-Not $global:vplusConnection) { Write-error "No vSphere+/vSAN+ Connection found, please use Connect-VPlus" } Else {
        $method = "GET"
        $deploymentsURL = "https://" + $global:vplusConnection.vmc_server + "/api/entitlement/v2/orgs/" + $global:vplusConnection.org_id + "/deployments?deployment_entitlement_type=SUBSCRIPTION&deployment_type=VSPHERE,VCF&with_eligibility=false&with_usages=true"

        if($Troubleshoot) {
            Write-Host -ForegroundColor cyan "`n[DEBUG] - $METHOD`n$deploymentsURL`n"
        }

        try {
            if($PSVersionTable.PSEdition -eq "Core") {
                $requests = Invoke-WebRequest -Uri $deploymentsURL -Method $method -Headers $global:vplusConnection.headers -SkipCertificateCheck
            } else {
                $requests = Invoke-WebRequest -Uri $deploymentsURL -Method $method -Headers $global:vplusConnection.headers
            }
        } catch {
            if($_.Exception.Response.StatusCode -eq "Unauthorized") {
                Write-Host -ForegroundColor Red "`nThe vSphere+/vSAN+ session is no longer valid, please re-run the Connect-VPlus cmdlet to retrieve a new token`n"
                break
            } else {
                Write-Error "Error in retrieving vSphere+/vSAN+ deployments"
                Write-Error "`n($_.Exception.Message)`n"
                break
            }
        }

        if($requests.StatusCode -eq 200) {
            $results = ($requests.Content | ConvertFrom-Json).Content

            if($results -eq $NULL) {
                break
            }

            if ($PSBoundParameters.ContainsKey("DeploymentName")){
                $results = $results | where {$_.deployment_name -eq $DeploymentName}
            }

            $deployments = @()
            foreach ($result in $results) {
                foreach ($usage in $result.subscription_usages) {
                    if($usage.product_id -eq "VSPHERE") {
                        $vsphere_usage = $usage.value
                    }

                    if($usage.product_id -eq "VSAN") {
                        $vsan_usage = $usage.value
                    }
                }

                $tmp = [pscustomobject] [ordered]@{
                    DeploymentId =$Demomode ? ([guid]::NewGuid()) : $result.deployment_id
                    DeploymentName = $DemoMode ? (-join ((48..57) + (97..122) | Get-Random -Count 10 | % {[char]$_})) : $result.deployment_name
                    Vsphere = $vsphere_usage
                    Vsan = $vsan_usage
                }
                $deployments+=$tmp
            }

            $deployments

            Write-Host "Total vSphere+ Core Usage: $(($deployments.vsphere | measure -Sum).Sum)"
            Write-Host "Total vSAN+ Core Usage: $(($deployments.vsan | measure -Sum).Sum)`n"
        }
    }
}

Function Get-VPlusSubscription {
    <#
        .NOTES
        ===========================================================================
        Created by:    William Lam
        Date:          02/06/2023
        Organization:  VMware
        Blog:          http://www.williamlam.com
        Twitter:       @lamw
        ===========================================================================
        .SYNOPSIS
            List all vSphere+/vSAN+ Subscriptions
        .DESCRIPTION
            List all vSphere+/vSAN+ Subscriptions
        .EXAMPLE
            Get-VPlusSubscription
        .EXAMPLE
            Get-VPlusSubscription -SubscriptionId AABBCCDD
    #>
    Param (
        [Parameter(Mandatory=$False)][String]$SubscriptionId,
        [Parameter(Mandatory=$False)][Boolean]$Summarize=$true,
        [Switch]$Troubleshoot
    )

    If (-Not $global:vplusConnection) { Write-error "No vSphere+/vSAN+ Connection found, please use Connect-VPlus" } Else {
        $method = "GET"
        $subscriptionsURL = "https://" + $global:vplusConnection.vmc_server + "/api/subscription/" + $global:vplusConnection.org_id  + "/core/subscriptions"

        if($Troubleshoot) {
            Write-Host -ForegroundColor cyan "`n[DEBUG] - $METHOD`n$subscriptionsURL`n"
        }

        try {
            if($PSVersionTable.PSEdition -eq "Core") {
                $requests = Invoke-WebRequest -Uri $subscriptionsURL -Method $method -Headers $global:vplusConnection.headers -SkipCertificateCheck
            } else {
                $requests = Invoke-WebRequest -Uri $subscriptionsURL -Method $method -Headers $global:vplusConnection.headers
            }
        } catch {
            if($_.Exception.Response.StatusCode -eq "Unauthorized") {
                Write-Host -ForegroundColor Red "`nThe vSphere+/vSAN+ session is no longer valid, please re-run the Connect-VPlus cmdlet to retrieve a new token`n"
                break
            } else {
                Write-Error "Error in retrieving vSphere+/vSAN+ subscriptions"
                Write-Error "`n($_.Exception.Message)`n"
                break
            }
        }

        if($requests.StatusCode -eq 200) {
            $results = ($requests.Content | ConvertFrom-Json).Content

            if($results -eq $NULL) {
                break
            }

            if ($PSBoundParameters.ContainsKey("SubscriptionId")){
                $results = $results | where {$_.display_id -eq $SubscriptionId}
            }

            if($Summarize -eq $false) {
                $results
            } else {
                $subscriptions = @()
                foreach ($result in $results) {
                    # Handle scenario where subscription contains multiple product/services
                    if($result.purchase_quantity -ne -1) {
                        $tmp = [pscustomobject] [ordered]@{
                            SubscriptionId = $result.display_id
                            Status = $result.Status
                            Quantity = $result.purchase_quantity
                            Units = $result.license_unit_display_name
                            Type = $result.product_display_name
                            Flexible = $result.flexible
                            Seller = $result.seller_of_record
                            BillingOption = $result.billing_frequency_display_name
                            Term = $result.billing_term_display_name
                            Location = $result.location.name | select -First 1
                            StartDate = $result.subscription_start_date_time
                            EndDate = $result.subscription_end_date_time
                        }
                        $subscriptions+=$tmp
                    } else {
                        foreach ($context in ($result.context|Get-Member -MemberType NoteProperty).Name) {
                            $count,$rest = $result.context.$context -split ' '

                            $tmp = [pscustomobject] [ordered]@{
                                SubscriptionId = $result.display_id
                                Status = $result.Status
                                Quantity = $count
                                Units = $result.license_unit_display_name
                                Type = $context
                                Flexible = $result.flexible
                                Seller = $result.seller_of_record
                                BillingOption = $result.billing_frequency_display_name
                                Term = $result.billing_term_display_name
                                Location = $result.location.name | select -First 1
                                StartDate = $result.subscription_start_date_time
                                EndDate = $result.subscription_end_date_time
                            }
                            $subscriptions+=$tmp
                        }
                    }
                }
                $subscriptions
            }
        }
    }
}