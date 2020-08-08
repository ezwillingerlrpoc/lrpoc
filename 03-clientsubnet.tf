resource "aws_subnet" "storage-cluster-client-subnet" {
    vpc_id = aws_vpc.storage-cluster-vpc.id
    cidr_block = var.pub_sub_cidr
}

resource "aws_eip" "storage-cluster-net-eip" {
    vpc = true
    depends_on = [aws_internet_gateway.storage-cluster-inet-gw]
}

resource "aws_route_table" "storage-cluster-client-subnet-route-table" {
    vpc_id = aws_vpc.storage-cluster-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.storage-cluster-inet-gw.id
    }
}
#route tables need associations
#also depends on the route table?
resource "aws_route_table_association" "storage-cluster-client-subnet-route-table-assoc" {
    subnet_id = aws_subnet.storage-cluster-client-subnet.id
    route_table_id = aws_route_table.storage-cluster-client-subnet-route-table.id
    depends_on = [aws_subnet.storage-cluster-client-subnet]
}
