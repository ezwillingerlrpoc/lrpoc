#LR POC

#.02 release. 

Ansible is working but Gluster isnt. Ansible run is manual, and there are some problems with how the ansible inventory is dynamically created by Terraform (there is a requirement for a manual file write for a file provisioner that I haven't figured out how to get past). See requirement note 3 and release note 3 for more details.


I forgot to mention the requirements in the .01 release that have already been merged to master. Here are the requirements for v0.02:

1. An SSH key pair, the paths for which are declared in vars.tf 
2. An appropriate IAM role with appropriately locked down permissions. For this POC, I used the AWS builtin SystemAdministrator role because it was expedient. A proper implementation would be restricted. That could be done by turning on CloudTrail and compiling a list of the calls made. The IAM role creation would still need to be done by hand unless one wanted to feed AWS root credentials into Terraform for bootstrapping, which is doable, but certainly increases the complexity of this POC.
3. An "ansible_inventory" file in the root folder. As of v0.02, I generate the ansible_inventory file dynamically using a template to push into the Ansible control node (called the "client" instance, because originally it was going to test the gluster volume but then its scope expanded). (See release note 3 below for more discussion of the ansible_inventory file). 

5. The client instance only allows SSH in from the public IP of the workstation running Terraform, which is done with an API call to a public internet service. This service could go dark at any moment, but since I am on a home connection with a dynamic IP, it was expedient. In a corporate infrastructure with well-defined network topologies, this could be a constant stored in a variable or probably even declared statically depending on how long the POC was expected to run for.

Notes for this release:

1. File provisioners seem tricky and aren't best practice. I should probably be using userdata. Or S3.
2. The security group is ridiculously open - wide open inside the VPC and wide open outbound. This is a terrible security practice. This should be fixed in production, the required Gluster services are well known, and beyond those and SSH there shouldn't be anything else. ICMP for diagnostics, I suppose, and maybe outbound gluster ports for remote consumption of the Gluster volume (where remote is possibly a different VPC or a hybrid on-prem architecture).
3. Because Terraform creates the ansible_inventory file dynamically using the output of terraform apply and subsequently destroys that file upon running terraform destroy, a manual file needs to be created after each destroy. That is simple enough to script in a wrapper with touch or New-Item, but it's a really hacky "solution" that is dissatisfying for obvious reasons. There has to be at least an incrementally better way to do it - probably involving creating the document in memory first (?)- but this feels like it could easily be a rabbit hole to get stuck in, so I am noting it and moving on.
3.1 I did note that there are several open feature requests to allow resources to persist beyond destruction. Seems kind of backwards and that it would reinforce my hacky workflow, but it would also solve this problem.
4. As mentioned below, there are no firewalls on the instances at the OS level, just security groups. This is not a good defense-in-depth strategy. Security groups are pretty solid, but there's no reason to not take proper precautions (in anything approximating a QA or production environment) and have appropriate network restrictions at both the EC2 and OS levels. One might be able to argue that network ACLs are interesting as well, but since they're stateless I think there are more opportunities for silly mistakes.
5. I have been manually running build.yaml on the instance and it fails to install gluster. Upon investigating, the service wont start and in fact doesn't exist. Nmap shows that the only port open is 22. I can't find firewalld, iptables, or nftables on the system. Installing iptables and opening everything wide open doesn't do it. But if there's nothing listening on any port, it wont respond. So not a port thing. It's more that the glusterd service doesn't get installed/wont start, not that it starts and then chokes on not being able to communicate with peers.

   - There was supposedly something about installing on redhat/centos on older versions, but its in yum and redhat bought gluster in 2011 so it seems unlikely to be a distro thing.
   - Also Gluster says "Get the package from the CentOS Storage SIG" and the CentOS Storage SIG says "It's super easy! The repo is enabled by default! Just use yum!" (reference https://wiki.centos.org/SpecialInterestGroup/Storage and https://wiki.centos.org/AdditionalResources/Repositories)
   - However, all the documentation (which admittedly is a full point release old) says I should be installing glusterfs-server and not glusterfs, even though glusterfs-server doesn't exist in the repo as far as I can tell, nor does the supposed CentOS version centos-release-gluster
   - What am I missing?
   - the only thing in /var/log/glusterfs is cli.log. the daemon doesnt exist.
   - Definititely mounting the volume. I can touch files in the brick path. It's never making the bricks.
   - the daemon doesn't exist.
   - I'm not installing the glusterfs-server package
   - try a different distro?


--------------------

#.01 release. 

Working terraform module for AWS infrastructure with validated file copy to the inside of the machine. Still need security groups on the cluster instances to control gluster communication. This should be sufficient to move onto Ansible setup. 

Still plenty of things to make better:
1. Make sure all element() calls are removed, as deprecated in .12 but left in for .11 compatibility
2. Import and delete default vpc? 
3. VPC endpoint for S3/glacier backup?
4. Implies some kind of file system watcher that checks for last modified date and then moves it
5. script wrapper around terraform apply that will take MFA tokens as input and generate proper AWS cred file for MFA-supported terraform 
6. figure out how to link the cluster instances so that any change to an instance makes all get reinstantiated 
   - like this copypaste?:
     ```
     # Changes to any instance of the cluster requires re-provisioning
     triggers {
     cluster_instance_ids = "${join(",", aws_instance.cluster.*.id)}"`
     }
     ```                           
7. output some alert about restricting SSH access to only the public IP
8. write doc about requirements like keypair and credential file etc.
9. can I do something better (= cross platform default) about the paths?