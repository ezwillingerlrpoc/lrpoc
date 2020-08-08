$confirm = $null
$confirm = Read-Host -prompt @"
Please confirm the following:
1. You have public and private SSH keys (of an acceptable format for AWS EC2 instances) in the paths defined in vars.tf
2. An IAM user defined with AWS builtin role SystemAdministrator permissions and a corresponding credential file / named profile as defined in vars.tf
3. You have access to the public internet over TCP/22 from your public IP $((Invoke-WebRequest http://api.ipify.org).content)
Type 'yes' to continue, anything else to abort
"@
 if ($confirm -ne "yes") {
     continue
}
 else {
    $ignore = New-Item -Path .\builddnf.yaml -Force -ItemType File
    $ignore = New-Item -Path .\ansible_inventory -Force -ItemType File
    terraform init -input=false 
    terraform plan -out=tfplan -input=false
    terraform apply -input=false tfplan
 }

 #TODO: Read MFA token(s) and generate credential file