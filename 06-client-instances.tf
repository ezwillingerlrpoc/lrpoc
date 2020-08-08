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
    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [aws_vpc.storage-cluster-vpc.cidr_block]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

}


resource "local_file" "ansible_inventory" {
    content = templatefile("ansible_inventory.tmpl",
        {
            private-ips = flatten(aws_network_interface.storage-cluster-glusterd-net-if.*.private_ips)
        }
    )  
    filename = "${path.module}\\ansible_inventory"
}
resource "local_file" "ansible_playbook" {
    content = templatefile("builddnf.tmpl",
        {
            private-ips = flatten(aws_network_interface.storage-cluster-glusterd-net-if.*.private_ips)
        }
    )  
    filename = "${path.module}\\builddnf.yaml"
}

/*
output "hosts" {
    value = local_file.ansible_playbook
}
*/

resource "aws_instance" "storage-cluster-client-instance" {
    ami = data.aws_ami.rhel_ami.id
    instance_type = var.instance_type
    key_name = aws_key_pair.rsa_ssh_key.key_name
    user_data = file("userdata_client.txt")
    depends_on = [local_file.ansible_inventory]
    network_interface {
        network_interface_id = aws_network_interface.storage-cluster-client-net-if.id
        device_index = 0
    }
    
    provisioner "file" {
        source = var.ssh_priv_key
        destination = "~/.ssh/id_rsa"
        connection {
            host = aws_eip.storage-cluster-net-eip.public_ip
            type = "ssh"
            user = "fedora"
            private_key = file(var.ssh_priv_key)
        }
    }
    provisioner "remote-exec" {
        inline = [
            "chmod 600 ~/.ssh/id_rsa",
            "mkdir ~/ansible_files/"
        ]
        connection {
            host = aws_eip.storage-cluster-net-eip.public_ip
            type        = "ssh"
            user        = "fedora"
            private_key = file(var.ssh_priv_key)
        }
    }
    
    #this one really didnt want to work
    #and to hack it to work i have to write an ansible_inventory file manually
    #but terraform destroy removes that file so I have to recreate it each destroy
    #yeah provisioners really aren't ideal
    #use S3 after figuring out the manual file thing
    provisioner "file" {
        #why do I need to wrap this in file()?
        content = file("${path.module}\\ansible_inventory")
        destination = "~/ansible_files/hosts"
        connection {
            host = aws_eip.storage-cluster-net-eip.public_ip
            type = "ssh"
            user = "fedora"
            private_key = file(var.ssh_priv_key)
        }
    }
    provisioner "file" {
        #why do I need to wrap this in file()?
        content = file("${path.module}\\ansible_inventory")
        destination = "~/ansible_files/hosts"
        connection {
            host = aws_eip.storage-cluster-net-eip.public_ip
            type = "ssh"
            user = "fedora"
            private_key = file(var.ssh_priv_key)
        }
    }
    provisioner "file" {
        #why do I need to wrap this in file()?
        content = file("${path.module}\\builddnf.yaml")
        destination = "~/ansible_files/builddnf.yaml"
        connection {
            host = aws_eip.storage-cluster-net-eip.public_ip
            type = "ssh"
            user = "fedora"
            private_key = file(var.ssh_priv_key)
        }
    }
    provisioner "remote-exec" {
        inline = [
            "sleep 2m",
            "ansible-playbook -i ~/ansible_files/hosts -u fedora ~/ansible_files/builddnf.yaml -e 'ansible_python_interpreter=/usr/bin/python3' --ssh-common-args='-o StrictHostKeyChecking=no'"
        ]
        connection {
            host = aws_eip.storage-cluster-net-eip.public_ip
            type        = "ssh"
            user        = "fedora"
            private_key = file(var.ssh_priv_key)
        }
    }
}/*
    
   */ 
    #do I need to put the private key on the inside for ansible?
    #need the host IPs/names for ansible later
    #also setup scripts or whatever that dont go in userdata