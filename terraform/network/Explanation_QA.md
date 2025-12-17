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

**6.What problem does STS AssumeRole solve?**

Imagine this situation:

You are running Terraform from your laptop or an on-premise server. AWS must trust you, but AWS should not trust your laptop forever.

If AWS allowed permanent credentials with full permissions:

1. Anyone stealing those keys could destroy everything

2. Keys would never expire

3. Auditing would be difficult

**STS (Security Token Service)** solves this by issuing temporary credentials.

When you assume a role:

1. AWS gives you credentials that expire

2. Those credentials have only the permissions defined on the role

3. Once expired, they are useless

This dramatically reduces blast radius.

**7. What does “AssumeRole” actually mean?**

AssumeRole literally means changing identity.

You start as one identity (an IAM user).
After calling STS, AWS treats you as a role instead.

It is not a permission upgrade.
It is an identity switch.

A good analogy is logging into a corporate system. You first log in with your username, then you switch to an admin console for a short time. While you are in admin mode, your normal user permissions no longer apply.


**8. What does this AWS CLI profile configuration really do?**

When you configure:

[profile terraform-network]
role_arn = arn:aws:iam::414394709396:role/sts-assume-role
source_profile = manoj2


You are telling AWS CLI:

**Whenever someone uses terraform-network, first authenticate as manoj2, then assume sts-assume-role, and use the role’s permissions.**

Terraform does not see the user.
Terraform only ever sees the role.

**9.When do organizations use STS vs AWS SSO?**

Both are used, but for different reasons.

**AWS SSO is commonly used for:**

Human access

Developers

Admins

Console and CLI access

**STS AssumeRole with IAM users is still used for:**

On-premise automation

Legacy systems

Non-interactive services

Bootstrapping

In mature organizations, SSO is preferred, but STS is still everywhere behind the scenes.


**10.Why did aws sts get-caller-identity fail without a profile?**

Because AWS CLI defaulted to the default profile, which had no valid credentials.

When you explicitly used:

**--profile terraform-network**


AWS CLI knew:

Which user to authenticate as

Which role to assume

This is why the command succeeded.

Terraform behaves the same way.


**11. Can Terraform read .tfvars inside a module?**

No. Terraform never reads .tfvars from child modules.

Terraform runs only from the root directory.
Only the root module can load variable values.

Modules are like functions:

They declare inputs

They receive values from the caller

They never load configuration themselves

This is intentional and fundamental to Terraform’s design.

**12. Is variables.tf required in the root module?**

No. Terraform does not require it.

**If:**

Variables are declared in the module

Values are provided via root .tfvars

Terraform works fine.

However, production teams usually keep root variables.tf for clarity, validation, and readability.

**13. Are temporary credentials created for the user or the role?**

This confusion usually happens because we start by authenticating as a user, so it feels like AWS is upgrading that user. That is not what happens.

Temporary credentials are **never** created for the **IAM user**. They are **always created** for the **IAM role**.

The IAM user’s only responsibility is to ask AWS a single question:

**“Am I allowed to assume this role?”**

This is done using the **sts:AssumeRole** API.

For example, when this command is executed:

**aws sts assume-role \
  --role-arn arn:aws:iam::414394709396:role/sts-assume-role \
  --role-session-name terraform-session \
  --profile manoj2**


Here is what actually happens internally:

First, AWS authenticates the request using the IAM user credentials stored in the manoj2 profile. At this moment, AWS knows the caller is the IAM user manoj2.

Next, AWS checks two things:

**Does the role trust this user? (trust policy)**

**Is the user allowed to call sts:AssumeRole on this role? (user permission policy)**

If both checks pass, AWS issues temporary credentials for the role, not for the user.

Those credentials represent this identity:

**arn:aws:sts::414394709396:assumed-role/sts-assume-role/terraform-session**

From this point onward, the IAM user identity is no longer used. Every AWS API call is evaluated only against the role’s permission policies.

This is why the user can be extremely restricted, sometimes allowed to do nothing except sts:AssumeRole, while the role can have permissions like creating VPCs, subnets, or EC2 instances.

In simple terms:
The user opens the door.
The role is the one that walks inside.


**14. Why does AWS SSO exist if STS already exists?**

STS is a technical building block, not a user-friendly system. It solves one narrow problem:

**“How do I issue temporary credentials for a role?”**

**AWS SSO (now called IAM Identity Center)** exists because humans are bad at managing access keys. Keys get leaked, shared, forgotten, or stored insecurely. AWS SSO removes access keys entirely for human users.

Instead of creating IAM users with long-term keys, AWS SSO allows people to log in using:

**1.Email and password**

**2.MFA**

**3.Corporate identity providers like Active Directory, Okta, or Azure AD**

Under the hood, AWS SSO still uses STS, but it hides that complexity.

**How AWS SSO actually works internally (step by step):**

Assume a user named user@company.com wants to run Terraform.

First, an administrator sets up AWS IAM Identity Center in the AWS account. This creates a central identity store or connects AWS to an external identity provider.

**Next, the admin defines:**

1.An AWS account (for example, prod-account)

2.A permission set (for example, Terraform-Network-Admin)

3.A permission set is nothing more than:

a)One or more IAM policies

b)Wrapped into a role template

When the permission set is assigned, AWS automatically creates a role in the target account. You do not create this role manually.

**Then the admin assigns:**

User: user@company.com

Account: prod-account

Permission set: Terraform-Network-Admin

At this point, the configuration is complete.

**What happens when the user logs in with AWS SSO?**

When the user runs:

**aws sso login --profile terraform-sso**


This is what happens internally:

First, the user is redirected to a browser and authenticates using email, password, and MFA.

Once authentication succeeds, AWS SSO requests temporary role credentials from STS on behalf of the user.

STS issues temporary credentials for the SSO-managed role, not for the user.

These credentials are stored locally by AWS CLI and automatically refreshed.

From Terraform’s point of view, this is no different from STS AssumeRole. Terraform simply sees valid temporary credentials.

**How Terraform fits into AWS SSO**

After SSO login, Terraform runs normally:

export AWS_PROFILE=terraform-sso
terraform plan


Terraform does not know:

Who the user is

How they authenticated

Whether MFA was used

It only knows that valid credentials exist and that those credentials represent a role with certain permissions.

**Key mental model**

STS is the engine.
AWS SSO is the steering wheel.

STS issues temporary credentials.
SSO decides who is allowed to get them and how.

This is why organizations say they “use SSO”, but technically everything still runs on STS underneath.

