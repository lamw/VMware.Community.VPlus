# PowerShell Module for vSphere+ and vSAN+ Subscriptions

![](vmware-plus-icon.png)

## Summary

PowerShell Module to interact with subscription consumption for [vSphere+ and vSAN+ Cloud Service](https://williamlam.com/2022/07/a-first-look-at-the-new-vsphere-vsan-cloud-service.html). For more information on how to use this module, please refer to this [blog post](https://williamlam.com/2023/02/automating-subscription-and-usage-retrieval-for-vsphere-and-vsan-cloud-service.html).

## Prerequisites
* [PowerCLI 12](https://developer.vmware.com/web/tool/13.0.0/vmware-powercli) or newer

## Installation

```console
Install-Module VMware.Community.VPlus
```

## Functions

* Connect-VPlus
* Get-VPlusDeployment
* Get-VPlusSubscription