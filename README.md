# [WIP] Deploying a dask cluster on EC2 spot instances

This demonstrates how to set up a `dask.distributed` cluster
on EC2 spot instances.

Leveraging existing devops tools like Terraform and Docker, 
we aim to provide easy to deploy and highly customizable dask
cluster configurations while keeping scripts to a minimum.

For now, the recipes provided in this repository remains highly
experimental, untested and not recommended for use in any settings.
For a more thorough and mature solution see: [dask/dask-ec2](https://github.com/dask/dask-ec2),
an easy to use command-line tool to create dask clusters on EC2,
part of the official dask project.

## Prerequisites

* [Terraform](https://www.terraform.io/downloads.html) and
  [Packer](https://www.packer.io/downloads.html) binaries in PATH
* AWS credentials set in `~/.aws/credentials`

## Quickstart

**Create the base AMI with `packer`** (install docker and build container):

```bash
packer build images/dask_base_cpu.json
```

Note: add argument `--force` to re-create an existing AMI.

**Generate an ssh key** to access dask-scheduler and worker nodes:

```bash
mkdir -p .ssh
ssh-keygen -t rsa -b 4096 -C "dask_node" -f .ssh/dask_node_key -P ""
```

**Create the cluster with `terraform`**:

```bash
terraform plan
terraform apply
```

**Set up port redirection** to access the dask scheduler:

```bash
ssh -N -i .ssh/dask_node_key \
    -L 8786:localhost:8786 \
    -L 9786:localhost:9786 \
    -L 8787:localhost:8787 \
    ubuntu@[scheduler.public_ip]
```

**Run dask jobs**:

```python
from dask.distributed import Client

def square(x):
    return x ** 2

client = Client('127.0.0.1:8786')

# TODO: add a substantive example of dask job.
squares = client.map(square, range(100))

print(client.gather(squares))
```

Check the scheduler UI: [localhost:8787/status](http://127.0.0.1:8787/status)

**Release AWS resources** when all jobs are finished:

```bash
terraform destroy
```

## TODO and ideas

* Use docker registry
* Use Kubernetes or ECS
* Command line tool?
* GPU image/container with CUDA 8 support
* Dask job example
* Use terraform variables
* Support for other cloud providers (openstack, GCE, etc.)