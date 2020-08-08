#needs a public IP for validating solution

resource "aws_network_interface" "storage-cluster-client-net-if" {
    subnet_id = aws_subnet.storage-cluster-client-subnet.id
    security_groups = [aws_security_group.allow_ssh.id]
}

resource "aws_eip_association" "storage-cluster-client-net-eip-association" {
    allocation_id = aws_eip.storage-cluster-net-eip.id
    network_interface_id = aws_network_interface.storage-cluster-client-net-if.id
    #this is hacky but it works because I'm only assigning one IP
    private_ip_address = sort(aws_network_interface.storage-cluster-client-net-if.private_ips)[0]

}

data "http" "public_ip" {
    url = "http://api.ipify.org"
}

resource "aws_security_group" "allow_ssh" {
    name = "allow_ssh"
    description = "allow ssh in from anywhere"
    vpc_id = aws_vpc.storage-cluster-vpc.id
   
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        #cidr_blocks = ["0.0.0.0/0"]
        cidr_blocks = ["${data.http.public_ip.body}/32"]
    }
}
resource "aws_instance" "storage-cluster-client-instance" {
    ami = data.aws_ami.rhel_ami.id
    instance_type = var.instance_type
    key_name = aws_key_pair.rsa_ssh_key.key_name
    user_data = file("userdata.txt")
    network_interface {
        network_interface_id = aws_network_interface.storage-cluster-client-net-if.id
        device_index = 0
    }
    #vpc_security_group_ids = 
    provisioner "file" {
        source = var.ssh_priv_key
        destination = "~/.ssh/id_rsa"
        connection {
            host = aws_eip.storage-cluster-net-eip.public_ip
            type = "ssh"
            user = "ec2-user"
            private_key = file(var.ssh_priv_key)
        }
    }
    provisioner "file" {
        source = var.foobar
        destination = "~/foobar.txt"
        connection {
            host = aws_eip.storage-cluster-net-eip.public_ip
            type = "ssh"
            user = "ec2-user"
            private_key = file(var.ssh_priv_key)
        }
    }
}

    
    #do I need to put the private key on the inside for ansible?
    #need the host IPs/names for ansible later
    #also setup scripts or whatever that dont go in userdata