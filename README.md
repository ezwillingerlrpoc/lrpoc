#LR POC

# 0.1 release

This release fulfills the requirements of the POC, namely:
- **The cluster must successfully deploy from scratch by running a single command or script**
  - The POC is instantiated with ***LrPocRunMe.ps1*** and asks for you to confirm that you meet the requirements for successful instantiation. I trust that you can either run Powershell or open up the file and clearly see what I am doing. It's trivial.
- **A single networked GlusterFS filesystem should be created and mounted on all nodes in the cluster**
  - This is accomplished with the Ansible playbook builddnf.yaml.
- **Destruction of a single node in the cluster should not result in any data loss on the GlusterFS filesystem**
  - I didn't automate this, although automated testing could be accomplished with another playbook. My testing regime was as follows:
    ```
     From each host: sudo mount -t glusterfs localhost:/test /testmount
     From host1: sudo touch file01.txt
     From host2: ls /testmount
     file01.txt is there
     From EC2 console: shutdown host1
     From host2: ls /testmount
     File01.txt is there
     From host2: sudo touch file02.whileotherhostwasdown.txt
     From EC2 console: start host1
     From host1: ls /testmount
     file02.whileotherhostwasdown.txt is there
    ```
Furthermore, it displays most or all of the characteristics you will be looking for, namely:
- **Required functionality as outlined above**
  - Met as described above.
- **Proficiency with modern tools slated for this approach**
  - It is up to you to evaluate proficiency.
- **Idempotency**
  - I have applied the Terraform and Ansible templates on top of themselves many times.
- **Overall best practices for the tools, languages, and/or approaches you use**
  - For the purposes of the POC, I have cut several corners. Where appropriate, I have included comments in code or in the README.md file indicating as such. I will also be writing a great deal more about best practices down below.
- **We prefer your solution utilize Ansible and an Infrastructure-as-Code technology (e.g. Vagrant or Terraform)**
  - As mentioned earlier, I have used Ansible and Terraform with a Powershell wrapper.
- **Updates to this README.md file describing your solution along with any known issues**
  - I have updated this README.md file along the way.

# Best Practices

There are some best practices that are more or less universal, such as least privilege and security in depth. There are some best practices that are arbitrary and/or minimal in scope, like organization-specific programming patterns. The more interesting and difficult best practices to implement are the ones that occupy the middle of that spectrum, and I would like to discuss where my POC falls short of an ideal and what would need to be done in order to close that gap. But before I do that, it would also be helpful to determine what the use case will be for the production-ready implemention of this system to determine what best practices we should adhere to. 

- It's possible that this is designed as an small on-prem (production) scratch volume for ingesting sysvol logs from a variety of collectors before it is ETLed and ultimately stored in a database of some sort on a different storage solution. If so, there might be no requirement for distributed read capacity, very little requirement for long term (e.g > 1 hour) data storage, and the primary requirement would be small file throughput with plenty of buffering. Given its on-prem nature, we might be constrained by client storage performance (if the product is an appliance rather than a hardware node) and would have to make tradeoffs for performance tuning. If, however, it was a similar use case where there were multiple scratch volumes for multiple collectors across a multi-cloud enterprise, distributed read/write access would likely be more desirable. 

- It's also possible that this is designed to house working data on-prem for HPC clusters in a development environment, in which case I would propose cost-effective blazingly fast distributed replication, tiered storage, carefully selected hardware backend and interconnects, etc. (reference https://events.static.linuxfound.org/sites/events/files/slides/Storage-Extremes-Lessons-Linux-Foundation-Vault-03-2017.pdf which ends at MarFS but asserts that Gluster is probably the closest solution to MarFS). All of this would require extremely deep dives into file system- and network- level performance tuning, and would be orders of magnitude more expensive than simply standing up a two node replication on t2.micro instances, as I have done.

So given that there are many unanswered questions as to the use case of this POC, I instead chose to focus on functionality ("does it meet the stated requirements?", or in other words, "Is this an MVP?") with the goal of talking about best practices at a systems level, which I have done above, rather than picking in a vacuum *which* best practices I would adhere to That leaves us to discuss a gap analysis of known shortcomings with my MVP and what I would do make it a more maximum viable product.


**AWS Infrastructure**

As mentioned in the README.md there's a lot of work I know needs to be done here that I handwaved away in favor of an MVP. AWS has done a great deal of work to publish best practices (e.g. the well architected framework) and released many tools to help implementing them (Inspector). While many of these practices aren't exactly mandatory in development sandboxes, my experience is that dev environments tend to exhibit at least some configuration drift, and the closer pre-production environments can adhere to the final standards, the fewer bugs there will be to chase down in the QA environments.
- EC2 security groups need to be locked down to only known required ports (e.g. TCP/80 and/or 443 outbound, TCP/22 inside the VPC and also between EC2 instances and Terraform deployment infrastructure, and the Gluster ports TCP/ and UDP/24007-24008 and 49152-[49152+n] (for n bricks) for both node to node and also node to client communication.
  - Using prebuilt AMIs with all the necessary packages already installed may remove the requirement for HTTP/S access to repositories for package installation.
- The servers should have software firewalls configured to restrict access to the same ports.
- The terraform IAM user should be restricted to only the permissions necessary to instantiate the POC, and perhaps MFA should be required (this is to a large degree an organizational consideration rather than a technical one).
- Various AWS logging and security systems should be turned on, including Cloudtrail, VPC flow logs, GuardDuty, and Inspector, among others, but CloudTrail is the most important one here.
- Depending on the use case, S3 could be used as a backup mirror with optional Glacier integration for long term archiving.
- S3 (or SNS/step function/lambda workflows) could be used to signal particular stages in the build process as a way of working around dependency triggers.
- S3 is an excellent medium for transmitting build files to the inside of an instance if they can't be included in the AMI. This may negate the need for file provisioners in Terraform.
- It may be desirable to encrypt EBS volumes. For instance, a double layer of encryption (on top of SQL encryption at rest) is an easy win to communicate to auditors if you are plausibly storing NPI.
- Support agreements are an excellent thing in enterprise environments. RHEL would likely be a better choice than Fedora.

**Terraform Design**
- I use several provisioners for the Ansible control node instance. Documentation suggests using provisioners as a last resort. In a non-MVP situation, I would ideally use S3 for the file provisioners and userdata or a pre-existing configuration management solution for the remote-exec provisioners.
- As mentioned in the v0.02 release, the combination of local_file resource and templatefile() function didn't work as smoothly as I had hoped, and I had to band-aid them by manually (in the wrapper script) creating the missing files in the event that terraform destroy was run. I know there must be a better solution.
- The EIP association for the Ansible control node makes an assumption that the EIP only has one private IP address assigned(line 12 in 06-client-instances.tf) It's arguably possible that a more elegant solution would be required in more complicated deployments.
- The 7 separate files is a little unwieldy. I'm not aware of a documented best practice, but it seems unnecessarily verbose.
- My resource and file naming convention is a little crazy. It could use some rework, but as an MVP it's uninteresting. If I was presenting a lunch and learn where I was walking through the workflow, I would want it cleaned up. Similarly, some of the comments that I wrote to myself along the way can be removed.

**Ansible design**
- One notable shortcoming in the playbook is that I don't perform an update or upgrade \* to bring all packages in the AMI up to date. I did this to iterate quicker without having to wait for approximately 100 packages to be downloaded and updated. If a golden AMI was used, this wouldn't be relevant. Since I am using a community AMI, this is definitely not ideal.
- I use --ssh-common-args='-o StrictHostKeyChecking=no' passed to Ansible rather than modifying known_hosts on the control node. Stack has a solution available that I would need to test before implementing (https://stackoverflow.com/a/39083724), but its well ranked and appears superficially reasonable.

**Gluster design**
- To a large degree, many of the best practices impacted by use case are relevant here. The Gluster Administration Guide (https://docs.gluster.org/en/latest/Administrator Guide/) offers a variety of details as to configuration and use, as does the Red Hat Administration Guide (https://access.redhat.com/documentation/en-us/red_hat_gluster_storage/3.5/html/administration_guide/index)
- I didn't conform to the suggested brick naming conventions, which suggests /data/glusterfs/\<volume>/<brick>/brick
- I only created a 2 node system as an MVP, which is susceptible to split brain under certain conditions. Either an arbiter volume or a replica 3 volume would control for that risk (with different tradeoffs).
- Testing the replication from the Gluster nodes is not a great practice, since I can't imagine any use case at all where the only consumers of gluster are the Gluster nodes themselves. In an ideal POC I would have instantiated a client node that mounted the volumes on startup and then used it as part of a larger and automated testing suite.
- Enabling TLS would be a good idea, depending on the sensitivity of the information stored on the cluster
- The Linux OS can also be tuned for performance (e.g. https://docs.gluster.org/en/latest/Administrator Guide/Linux Kernel Tuning/) in addition to the Gluster nodes (e.g. https://access.redhat.com/documentation/en-us/red_hat_gluster_storage/3/html/administration_guide/small_file_performance_enhancements)
- It's worth mentioning that the Gluster Install Guide indicates (https://docs.gluster.org/en/latest/Install-Guide/Setup_aws/) that if a node reboots, there is some work to be done to get it back to a healthy state. My superficial testing found no evidence of this, and in a different page of the documentation, there was evidence that the documentation was a point version behind. More testing will need to be done to prove the resiliency of this AWS implementation.



# .02 release. 

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

# .01 release. 

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
