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
}

$adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
$group = $adsi.Children | Where-Object { $_.SchemaClassName -eq 'group' -and $_.Name -eq $name }

try {
    If ($state -eq "present") {
        If (-not $group) {
            If (-not $check_mode) {
                $group = $adsi.Create("Group", $name)
                $group.SetInfo()
            }

            $result.changed = $true
        }

        if($null -ne $description){
            if($null -ne $group){
                if($group.Description -ne $description){
                    If (-not $check_mode) {
                        $group.description = $description
                        $group.SetInfo()
                    }
                }
                $result.changed = $true
            }
        }else{
            If (-not $check_mode){
                $group = $adsi.Create("Group", $name, $description)
                $group.SetInfo()
            }
            $result.changed = $true
        }
    }
    ElseIf ($state -eq "absent" -and $group) {
        If (-not $check_mode) {
            $adsi.delete("Group", $group.Name.Value)
        }
        $result.changed = $true
    }
    ElseIf($state -eq "query"){
        If (-not $check_mode){
            $result.results = @()
            ForEach ($groups In $group){
                #$result.results += New-Object -TypeName psobject -Property @{"group"= $group.Name}
                $Members = @($group.psbase.Invoke("Members"))
                ForEach ($Member In $Members){
                    $Class = $Member.GetType().InvokeMember("Class", 'GetProperty', $Null, $Member, $Null)
                    $NameMember = $Member.GetType().InvokeMember("Name", 'GetProperty', $Null, $Member, $Null)
                    #$result.results += New-Object -TypeName psobject -Property @{"username"= $NameMember; "class"= $Class}
                    #$result.results += @{"username"= $NameMember; "class"= $Class}
                    $result.results += @{"username"= $NameMember; "class"= $Class}
                }
            }
        }
    }
}
catch {
    Fail-Json $result $_.Exception.Message
}

Exit-Json $result
