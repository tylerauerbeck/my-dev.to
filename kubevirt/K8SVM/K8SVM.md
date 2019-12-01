Traditionally there have been very clear battle lines drawn for application and infrastructure deployment. When you need to run a Virtual Machine, you run it on your virtualization platform (Openstack, VMWare, etc.) and when you need to run a container workload, you run it on your container platform (Kubernetes). But when you're deploying your application, do you really care where it runs? Or do you just care that it runs **somewhere**?

This is where I entered this discussion and I quickly realized that in most cases, I really didn't care. What I knew was that I needed to have the things I required to build my application or run my training. I also knew that if I could avoid having to manage multiple sets of automation -- that would be an even bigger benefit. So if I could have both running within a single platform, I was absolutely on board to give it a shot.

## What is KubeVirt?

[KubeVirt](https://kubevirt.io/) is a set of tools used to run Virtual Machines on top of a Kubernetes environment. You may have needed to read that through a few times, but it's true, Virtual Machines running on top of your container platform. There's no need for separate VM's running elsewhere, just one place to deploy all of your things. I'm sure like many others you've heard "You can run anything in a container!". While that's mostly true, that doesn't necessarily guarantee that it won't be hard or it won't force you to make some terrible decisions along the way. So if you find yourself heading down this path, ask yourself the following question: "If you can have both while reducing your cost (both technical and mental), what's stopping you?"

## What benefits does KubeVirt provide?

So what actual benefits does KubeVirt provide? From my experience, it reduces cognitive load on folks who are trying to deploy your application (whether that be manual deployments or the automation for those deployments). Rather than having to manage multiple workflows that know when something is going to platform A or platform B -- we now have a common deployment model. And it's YAML all the way down my friends.

![Yay YAML](https://media.makeameme.org/created/yaml-5b3167.jpg)


And while we all may have our gripes with YAML, it reduces the cognitive lift of having to figure out what you're looking at when you're handed a new application to deal with. You may not know _exactly_ what it is that you're deploying, but you can safely assume that you're just a `kubectl apply -f ` away from finding out. This standardization can greatly increase the efficiency of your dev/ops/devops teams because now they're all operating and communicating in a common set of tooling rather than breaking them into smaller teams based off of different skill sets.

The second benefit that you can get from using KubeVirt is (potential) savings from consolidating your tech stack. Rather than running separate sets of infrastructure for your virtualization and container platforms, you can begin consolidating these stacks for common purposes. To be clear, this isn't going to be something that you wave a magic wand at and it would suddenly become a consolidated stack. It would look more like (something something something). However, once you begin that journey, you would then begin to see potential savings in things like software and utility costs. Depending on your workloads, you may also see an added benefit of being able to decrease your infrastructure completely because Kubernetes may be better at packing/scheduling your applications together than other systems. These benefits tend to vary based on workload, so your mileage may vary.

The last benefit that comes to mind are the things that a container platform provides you. When a virtual machine dies it generally stays dead until something tells it to power back on -- whether that be something inside of the virtualization platform itself or some other monitoring system that either tells it (or tells someone) to bring it back online. Even at this point, the system may come back online -- but it may not be in great shape (re: healthy). The scheduling capability that Kubernetes provides is a huge boost due to the fact that if something is scheduled to be running, it will continue to make sure that it is running. And with things like liveness and readiness probes, you now get these low-level monitoring components for free. So the need to engage either an external system or members of your team decrease from these capabilities alone. So now if something goes wrong, it really must have gone wrong before you need to become engaged. (feels like I need a bookend here)

## Scenario: Building an Ansible training on Kubernetes

These details are all fine and dandy, but for me it's always useful to see these tools in action before I tend to grasp some of these concepts. So I'm going to walk through the scenario that had me looking at KubeVirt in the first place. It all started with not having the permissions that I needed...

![This is fine](https://cdn.vox-cdn.com/thumbor/2q97YCXcLOlkoR2jKKEMQ-wkG9k=/0x0:900x500/1200x800/filters:focal(378x178:522x322)/cdn.vox-cdn.com/uploads/chorus_image/image/49493993/this-is-fine.0.jpg)

I was working with a customer and we quickly realized that we needed to catch them up to speed quickly if we were going to be able to be useful to them in the small amount of time that we had scheduled together. This meant that I needed to introduce the tools, make sure they were able to work with them (re: install and use them) and then make sure that they would be in good shape once we left. We do this a lot, so helping folks get up to speed didn't concern me at all. However the next piece of information I was given **haunts** me anytime I hear it.

> We don't have privileges on our local machines.



Listen. I understand. We live in a scary world. There is always someone looking to poke a hole in your organization. But there needs to be balance. You need to make sure the people that you employ have the ability to do their job. Otherwise you are wasting valuable time that your people have that could be spent providing value to your organization and are effectively telling them to sit on their hands until someone tells them that they can begin working again. I also understand that there are ways to effectively manage these types of risks.<sup>1 `create a link here`</sup> This was not one of these times.

So stepping off of my soapbox and back to our scenario. Once I heard this and it was explained to me what needed to happen in order to get the necessary software onto their machines, I knew that I needed to come up with a plan. To be successful here, I needed to be able to get a set of tools (primarily Ansible) onto their local machines and then make sure that they had a set of machines to work against. Problem number one was getting these tools approved for installation. At a high level, this required a significant amount of paperwork (tickets, sign-offs, etc.). The next part was getting the appropriate teams to provide a set of VM's to each of our developers so that they could use them to get familiar with Ansible. A rough estimate was given to me that essentially chewed into half of our scheduled time together before we would even receive them. Considering that we couldn't do much without getting them familiar with the tools beforehand, this was a non-starter for me.

So it was time to get creative.

![Mad Scientist](https://images2.minutemediacdn.com/image/upload/c_fill,g_auto,h_1248,w_2220/f_auto,q_auto,w_1100/v1555384675/shape/mentalfloss/doc_0.jpg)


## The problem?

So let's first clearly define the problem. I needed to get Ansible in the hands of developers and provide them with a way to begin learning this technology. 

This required the following:
- (1) workstation to run Ansible from
- (2) VM's to run Ansible against

🚨🚨 **Note:** _Yes, I could have used that single workstation to both run the Ansible from and run the Ansible against. However I was looking to provide a better illustration of the benefits of Ansible, along with how it's used in a real-world scenario._ 🚨🚨

## The goal?

So we have a clearly defined problem. At this point, I at least had a cluster available to me throughout the engagement. I also knew by the end that the customer would also have a cluster available to them. The goal here was to both upskill them on new technologies and also ensure that they were able to "take it home" with them so that they could begin upskilling others in their organization. While I could have just solved this with my own cloud money, this wouldn't have solved exactly what we were trying to do there. Granted this was a self-imposed constraint, but one that I decided was valid because of the restrictions that were in place in their organization and would likely take some time to unwind before they were (hopefully) lifted.

## The solution!

This is when I ran into KubeVirt. I quickly realized that we had all the access we needed to be able to deploy and run things in the cluster. So after a quick proof-of-concept, I felt fairly confident that we could do what we needed to do all within the cluster. The big challenge at the time was ensuring that we were able to communicate over the network using the protocols that we needed to (primarily SSH required by Ansible). There were likely a ton of better ways to solve this problem and there are absolutely better ways that I know of doing this now. But to avoid having to dig a bit into Kubernetes networking, I'll stick with the simplest <strike>solution</strike> hack that I found to get around the problem at the time. So without further delay, let's get to work.

### Step 1: Find yourself a Kubernetes platform

While this scenario was originally run on an Openshift cluster, this will work on any Kubernetes platform. To keep things simple, I'll use [KinD](https://github.com/kubernetes-sigs/kind). The only thing you need to get this running is to grab the KinD release from Github and to have Docker running on your machine. For the purposes of this article, we'll be using KinD version [v0.6.0](https://github.com/kubernetes-sigs/kind/releases/tag/v0.6.0).

Once we've pulled down the binary, we'll need to ensure that it's somewhere in our path. We also need to define what our cluster is going to look like. Let's create a directory called `kv-demo` and then create the following file called `cluster.yml`.

```yaml
kind: Cluster
apiVersion: kind.sigs.k8s.io/v1alpha3
nodes:
- role: control-plane
- role: worker
```

What this will give us is a 1 master & 1 worker cluster to start working with. All we need to do is deploy this and we'll be ready to get started. You can do this with the following command: `kind create cluster --config cluster.yml --name kv-demo`. After running this command you'll see output similar to the one below:

```
Creating cluster "kv-demo" ...
 ✓ Ensuring node image (kindest/node:v1.16.3) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-kv-demo"
You can now use your cluster with:

kubectl cluster-info --context kind-kv-demo

Thanks for using kind! 😊

```

As long as this matches up, move on to the next step.

### Step 2: Install KubeVirt

Now that we have a platform to deploy on top of, we can go ahead and get the required components up and running. For this example, we'll use KubeVirt [v0.23.0](https://github.com/kubevirt/kubevirt/releases/tag/v0.23.0). If you would like to use the CLI `virtctl`, this is where you can grab it from. Otherwise there's nothing that you need directly from this repository as we'll be referencing files remotely.

#### Nested Virtualization Check

The first thing you need to do is to see whether nested virtualization is enabled on your host. To do this, run the following: `cat /sys/module/kvm_intel/parameters/nested`. If the response is `Y`, then move on to the next step. If the response is `N`, then you'll need to create a configmap with the following: `kubectl create configmap kubevirt-config -n kubevirt --from-literal debug.useEmulation=true`.

### Deploy KubeVirt Operator

Once the config is in place, we can deploy the initial KubeVirt components. The first piece that needs to be put in place is the operator. Run the following to deploy the operator: `kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/v0.23.0/kubevirt-operator.yaml`. This deploys the following components:
- `kubevirt` namespace
- `kubevirts` custom resource definition
- `kubevirt.io:operator` clusterrole
- `kubevirt-operator` service account
- `kubevirt-operator` clusterrole
- `kubevirt-operator` clusterrolebinding
- `virt-operator` deployment

Once you see these objects applied, you'll need to monitor the progress of your deployment. You can monitor this by watching for the pods to be created in the `kubevirt` namespace with `kubectl get pods -n kubevirt -w`. Once you see that everything is running and ready, we can move on to the next step. You can see the below output for reference output.

```
NAME                             READY     STATUS    RESTARTS   AGE
virt-operator-6b494c9fc8-l466w   1/1       Running   0          4m28s
virt-operator-6b494c9fc8-zql77   1/1       Running   0          4m28s
```

#### Deploy KubeVirt

Now that our operator is up and running, we can create a custom resource that will tell the operator to deploy KubeVirt itself. This consists of the `virt-api`, `virt-controller` and `virt-handler` components. If you're interested in the architectural specifics of the deployment, you can see a nice description [here](https://github.com/kubevirt/kubevirt/blob/v0.23.0/docs/architecture.md) from the KV team. Once you're ready to deploy these components, you can run the following: `kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/v0.23.0/kubevirt-cr.yaml`. You'll see that this creates a single instance of a `kubevirt` resource called `kubevirt`. This deployment can take some time, but you can again run `kubectl get pods -n kubevirt -w` to monitor the progress. You should eventually see output that looks something like what you see below:

```
NAME                               READY     STATUS    RESTARTS   AGE
virt-api-69769c7c48-dh2zj          1/1       Running   0          3m42s
virt-api-69769c7c48-p84lq          1/1       Running   0          3m42s
virt-controller-6f97b858b7-94fv7   1/1       Running   0          3m15s
virt-controller-6f97b858b7-cfhnv   1/1       Running   0          3m15s
virt-handler-bmmwn                 1/1       Running   0          3m15s
virt-operator-6b494c9fc8-l466w     1/1       Running   0          24m
virt-operator-6b494c9fc8-zql77     1/1       Running   0          24m
```

### **Intermission**

Congratulations! At this point, we've got KubeVirt up and running. But before we start deploying our virtual machines, we want to make sure we've got somewhere to work from. To accomplish this, we'll be deploying a container inside of our cluster that we can connect to. This accomplishes two goals. The first being that if we define an image that has all of our tools already pre-baked into the container -- that leaves one less thing that we leave up to user error.


![works on my machine](https://res.cloudinary.com/teepublic/image/private/s--qdBkljDY--/t_Preview/b_rgb:ffffff,c_limit,f_jpg,h_630,q_90,w_630/v1516825854/production/designs/2305863_0.jpg)


The second goal that we accomplish is that we ensure we have access to a common network and can easily communicate with our virtual machines. Again, this was a bit of a hack that we went through at the time and there are absolutely better ways of doing this. But that discussion can be saved for another time.

Now back to work.

### Step 3: Get yourself a workspace container

As mentioned above, the next step is ensuring that we have a workspace to operate from. We'll do this by using a container than has the necessary toolset already made available for us. In our scenario, we already had one pre-built which you can find the Dockerfile for [here](https://raw.githubusercontent.com/redhat-cop/containers-quickstarts/v1.16/tool-box/Dockerfile). This has a number of tools already pre-installed on top of our RHEL 8 base image, but most importantly it has Ansible. You can cut this down as you see fit or you can use it as is -- your choice. If you're satisfied what how this looks, then you can just rely on a pre-built version of this image that we have hosted in Quay: `quay.io/redhat-cop/tool-box`.

So once you've decided on how you'd like to use this image, we can then deploy it into our cluster with the following

```
kubectl create user-ns
kubectl create deployment tool-box --image=quay.io/redhat-cop/tool-box:v1.16 -n user-ns
```

This will give us a new namespace and will then create a deployment of our tool-box container. You should see this is running with `kubectl get pods -n user-ns`.

```
NAME                      READY     STATUS    RESTARTS   AGE
tool-box-64f5d796-2db66   1/1       Running   0          3m49s
```

🚨🚨 **Note::** _If you built this locally or pushed it to your own remote registry, you simply just need to replace the quay registry above with the appropriate image registry, image name and tag._ 🚨🚨

Now in order to check that we have connectivity to our workspace, we exec into our pod and run some commands to make sure we're in good shape. Run the following:

```
kubectl exec -it tool-box-64f5d796-2db66 /bin/bash
whoami
ansible --version
```
🚨🚨 **Note:** _You should replace the name of the toolbox container above with the one that appears on your screen. This will absolutely be different in your cluster than what I have in mine._ 🚨🚨

After running the above commands, you'll see output similar to the following:

```
bash-4.4$ whoami
tool-box
bash-4.4$ ansible --version
ansible 2.8.6.post0
  config file = None
  configured module search path = ['/home/tool-box/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/local/lib/python3.6/site-packages/ansible
  executable location = /usr/local/bin/ansible
  python version = 3.6.8 (default, Oct 11 2019, 15:04:54) [GCC 8.3.1 20190507 (Red Hat 8.3.1-4)]
```

As long as this all checks out, we've got a functional workspace. Now we're ready to start working with some VM's!

### Step 4: Now for some Virtual Machines

As part of our KubeVirt deployment, we created a handful of CRD's. One of those was called `virtualmachineinstances`. As you may guess, this is one way we have of creating a VM. There are additional methods, but this is the approach we'll take as part of this example. We'll focus on just deploying a single VM for brevity. However, you can customize this into a template to fit your requirements (or even just modify and run multiple times) in order to create multiple VM's. In order to create our single instance, you can run the following:

```
kubectl create -f https://raw.githubusercontent.com/tylerauerbeck/my-dev.to/master/kubevirt/K8SVM/files/vmi.yml -n user-ns`
```

After a few minutes, you should see something similar to the following:

```
NAME                               READY     STATUS    RESTARTS   AGE
tool-box-64f5d796-2db66            1/1       Running   0          54m
virt-launcher-vmi-fedora-0-cj4c2   2/2       Running   0          7m18s
```

What this will do is create a VM called `vmi-fedora-0` in your `user-ns` namespace. This will then be recognized by KubeVirt and it will then begin deploying your VM. If you inspect the `yml` above, you'll notice a few things:

```
  volumes:
  - containerDisk:
      image: kubevirt/fedora-cloud-container-disk-demo:v0.21.0
```

This image that we refer to is a pre-built Fedora image from the KV team. If you'd like to know more particulars about how this image is built, you can read more [here](https://kubevirt.io/user-guide/docs/latest/creating-virtual-machines/disks-and-volumes.html#containerdisk). All you need to know for now though is that this is just a Fedora base image that we use to spin up our VM.

The next piece you may notice is the following cloudInit:

```
cloudInitNoCloud:
      userData: |
        #cloud-config
        hostname: fedora-0
        password: fedora
        chpasswd: { expire: False }
        ssh_pwauth: True
        disable_root: false
        ssh_authorized_keys:
          - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDsYL8SnJf3blzXmsqJrdyz8RF88W+k9tv/5muoL9ieUGpI67cCKbzCInfKRiuMaDd51D8f+ezZzwx6x/sSbhaDIA90cPBCJIVXY3sVLTSIYK+EzfzDdgYBdpphsRCapwK++5Yev68NT/02BJRbqXhNrYcE4bj2GEQX6Tq8n3LqOYg3j5TvmCBvxut7qztn16rNHFBFF2K/AEavzkyFrzaddFAdVzmV79zBAhCYwoRWhXffMr0NxihxdbglT7qNRtJbOlvBgbYinn2rSsXrSF+1TdCHk3Uo+H5q2sfSDtMQCN32Oh+bCG/zxwL8p2hbdC6AKIk3LzICTqFa+gRCvOWR 
```

There are plenty of things that you can specify here, but the ones to take note of here are:
- Setting a hostname
- Setting a default password
- Not disabling the root user
- Providing a public key to be inserted as part of the image (you can modify and use your own key)

To avoid introducing too many moving parts, I had initially decided to hard-code some of these things so that we could slowly build up a comfort and knowledge-base versus opening the firehose to start. If you would like to use the key that is already added to this `yml`, you can retrieve it [here](https://raw.githubusercontent.com/tylerauerbeck/my-dev.to/master/kubevirt/K8SVM/files/id_rsa).

🚨🚨 **Note:** _I know keeping private keys in public repositories are bad. This is for testing purposes and I don't ever recommend doing this for any real-world workloads._ 🚨🚨

### Step 5: The finish: Let's run a playbook!

Alright, so now we're in the home stretch. We have a workspace to do our work from and we have a virtual machine to do our work against. Now we just need to add the last piece: **the work**. So let's get started! The first thing we'll want to do is take note of a piece of information that we'll need later. In order for us to write an Ansible playbook, we need to know what host we need to run against. Again, in this case we're going to keep it simple and just grab the IP address for the VM. You can get this by running `kubectl get vmi -n user-ns`. You should then see output similar to:

#### Get your IP address

```
NAME           AGE       PHASE     IP            NODENAME
vmi-fedora-0   18m       Running   10.244.1.11   kv-demo-worker
```

You should notice the IP column. Grab this value and stash it for later.

#### Configure your workspace

Now that we have the IP address for where we need to connect, let's make sure that our workspace is in good shape to begin communicating with it. The first thing we need to do is reconnect to our tool-box container. We can do this again by running `kubectl exec -it tool-box-64f5d796-2db66 /bin/bash`. Once we're dropped back in our terminal we need to do a few things
- Retrieve our private key
- Configure an Ansible inventory
- Create a simple Ansible playbook

##### Retrieve Private Key and Test Connectivity

We need use `curl` to download our private key from the repository noted above (if you chose to use the example-provided public key). We could get fancier and  mount the key in as part of our deployment, but the point here was to keep things as simple as possible to start.

To get our key into the right space with the right permissions, run the following:

```
mkdir -p /home/toolbox/.ssh
cd /home/toolbox/.ssh
curl -O https://raw.githubusercontent.com/tylerauerbeck/my-dev.to/master/kubevirt/K8SVM/files/id_rsa
chmod 700 id_rsa
```

We can then test that we can connect to our VM with the following: `ssh fedora@10.244.1.11 hostname`. This should return you the hostname and look similar to this output:

```
bash-4.4$ ssh fedora@10.244.1.11 hostname
vmi-fedora-0
```

##### Ansible 101

Now that our workspace and VM can communicate with each other, we'll roll in the last layer of our exercise: teaching some Ansible. The goal of this article wasn't to become an Ansible expert, so we're just going to do a very simple user creation to demonstrate tying all of this pieces together. The first thing we need to do is pull together our inventory. This tells our playbook where it's connecting to and how. Let's do the following in our tool-box container:

```
cd
mkdir inventory
touch inventory/hosts
```

Once this structure has been created, add the following to your hosts file:

```yaml
---
[my-test-group]
10.244.1.11 ansible_ssh_user=fedora
```

This will allow us to specify this group to execute our playbook against. The playbook itself is the second key to all of this. This specifies what actions we're going to be taking. To get this created, let's run the following (again inside of the tool-box container):

```
cd
touch playbook.yml
```

Once this file has been created, add the following content:

```yaml
---
- name: Create Test User
  hosts: my-test-group
  tasks:
    - name: Add the user 'james' with a bash shell, appending the group 'admins' and 'developers' to the user's groups
      user:
        name: james
        shell: /bin/bash
        append: yes
      become: true
```

Once this is ready, we can go ahead and run our playbook, which creates a user named `James` on the VM that we had created. We can confirm this by remote accessing the host via SSH and checking that the user James exists.

```
bash-4.4$ ssh fedora@10.244.1.14 "id james"
uid=1001(james) gid=1001(james) groups=1001(james)
```

## Conclusion

This approach is meant to show how you can go about using these technologies together. I was able to collapse the need for managing multiple methods of automation to create a Kubernetes cluster and separate VM's for my training. On top of that, I was able to collapse this down even farther because previously we needed to be able to deploy these types of automation in various types of cloud environments (AWS, Azure, GCP, etc.) as well as different on-premise environments. By taking this approach, we were able to break this down to the point that we only needed to rely on a single interface, the Kubernetes API.

# Disclaimer

These are just my thoughts and experiences. For more thorough information on KubeVirt visit their [website](https://kubevirt.io/) or check out their [Github](https://github.com/kubevirt/kubevirt). There are plenty of extra bells and whistles available to be used -- so make sure to dig deeper to continue to gain the benefits that they provide!
