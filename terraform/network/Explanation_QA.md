#**Terraform Network Module — Explanation & Q&A :**

##**1.Why are DNS support and DNS hostnames enabled?**

These settings allow AWS to provide DNS resolution inside the VPC.Without them, instances can still communicate using IPs, but many AWS services rely on DNS internally. 
Enabling them does not cost anything and avoids subtle issues later.

Even if you do not use DNS directly today, services like load balancers and managed AWS services depend on it.

##**2.Why do we use a list of availability zones?**

Instead of creating subnets manually for each availability zone, we give Terraform a list of AZs. Terraform then creates one subnet per AZ automatically. This avoids duplication and keeps the code easy to modify.

If we ever add or remove an AZ, we only change the list, not the Terraform logic.


##**3.How does Terraform assign the correct AZ and CIDR?**

Terraform uses the same index to pick values from multiple lists. On the first iteration, it picks the first AZ and the first CIDR. On the second iteration, it picks the second AZ and the second CIDR.
This ensures that each subnet gets the correct AZ and IP range without confusion.

##**4.Why can’t we reuse the same CIDR for multiple subnets?**

Even though a VPC has a large CIDR range, AWS does not automatically split that range into smaller networks. Every subnet must explicitly define the exact IP range it owns. If two subnets claim the same CIDR block, AWS cannot determine which subnet should receive traffic for a given IP address.
For example, **this will fail**:
public_cidr  = ["10.0.0.0/24", "10.0.0.0/24"]

Both subnets are trying to use the same IP range (10.0.0.0 – 10.0.0.255). AWS immediately rejects this because the ranges overlap.

The correct way is to define distinct, non-overlapping ranges, like this:
**public_cidr  = ["10.0.1.0/24", "10.0.2.0/24"] **
**private_cidr = ["10.0.101.0/24", "10.0.102.0/24"] **

##**5.How does Terraform assign the correct AZ and CIDR?**

Terraform creates subnets one by one using an internal counter called **count.index**. On each iteration, Terraform uses this index to pick values from the availability zone list and the CIDR list at the same position. Because both lists are ordered the same way, the correct AZ and CIDR always stay aligned.

For example, if the variables look like this:
**aws_azs     = ["ap-south-1a", "ap-south-1b"]
public_cidr = ["10.0.1.0/24", "10.0.2.0/24"]**

Terraform processes them like this internally:

**First subnet (count.index = 0)**

AZ -> ap-south-1a

CIDR -> 10.0.1.0/24

**Second subnet (count.index = 1)**

AZ → ap-south-1b

CIDR → 10.0.2.0/24

Because the same index is used for both lists, there is no guesswork and no mismatch between AZs and CIDR blocks.


