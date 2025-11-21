# Змінні для конфігурації ресурсів
$resourceGroupName = "mate-azure-task-9"
$location = "centralus" # Або інший регіон, який ви використовуєте
$vmSize = "Standard_B1s" # Вимоги завдання

# Облікові дані для VM
$Username = "azureuser"
$Password = "Yaroslava123" # ВСТАНОВЛЕНО ВАШ ПАРОЛЬ
$DnsLabel = "matebox-task9-server-1158875353" # ВСТАНОВЛЕНО ВАШУ УНІКАЛЬНУ МІТКУ DNS
$vmName = "matebox"
$sshKeyName = "linuxboxsshkey"

# Змінні для мережевих ресурсів (ВИПРАВЛЕНО ЗГІДНО З ВИМОГАМИ ЗАВДАННЯ)
$virtualNetworkName = "vnet"
$subnetName = "default"
$networkSecurityGroupName = "defaultnsg"
$publicIpAddressName = "linuxboxpip"
$vmImage = "Ubuntu2204" # Використання Friendly Name

# Облікові дані для підключення
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

# --- 1. СТВОРЕННЯ ГРУПИ РЕСУРСІВ ---
Write-Host "1. Creating Resource Group '$resourceGroupName'..."
$resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location

# --- 2. СТВОРЕННЯ SSH-КЛЮЧА ---
Write-Host "2. Creating SSH Key Resource '$sshKeyName'..."
# Перевіряємо, чи існує ключ, інакше створюємо
try {
    $sshKey = Get-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -ErrorAction Stop
    Write-Host "   SSH key already exists."
} catch {
    # Створюємо новий SSH Key Resource
    $sshKey = New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -Location $location
    Write-Host "   SSH key created successfully."
}
# Зберігаємо публічний ключ для подальшого використання (хоча $SshKeyName сам його прив'яже)
$sshKeyPublicKey = $sshKey.PublicKey

# --- 3. СТВОРЕННЯ МЕРЕЖЕВОЇ ІНФРАСТРУКТУРИ ---

# 3а. Створення віртуальної мережі (VNet)
Write-Host "3a. Creating Virtual Network '$virtualNetworkName'..."
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name $virtualNetworkName -AddressPrefix "10.0.0.0/16"

# 3b. Додавання підмережі
Write-Host "3b. Adding Subnet '$subnetName'..."
$subnet = Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.0.0/24" -VirtualNetwork $vnet

# 3c. Оновлення VNet з підмережею
$vnet = Set-AzVirtualNetwork -VirtualNetwork $vnet

# 3d. Створення Public IP Address
Write-Host "3d. Creating Public IP Address '$publicIpAddressName'..."
$pip = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -Name $publicIpAddressName -AllocationMethod Static -DomainNameLabel $DnsLabel

# 3e. Створення Network Security Group (NSG)
Write-Host "3e. Creating Network Security Group '$networkSecurityGroupName'..."
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name $networkSecurityGroupName

# 3f. Додавання правил NSG
Write-Host "3f. Adding NSG rules (SSH 22, HTTP 8080)..."
$nsg = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name "SSH" -Description "Allow SSH" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 22
$nsg = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name "HTTP_8080" -Description "Allow HTTP 8080" -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 8080
$nsg = Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg

# 3g. Створення мережевого інтерфейсу (NIC)
Write-Host "3g. Creating Network Interface..."
$nic = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "$vmName-nic" -Subnet $vnet.Subnets[0] -NetworkSecurityGroup $nsg -PublicIpAddress $pip

# --- 5. СТВОРЕННЯ ВІРТУАЛЬНОЇ МАШИНИ З ПРАВИЛЬНИМИ ПАРАМЕТРАМИ ---
Write-Host "5. Creating Virtual Machine '$vmName' of size '$vmSize' (This may take a few minutes)..."

$vm = New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -Location $location `
    -Image $vmImage `
    -Size $vmSize `
    -VnetName $virtualNetworkName `
    -SubnetName $subnetName `
    -PublicIpAddressName $publicIpAddressName `
    -SshKeyName $sshKeyName ` # Прив'язка існуючого ресурсу SSH Key
    -NetworkSecurityGroupName $networkSecurityGroupName `
    -DisablePasswordAuthentication `
    -Credential $cred

Write-Host "✅ VM Deployment Initiated. VM Name: $vmName"
Write-Host "   Public DNS Name: $($DnsLabel).$($location).cloudapp.azure.com"