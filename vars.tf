######
#Access vars#
#######
variable "profile" {
    default     = "default"
}
variable "cred_file" {
    default     = "c:\\Users\\Eli\\.aws\\credentials" 
}
/*#FIXME WITH LOCAL CREDS
variable "AccessKey" {
    type        = string
    description = "AWS Access Key"
}
variable "SecretKey"{
    type        = string
    description = "AWS Secret Key"

}
*/
variable "ssh_pub_key" {
    default     = "C:\\Users\\Eli\\Documents\\LRPOC\\MyKeyPair.pub"
    description = "Local public key"
}
variable "ssh_priv_key" {
    default     = "C:\\Users\\Eli\\Documents\\LRPOC\\MyKeyPair.pem"
    description = "Local private key"
}

#######
#AWS Vars#
#######



variable "aws_region" {
    type        = string
    default     = "us-west-1"
}
variable "rhel_ami_owner" {
    description = "Owner ID of AMI"
    default = "125523088429"
}

#micro is fine for a POC
variable "instance_type" {
    type = string
    default = "t2.micro"
}

variable "vpc_cidr" {
    default = "10.111.0.0/16"
}
variable "pub_sub_cidr" {
    description = "CIDR for public subnet"
    default = "10.111.1.0/24"
}
variable "priv_sub_cidr" {
    description = "CIDR for Gluster subnet"
    default = "10.111.11.0/24"
}


#####
#Instance vars
####

variable "glusterd_ebs_device_name_prefix" {
    default = "/dev/xvd"
}

# This is in Gb, small is fine for a POC
variable "glusterd_ebs_volume_size" {
    default = "11"
}

variable "foobar" {
    default     = "C:\\Users\\Eli\\Documents\\LRPOC\\userdata.txt"
    description = "Empty file for testing"

}
