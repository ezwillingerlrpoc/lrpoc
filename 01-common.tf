#AWS auth and region
provider "aws" {
  profile = var.profile
  shared_credentials_file = var.cred_file
  region  = var.aws_region
  version = "~> 3.0"
}
provider "http" {
    version = "~> 1.2"
}

#SSH Key
resource "aws_key_pair" "rsa_ssh_key" {
  key_name   = "ssh_pub_key"
  public_key = file("${var.ssh_pub_key}")
}

#Why is this here?
#region AZs
data "aws_availability_zones" "main" {}

#FIXME
#AMI ID
data "aws_ami" "rhel_ami" {
    most_recent = true
    owners      = ["${var.rhel_ami_owner}"]
    filter {
        name = "root-device-type"
        values = ["ebs"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
    filter {
        name = "name"
        values = ["RHEL-8.2.0_HVM-*-x86_64*"]
    }
}
