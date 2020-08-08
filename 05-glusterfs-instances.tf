resource "aws_network_interface" "storage-cluster-glusterd-net-if" {
    count = local.nb_subnets
    subnet_id = element(local.subnet_ids, count.index)
    description = "Gluster ${count.index} - network interface"
}
/*
data "template_file" "storage-cluster-glusterd-cloudconfig" {
    #use templatefile instead
    #not sure if I need anything in here
}

data "template_cloudinit_config" "storage-cluster-glusterd-config" {
    #not sure what to do here
    #use this object .rendered to use template_file to pass back IPs and whatever
}
*/
resource "aws_instance" "storage-cluster-glusterd-instance" {
    count = local.nb_subnets
    ami = data.aws_ami.rhel_ami.id
    instance_type = var.instance_type
    key_name = aws_key_pair.rsa_ssh_key.key_name
    user_data = file("userdata.txt")
    network_interface {
        network_interface_id = element(aws_network_interface.storage-cluster-glusterd-net-if.*.id, count.index)
        device_index = 0
    }
    ebs_block_device {
        device_name = "${var.glusterd_ebs_device_name_prefix}f"
        delete_on_termination = true
        volume_size = var.glusterd_ebs_volume_size
        volume_type = "gp2"
    }
    ebs_block_device {
        device_name = "${var.glusterd_ebs_device_name_prefix}g"
        delete_on_termination = true
        volume_size = var.glusterd_ebs_volume_size
        volume_type = "gp2"
    }
}
output "ip" {
    value = aws_instance.storage-cluster-glusterd-instance.*.private_ip
}
#need security groups


