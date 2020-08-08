#look at me
resource "aws_subnet" "storage-cluster-glusterd-subnet" {
    count = length(data.aws_availability_zones.main.names)
    vpc_id = aws_vpc.storage-cluster-vpc.id
    cidr_block = cidrsubnet("${var.priv_sub_cidr}", 2, count.index)
    availability_zone = element(data.aws_availability_zones.main.names, count.index)
}

locals {
    subnet_ids = aws_subnet.storage-cluster-glusterd-subnet.*.id
    nb_subnets = length(data.aws_availability_zones.main.names)
}

resource "aws_eip" "storage-cluster-nat-gw-eip" {
    vpc = true
    depends_on = [aws_internet_gateway.storage-cluster-inet-gw]
}

resource "aws_nat_gateway" "storage-cluster-nat-gw" {
    allocation_id = aws_eip.storage-cluster-nat-gw-eip.id
    subnet_id = aws_subnet.storage-cluster-client-subnet.id
    depends_on = [aws_internet_gateway.storage-cluster-inet-gw, aws_eip.storage-cluster-nat-gw-eip]
}

resource "aws_route_table" "storage-cluster-glusterd-subnet-route-table" {
    vpc_id = aws_vpc.storage-cluster-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.storage-cluster-nat-gw.id
    }
    depends_on = [aws_nat_gateway.storage-cluster-nat-gw]
}

resource "aws_route_table_association" "storage-cluster-subnet-route-table-assoc" {
    count = local.nb_subnets
    subnet_id = element(local.subnet_ids, count.index)
    route_table_id = aws_route_table.storage-cluster-glusterd-subnet-route-table.id
}