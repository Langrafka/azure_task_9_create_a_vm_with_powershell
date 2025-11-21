# --------------------------------------------------------------------------------------
# 1. КОНФІГУРАЦІЯ ЗМІННИХ
# --------------------------------------------------------------------------------------
$location = "centralus" # Надійний регіон
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"

# Читання SSH ключа: додано -Raw для коректного формату
$sshKeyPublicKey = Get-Content "$HOME\.ssh\id_rsa.pub" -Raw
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s" # ПОВЕРНЕНО ДО ВИМОГИ ЗАВДАННЯ!

# Додаткові змінні
$DnsLabel = "matebox-task9-server-$(Get-Random)"
$Username = "azureuser" # Ім'я користувача для SSH
$NicName = "matebox-nic"
$Password = "MateAcademy-2025!" # Тимчасовий пароль для об'єкта Credential

# --------------------------------------------------------------------------------------
# 2. СТВОРЕННЯ ГРУПИ РЕСУРСІВ
# --------------------------------------------------------------------------------------
Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force | Out-Null

# --------------------------------------------------------------------------------------
# 3. СТВОРЕННЯ МЕРЕЖЕВОГО КОНТЕКСТУ ТА NSG
# --------------------------------------------------------------------------------------
Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# 1. Створення Virtual Network та Subnet
Write-Host "1. Creating Virtual Network '$virtualNetworkName' and Subnet '$subnetName'..."
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name $virtualNetworkName -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig

# 2. Створення Public IP Address з DNS-лейблом
Write-Host "2. Creating Public IP Address '$publicIpAddressName' with DNS label '$DnsLabel'..."
$pip = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -Name $publicIpAddressName -AllocationMethod Static -DomainNameLabel $DnsLabel

# 3. Створення SSH Key Resource
Write-Host "3. Creating SSH Key Resource '$sshKeyName'..."
$sshKey = New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey

# 4. СТВОРЕННЯ МЕРЕЖЕВОГО ІНТЕРФЕЙСУ (NIC)
Write-Host "4. Creating Network Interface Card (NIC) '$NicName'..."
$currentVnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkName
$currentPip = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpAddressName
$subnet = $currentVnet.Subnets | Where-Object {$_.Name -eq $subnetName}

$nic = New-AzNetworkInterface `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $NicName `
    -SubnetId $subnet.Id `
    -PublicIpAddressId $currentPip.Id `
    -NetworkSecurityGroupId $nsg.Id

# 5. СТВОРЕННЯ ВІРТУАЛЬНОЇ МАШИНИ
Write-Host "5. Creating Virtual Machine '$vmName' of size '$vmSize' (This may take a few minutes)..."

# Тимчасовий об'єкт Credential
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

# 5а. Створення конфігураційного об'єкта VM
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize

# 5b. Встановлення профілю безпеки як Standard (Це має спрацювати, оскільки функція зареєстрована!)
$vmConfig = Set-AzVMSecurityProfile -VM $vmConfig -SecurityType Standard

# 5c. Встановлення операційної системи та облікових даних через Credential
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $vmName -Credential $cred -DisablePasswordAuthentication

# 5d. Додавання образу та мережевого інтерфейсу
$vmConfig = Set-AzVMSourceImage -VM $vmConfig -Publisher 'Canonical' -Offer '0001-com-ubuntu-server-jammy' -Skus '22_04-lts' -Version 'latest'
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

# 5e. Прив'язка SSH ключа
$vmConfig = Add-AzVMSshPublicKey -VM $vmConfig -Path "/home/$Username/.ssh/authorized_keys" -KeyData $sshKeyPublicKey

# 5f. Створення VM
$vm = New-AzVm -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig

Write-Host "✅ VM Deployment Initiated. VM Name: $vmName"
Write-Host "   Public DNS Name: $($DnsLabel).$($location).cloudapp.azure.com"