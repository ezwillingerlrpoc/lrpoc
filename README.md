# lrpoc
LR POC

.01 release. Working terraform module for AWS infrastructure with validated file copy to the inside of the machine. Still need security groups on the cluster instances to control gluster communication. This should be sufficient to move onto Ansible setup. 

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
