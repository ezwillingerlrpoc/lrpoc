resource "aws_vpc" "storage-cluster-vpc" {
    cidr_block = var.vpc_cidr
}
resource "aws_internet_gateway" "storage-cluster-inet-gw" {
    vpc_id = aws_vpc.storage-cluster-vpc.id
}
