#!powershell

# Copyright: (c) 2014, Chris Hoffman <choffman@chathamfinancial.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$params = Parse-Args $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false

$name = Get-AnsibleParam -obj $params -name "name" -type "str" -failifempty $true
$state = Get-AnsibleParam -obj $params -name "state" -type "str" -default "present" -validateset "present", "absent", "query"
$description = Get-AnsibleParam -obj $params -name "description" -type "str"

$result = @{
    changed = $false
    results= ""
}

$adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
$group = $adsi.Children | Where-Object { $_.SchemaClassName -eq 'group' -and $_.Name -eq $name }

try {
    if($state -eq "present"){
        if($null -ne $description){
            if($null -ne $group){
                if($group.Description -ne $description){
                    If (-not $check_mode){
                        Set-LocalGroup -Name $name -Description $description
                    }
                    $result.changed = $true
                }
            }else{
                If (-not $check_mode){
                    New-LocalGroup -Name $name -Description $description
                }
                $result.changed = $true
            }
        }elseif($null -eq $group){
            If (-not $check_mode){
                New-LocalGroup -Name $name
            }
            $result.changed = $true
        }          
    }
    elseif($state -eq "absent" -and $group){
        If (-not $check_mode){
            Remove-LocalGroup -Name $name
        }
        $result.changed = $true
    }
    elseif($state -eq "query"){
        If (-not $check_mode){
            $LocalMember = Get-LocalGroupMember -Name $name
            $result.results = @()
            foreach($LocalMembers in $LocalMember){
                $result.results += New-Object -TypeName psobject -Property @{name= $LocalMembers.Name; objectclass = $LocalMembers.ObjectClass; sid = $LocalMembers.SID.Value}
            }
        }
        $result.changed = $true
        $result.results
    }
}
catch {
    Fail-Json $result $_.Exception.Message
}

Exit-Json $result
