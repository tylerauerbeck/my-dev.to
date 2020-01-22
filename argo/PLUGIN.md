# Adding a custom plugin to ArgoCD

#TODO:
- Update patch to insert plugin into argocd-cm
- Replace Argo -> ArgoCD

# What is ArgoCD

[ArgoCD](https://github.com/argoproj/argo-cd) describes themselves as a "declarative, GitOps continuous delivery tool for Kubernetes". If we want to break this down a bit -- this is really just a nice way of saying that ArgoCD is a system that provides you a way of defining how you want your application deployments to look, watches a Git Repo for any changes to that definition and then provides you a way of keeping those two things in sync.

This can be quite a useful tool and actually has quite a bit of functionality already built in to get you started. If you've got helm charts, kustomize templates, ksonnet/jsonnet or even just plain yaml laying around, ArgoCD is ready for you! But what if that's not the case? What if your application actually relies on a seperate set of tooling that isn't built in to Argo? Well have no fear! Argo actually provides you with the ability to include your tools inside of the project so that you can quickly get started. 

But before we dig into the how this can be done, there's a few things that we should probably understand that will make this journey a bit less painful (or maybe at least make the pain understandable). Argo provides you the ability to add any tool you'd like to the system. The catch is that whatever tool you're using then needs to spit out YAML to stdout. That might not be too much of an issue as most tools know how to speak YAML these days. I YAML, you YAML, we all YAML at this point. The catch is that this YAML output is then interpreted/processed by kubectl. For the most part (re: standard components/objects) this isn't an issue. However, when you're off in the wild using non-standard objects then you're going to have a small (although easy enough to overcome) issue. Keep this in mind as our particular example will bump into and then address this.

# The Problem

So what problem are we looking to solve here? As a Red Hatter I do a lot of my work on top of Openshift. This means that I've ended up with quite a few Openshift templates that I use on a regular basis. But in order to be able to use them together with ArgoCD I need to be able to use the openshift client `oc` to process these templates before applying them. The downside is that this isn't natively available to ArgoCD. So we need to find a way to fix this. 

Ideally the way this would work is something like:
- Configure Argo so that it knows about the `oc` client and how to use it
- Tell Argo to use our new `oc` plugin to process our template
- See that Argo deploys all objects specified by the specified template

So there are a handful of small problems that we're tackling here. Now let's get started! The first thing that we'll need to do though is deploy ArgoCD. So let's run through this quickly.


---
🚨🚨🚨

**Note:** Technically the first thing we'll need to do is find ourselves an Openshift cluster since this is the specific plugin that we'll be using. You have a few options here including:
- Local:
  - [Minishift](https://github.com/minishift/minishift/) - Run a single node Openshift 3.X cluster locally
  - [CodeReady Containers](https://github.com/code-ready/crc) - Run a single node Openshift 4.X cluster locally
- Cloud Provider - Managed
  - [Openshift Dedicated](https://www.openshift.com/products/dedicated/) - Openshift running on AWS, managed by Red Hat 
  - [ARO](https://www.openshift.com/products/azure-openshift) - Openshift running on Azure, managed by Red Hat and Microsoft
- Self-Hosted 
  - This is of course an option if you're running your own clusters. This is a much bigger yak to shave, so some additional effort will be required here if this is new to you.

That being said, Openshift is only required in this instance because of our specific use case (using Openshift templates). It isn't required in all cases where you want to add an additional plugin (ex. adding Ansible, Terraform, etc. to Argo).
🚨🚨🚨

--- 

# The Setup

# Deploy Argo

Before we can do anything, we'll need to get Argo running in our cluster. For our purposes, we'll run the latest release: [v1.3.6](https://github.com/argoproj/argo-cd/releases/tag/v1.3.6). If you're interested, you can visit their Github to take a look at this. We'll keep things simple and use the non-ha deployment, which can be deployed with the following:

```
> oc new-project argocd
> oc apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v1.3.6/manifests/install.yaml
```

Once this has been executed, you'll see output similar to the following:

```
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io configured
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io configured
serviceaccount/argocd-application-controller created
serviceaccount/argocd-dex-server created
serviceaccount/argocd-server created
role.rbac.authorization.k8s.io/argocd-application-controller created
role.rbac.authorization.k8s.io/argocd-dex-server created
role.rbac.authorization.k8s.io/argocd-server created
clusterrole.rbac.authorization.k8s.io/argocd-application-controller configured
clusterrole.rbac.authorization.k8s.io/argocd-server configured
rolebinding.rbac.authorization.k8s.io/argocd-application-controller created
rolebinding.rbac.authorization.k8s.io/argocd-dex-server created
rolebinding.rbac.authorization.k8s.io/argocd-server created
clusterrolebinding.rbac.authorization.k8s.io/argocd-application-controller configured
clusterrolebinding.rbac.authorization.k8s.io/argocd-server configured
configmap/argocd-cm created
configmap/argocd-rbac-cm created
configmap/argocd-ssh-known-hosts-cm created
configmap/argocd-tls-certs-cm created
secret/argocd-secret created
service/argocd-dex-server created
service/argocd-metrics created
service/argocd-redis created
service/argocd-repo-server created
service/argocd-server-metrics created
service/argocd-server created
deployment.apps/argocd-application-controller created
deployment.apps/argocd-dex-server created
deployment.apps/argocd-redis created
deployment.apps/argocd-repo-server created
deployment.apps/argocd-server created
```

You'll also want to make sure you download the CLI if you prefer to interact with Argo via the command line rather than the UI. You can grab these for Linux or Mac below:
- [Linux](https://github.com/argoproj/argo-cd/releases/download/v1.3.6/argocd-linux-amd64)
- [Mac](https://github.com/argoproj/argo-cd/releases/download/v1.3.6/argocd-darwin-amd64) 

After this is all in place, you will ultimately end up with something that looks like:

```
> oc get pods -n argocd                                                    

NAME                                             READY     STATUS    RESTARTS   AGE
argocd-application-controller-6665b6c4d5-2vs4p   1/1       Running   0          55s
argocd-dex-server-6799d954b4-xdx7w               1/1       Running   1          55s
argocd-redis-7dc58875bf-2b5kn                    1/1       Running   0          55s
argocd-repo-server-5b9ddb4f7-2w7jv               1/1       Running   0          55s
argocd-server-6b8df9749-7qz29                    1/1       Running   0          54s
```

# Accessing Argo

# Reset Password - Part 1

By default the credentials you use are `admin` and the password is the name of the **initial** pod name of the `argocd-server`. This is a very important distinction to make because depending on the route you take, you can find yourself in a bit of an inception loop. That is -- you need the initial pod name to be able to reset your password. But in order to access Argo to reset your password, you may need to patch the pod to make the `argocd-server` available externally. Once you patch the pod though, it spins up a new pod and you've lost the name of that first pod. In order to recover from that point you either need to do a bit of digging (or some light digital arson) in order to get back to a point where you can reset the password. In our case though, let's be prepared and grab everything we need before patching our pod. To do this, let's search for our `argocd-server` pod specifically and filter everything else out:

```
> oc get pod -l app.kubernetes.io/name=argocd-server

NAME                            READY     STATUS    RESTARTS   AGE
argocd-server-6b8df9749-7qz29   1/1       Running   0          1m
```

Now that we've got the value that we need (`argocd-server-6b8df9749-7qz29`), let's move forward and expose the `argocd-server` pod so that we can officially reset this password.


# Expose ArgoCD UI

At this point, the ArgoCD UI isn't actually exposed outsdie of the cluster. This is an issue because we have no way of resetting our password, but also because in order to even interact with Argo (without the UI) we need to be able to use the CLI to contact it and set up our connection. So let's expose this endpoint so that we can get started.

 In our case, we're using Openshift. This means that we'll be interacting with Argo using a `Route`. This is a bit different than out of the box Kubernetes, where you would rely on an Ingress or LoadBalancer of some sort. To set up our route, we can just run:

```
> PATCH='{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"argocd-server"}],"containers":[{"command":["argocd-server","--insecure","--staticassets","/shared/app"],"name":"argocd-server"}]}}}}'

> oc -n argocd patch deployment argocd-server -p $PATCH

> oc -n argocd create route edge argocd-server --service=argocd-server --port=http --insecure-policy=Redirect
```

Once these commands have been run, you can check to see that a route exists:

```
> oc get routes -n argocd

NAME            HOST/PORT                                         PATH      SERVICES        PORT      TERMINATION     WILDCARD
argocd-server   argocd-server-argocd.apps.c1.internal.auerbeck.dev             argocd-server   http      edge/Redirect   None
```

> h/t to [Mario Vázquez](https://twitter.com/mvazce) who I grabbed this from [here](https://blog.openshift.com/introduction-to-gitops-with-openshift).

---
📝📝📝 

**Note:** However if you're following along and want to use just Kubernetes, you can choose to rely on some `LoadBalancer` magic from your cloud provider or are run something like [MetalLB](https://github.com/danderson/metallb) locally, you can just run:

```
> kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

Otherwise, if you're going to rely on Ingress you can follow the instructions that the Argo project supplies [here](https://argoproj.github.io/argo-cd/operator-manual/ingress/). 

📝📝📝

---

# Reset Password - The Finale

Now that we have an endpoint we can use to configure Argo, let's reset our password. We can do this by using the host value of the route that we created along with the argo CLI:

```
> argocd login --grpc-web argocd-server-argocd.apps.c1.internal.auerbeck.dev:443
```

Once we run this, we'll be prompted for a username and a password:

```
INFO[0000] tracing enabled=false                        
Username: admin
Password: 
```

Remember -- we need to use the value that we got for the `argocd-server` pod before we patched our deployment. If we try to use the new podname, we're going to run into issues. 

> Pain Point: There was mention of some light arson

That's right. You may find yourself in a position where you can't grab the original pod name, but you don't necessarily want to redeploy everything all over again. This is fine. We'll just need to (digitally) burn a few things down. What you'll need to do is modify the appropriate secret and remove two admin keys. After this, delete your `argocd-server` pod and it will repopulate the secret with new and appropriate values. But this time, make sure you take note of the podname! Otherwise you'll likely need to repeat these steps.

But with all that being said, as long as we use the appropriate pod value, we should see something that looks more like this:

``` 
'admin' logged in successfully
Context 'argocd-server-argocd.apps.c1.internal.auerbeck.dev:443' updated
```

And now that we're logged in we can run:

```
argocd account update-password
```

From here you'll be prompted for the existing password and then will be able to set your own. Do this now, otherwise you'll be fumbling around for that pod name during the rest of your development!

# **Bonus Content**: Use Openshift Authentication

So as you can see, there is a bit of a dance required in order to reset the password if you're going to be making changes or exposing Argo externally. Surely we have the technology to make this less painful! Well as a matter of fact we do and you have a few options here in general. But specifically for Openshift we now have the ability to integrate with Openshifts authentication system. This is a bit outside of the scope of this blog, but you can take a look at the details [here](https://blog.openshift.com/openshift-authentication-integration-with-argocd/) from [Andy Block](https://twitter.com/sabre1041/).

# Adding your custom plugin: The `oc` client

Now that we've got a functional system, we can begin adding our own bits to it. In our case, we are looking to add the oc client to ArgoCD and then let ArgoCD know how to use it. The first thing we will need to do is get our binary situated where it needs to be. This means that we'll need to edit the `argocd-repo-server` deployment.  There are two approaches we can take here depending on how complicated the plugin we're trying to add is. In our instance, we only need to add a single binary to the system (the `oc` client). This fits into the much simpler use case of just creating an `initContainer`, a volume and then mounting that volume into the `repo-server`. 

If it gets much more complicated than this (or if you have multiple binaries that you would like to add), the better option is to craft your own `repo-server` image (using your tooling of choice) and then have the repo-server use that image instead of the default image. This decision all comes down to your specific implementation. But in our case we'll be going with the first option that we described. To do this, we want to add the following patch:

```
spec:
  initContainers:
  - name: download-custom-tools
    image: quay.io/openshift/origin-cli:latest
    command: [sh, -c]
    args:
    - cp /usr/bin/oc /custom-tools/oc
    volumeMounts:
    - mountPath: /custom-tools
      name: custom-tools
  containers:
  - name: argocd-repo-server
    volumeMounts:
    - mountPath: /usr/local/bin/oc      
      name: custom-tools
      subPath: oc
  volumes:
  - name: custom-tools
    emptyDir: {}
```

Let's unroll this a bit so that we understand what's going on.

## initContainer

The first thing you'll notice is that we're adding an initContainer. We're doing this because we need to be able to initially grab the `oc` binary from somewhere so that it can later be passed along to the main `argocd-repo-server` image. We could do something like just utilizing a simple base image that has `wget` installed and then pulling the binary down from some endpoint. But, luckily for us, the Openshift team has already done the heavy lifting for us. The team provides a container image that already has the binary included. So what we can do is specify that the initContainer utilizes this image (`quay.io/openshift/origin-cli:latest`). Now that we know that the container that will be running already has the `oc` client available, all we need to do is copy it to our volume so that it can later be mounted by the repo server. We know that the oc client itself sits at `/usr/bin/oc`, so all we need to do is specify the args to our shell command be a simple copy (`cp /usr/bin/oc /custom-tools/oc`). The last step is to provide our mount and then we have a fully functional initContainer that loads an image that contains the `oc` client and then copies it over to our persistent volume so that it can later be used by the repo server.

## Container

The next component to this patch is the container itself. There is a considerable amount of configuration already done and provided inside of the existing repo server deployment. We absolutely don't want to have to provide that inside of our patch as those configurations may change between different versions of ArgoCD and that would be a considerable amount of overhead to maintain inside our patch just to keep up with this. But due to the strategic-merge nature of the `patch` command, all we need to do is provide the name of the container (`argocd-repo-server`) and then provide the components which we would like to add. In our case, this tells the container where to mount the volume that contains our `oc` binary. We're telling the deployment that we would like to make `oc` available at `/usr/local/bin/oc` since this is traditionally always in the $PATH. Once this has been patched in, the repo-server will then have the `oc` client available just like the others.

## Volume

The last (and very critical) part of this patch is creating the volume that the oc client will be installed to (so that it can be shared between the initContainer and the actual repo-server container). Without this volume, you may be moving the `oc` client around, but it'll never be available to the repo-server. So make sure that this gets included!

## Putting it all together

So now that we have our patch ready, let's apply this and validate that  our client is available as expected. To do this we can just run the following:

```
> PATCH='{"spec": { "template": { "spec": {"initContainers": [{"name": "download-custom-tools","image": "quay.io/openshift/origin-cli:latest","command": ["sh","-c"],"args": ["cp /usr/bin/oc /custom-tools/oc"],"volumeMounts": [{"mountPath": "/custom-tools","name": "custom-tools"}]}],"containers": [{"name": "argocd-repo-server","volumeMounts": [{"mountPath": "/usr/local/bin/oc","name": "custom-tools","subPath": "oc"}]}],"volumes": [{"name": "custom-tools","emptyDir": {}}]}}}}' 

> oc patch -n argocd deployment argocd-repo-server -p $PATCH
```

After running the above, we should then see:

```
deployment.extensions/argocd-repo-server patched
```

We can also take this one step further and connect to the pod and verify that the oc client is available. We can do this by using `oc rsh` to check this out. After running this against the appropriate pod name, we should see the below:

```
> oc rsh argocd-repo-server-5bb9476d4d-h9gqt oc version                    

Client Version: v4.2.0-alpha.0-342-gb6d9dcb
```

Great! Our client is now available. But at this point, Argo still doesn't know how to use it. This of course leads us on to the next phase.

# Let Argo know how to utilize our custom plugin

So while the `oc` client is now available to Argo, it doesn't quite know how to use it yet. In order to change this, we'll need to modify the `argocd-cm` configmap. Out of the box, there isn't any actual data in here. So we'll want to patch this object with the following:

```
data:
  configManagementPlugins: |
    - name: oc-template
      init:
        command: ["bash","-c"]
        args: ["if [ ! -z ${MERGE_TYPE} ]; then MERGE_TYPE=\"--type=${MERGE_TYPE}\"; else MERGE_TYPE=\"\"; fi && if [ -f ${TEMPLATE_NAME} ] || [[ ${TEMPLATE_NAME} =~ ^https? ]] ; then TEMPLATE_NAME=\"-f ${TEMPLATE_NAME} --local\"; fi && oc process ${TEMPLATE_NAME} --param-file=${PARAM_FILE} -o=json -n ${ARGOCD_APP_NAMESPACE} | oc patch -f - -p '{\"metadata\":{\"annotations\":{\"argocd.argoproj.io/sync-options\":\"Validate=false\"}}}' --dry-run=true -o=json ${MERGE_TYPE} -n ${ARGOCD_APP_NAMESPACE} | oc create -f - --dry-run=true -o=yaml -n ${ARGOCD_APP_NAMESPACE} > app.yaml"]
      generate:
        command: ["sh", "-c" ]
        args: ["oc create -f app.yaml --dry-run=true -o=yaml"]
```

As you can see, this isn't the most elegant looking solution. BUt we can talk about the specifics of what it's doing here in a moment. The important piece to know is that this configuration is providing Argo with the appropriate knowledge of our new plugin and the commands required to run when it is called. Just as with getting the binary in place, there is a bit to unpack here. So let's take a look so we understand the yaml that we're shoving into our configmap.

`configManagementPlugins` is the key that ArgoCD uses to store all of the custom configurations that you may need to add to the system. This is where you will provide all of your custom plugins and the command (or set of commands) that are required in order for it to spit out the appropriate yaml to deploy into your cluster.

From here, each plugin consists of the same basic parts: `name`, `init` and `generate`. The name is pretty self-explanatory. This is what you will specify inside of your ArgoCD application so that it knows to run this set of commands. `Init` is an optional component, but can be very useful. This is where you would specify any number of commands that need to happen to prepare your environment to generate the yaml. It can also be used to hack around and prettify your yaml output before ultimately sending the final product to the next phase. The last (and required) component of your plugin is the `generate` step. This is the command that is run to send your yaml to stdout, which will ultimately be applied by `kubectl`. So with this set of tools in our hand, we can specify the steps required to begin utilizing our openshift templates. Before we dig a bit deeper into this though, let's revisit what we're trying to do.

# The oc-template plugin

Now that we've got our plugin cobbled together, let's take a look at what is actually consists of.

## Init

Our init phase is just a tiny, in-line bash script. There are two small pieces of logic and then it pipes some inputs between different oc commands. Once this is all done, it then grabs the appropriate output and pipes it to a file called `app.yaml`. So why is all of this necessary? 

### Logic

The small if statement that we have included here is to determine whether we need to tack the `-f` and `--local` flags onto our commands because we're working with either local or remote files. If this isn't the case, then we just omit those flags and we will be working with internal cluster templates. The second if statement checks to see if there is a specific merge type specified. This is required for the scenarios that don't function appropriately with the default strategic merge type that the patch command uses.

### Piping Madness

The next part of our init command sees us use three different `oc` commands:

- process : The process command is used to apply our parameters into our templates. We utilize the `TEMPLATE_NAME` and `PARAM_FILE` environment variables that we created in our Argo Application yaml to point to our templates and param values. We then specify to display our output in JSON. I was seeing some oddities about how output was being handled when specifying YAML for these initial steps. So I recommend sticking with JSON for now. You'll also notice that I supply the appropriate namespace during each step of this `oc` chain. This is because I noticed that if I didn't do this, Argo would just default to trying to apply this to the `default` project. Unsure if this is some logic baked into the system or simply the templates that I'm working with. But for now this is a limitation on this plugin (i.e. only being able to have a single app and it's components be deployed to a single namespace).

- patch : This step is required so that we can deploy Openshift specific components that `kubectl` doesn't know how to deal with (deploymentconfigs, routes, etc.). Here we apply a patch that applies the `argocd.argoproj.io/sync-options": "Validate=false"` annotation to all objects. This may be a bit overkill and may be able to be pruned down at a later point. But for now, this will get us where we need to go. From here, we also ensure that we're using the `--dry-run` flag so that it just spits the output of this command to stdout and doesn't try to apply this right away. This allows us to get the new output with our new annotation applied and allows us to pass this on to the last step in this chain. We also ensure that we're receiving our output in JSON again due to the same issues I mention above.

- create : This last phase outputs the actual list of objects to be applied to our cluster. We again use `--dry-run` so that we just get our output sent to stdout. This time though, we get this output in YAML and we write it out to a file. You may be wondering why I chose to use create here instead of apply. This is actually due to how Argo chooses to do diffing on the objects that it is tracking. When you use apply in your plugin before Argo itself does it's apply, it registers the `last-applied-config` annotation as part of the YAML definition. This then leads to all future syncs reporting as OutOfSync because your previous configuration doesn't have some of the labels that Argo injects. To get around this, we just do a create and use --dry-run so that we get our output, but we see that nothing is actually being created (and thus there is not last-applied-config because nothing has been applied up to that point).

So at this point, we then have our YAML stored in `app.yaml` and we are ready to send this to the next phase to be deployed into our cluster. From here, the hard work is done.

## Generate

The generate command is actually the same `oc create` command that we ran as the last stage of our `init` chain. Having these split like this _might_ be overkill at this point. But to ensure that we have everything in the appropriate format, this will get the job done. This may be a point to revisit later though. So after this command runs, it again outputs our yaml to stdout. However this time it is then captured by Argo and is then applied using `kubectl` (if you are going to allow Argo to auto-sync). Otherwise it will show you the diff that will be applied to the cluster until you manually sync them yourself.

The only other "missing" piece here that hasn't really been addressed are the `TEMPLATE_NAME` and `PARAM_FILE` variables. We use them, but don't really see where they get set.  This comes soon, but just know that it's all just stored in another YAML file.


So now that we understand a bit more about what the above configuration does, we can deploy these changes to the cluster. We can do this by running the below patch in our project.

TODO: Create the appropriate patch 
```
> PATCH=''
#TODO: Add appropriate patch

> oc patch -n argocd configmap argocd-cm -p $PATCH

configmap/argocd-cm patched
```

## Success!(?)

Alright, so where are we now? We've got an ArgoCD server running and we can successfully communicate with it. We've also configured this server to include our `oc` plugin and also know how to use it. At this point, we've officially added a custom plugin to Argo and we'll be able to use it. Now it's time for the payoff -- let's see this thing in action!

# Using our custom plugin

ArgoCD refers to their deployments using a CRD called an Application. This is a bit generic, which is why I've been specifically referring to them as ArgoCD Applications up to the point. As with most systems, you have a few options when deciding on how you would like to deploy these Argo Applications. However because of how we need to pass in certain values (the environment variables I mention above), we can't necessarily use all of them (yet?). If we want to use our `oc-template` plugin, we are limited to just crafting a YAML definition for the Application resource. This is a bit dissapointing because otherwise the ArgoCD client and UI are pretty useful. However it doesn't expose functionality (that I've found) in order to specify that environment variables that we need. So for that reason, we'll need to skip these for now.

## A quick Openshift aside

Ultimately , what we're trying to do here is add the ability to utilize our `oc` client in order to deploy openshift templates into our openshift clusters. There are really three use cases that we have when interacting with our openshift templates, so we'll want to make sure that our plugin can handle them as they're described below:

- Local Templates - These are templates that exist "locally". Meaning that at the time of execution, we will be referring to them on the local filesystem versus some remote endpoint. In terms of Argo, we run across these when our templates exist within a repo that we control.

- Remote Templates - These are templates that do not exist locally within our git repository. Generally we will be referring to a url that points to a repository that we don't necessarily control. You can think of this as using someone elses templates, but then storing your configurations (param files) within your own repo. There are risks here for sure and one could argue that this doesn't necessarily jive completely with a pure gitops strategy. But that's a conversation for another time.

- Cluster Templates - These are templates that are included with the Openshift release. Rather than having to store these in your own repos you can just depend on some of these projects to just be there in your cluster. This allows you to again just worry about your configurations and not necessarily the components themselves. 

## The Application CR YAML

When creating an ArgoCD Application, there are a handful of things that are required by default:

- Name - Just a name that you'll give Argo to refer to your Application
- Source: The place that you point ArgoCD at to resolve your Application. This is a git repository of some sort that either holds your YAML or Helm charts at this point. In our case this will be the repo that is holding our Openshift template (or just parameter files if we happen to be pointing at someone elses template).
- Destination: Cluster information for where you would like to deploy this to. This includes both the cluster definition and the namespace that will be used.

In our case, we're using a custom plugin. So we need to make sure to define this as well. Things that get included here are:
- Name - Name of the plugin that has already been defined and configure. In our case, this will be `oc-template`.
- Env - We can also specify a number of environment details here. In our case, we need to make use of (at least) two environment variables so that our plugin can use them (`TEMPLATE_NAME` and `PARAM_FILE`). You can also define `ARGOCD_APP_NAMESPACE` and `MERGE_TYPE` if necessary.

In the end, our YAML will look something like:

```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-awesome-remote-nexus
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/tylerauerbeck/my-example-argo-deployment.git
    targetRevision: master
    path: nexus

    # plugin specific config
    plugin:
      name: oc-template
      # environment variables passed to the plugin
      env:
        - name: TEMPLATE_NAME
          value: https://raw.githubusercontent.com/redhat-cop/openshift-templates/master/nexus/nexus-deployment-template.yml
        - name: PARAM_FILE
          value: app.params

  # Destination cluster and namespace to deploy the application
  destination:
    server: https://kubernetes.default.svc
    namespace: remote-nexus
```

In our above example, we'll be creating a Nexus application that uses a remote openshift template. We will then apply our Application definition and it will use this remote template along with the params file that is contained within our repo. To deploy this, we'll run the below command and then we should be able to see this both from the CLI as well as in our ArgoCD UI.


```
> oc get Application -n argocd
```

This should then show us something like the following:

```
NAME                      AGE
my-awesome-remote-nexus    1h
```

Since we don't have this set to AutoSync, we'll need to manually sync this for now. This would be another setting that you could provide in your Application definition. If you're interested in other settings that can be set, you can take a look at this example [here](https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/application.yaml). But for now, we can run these manually either through the UI by clicking on our Application and syncing the components or by running the below command with the ArgoCD CLI:

```
> argocd app sync my-awesome-remote-nexus
```

You'll then get a message saying that everything is synced and then we should be able to see the components that have been deployed (again either from the CLI or UI). Once this is completed, we're officially done! We've added our openshift plugin to the system and we've been able to successfully deploy an openshift template from wherever we have our templates stored!


# What did we learn?

During this whole process, I think we've seen the benefit that Argo can provide. We've also seen that it's possible to take a tool that you need and extend ArgoCD so that you can continue to benefit from templates that you may already have.

With that being said, we can see that there are some intracacies involved in getting our tool to spit our YAML exactly the way that that Argo wants it. Realistically this is where you will spend the majority of your time. But, if you happen to be looking specifically for an Openshift templates plugin, you have no worries -- it's now already done for you and you can grab the information used in this blog!

# PS: Some limitations

Currently the plugin defined in this article can only handle a single template per Application CR. This means that for your deployments, you'll need to cobble everything into a larger template containing multiple items. This is definitely something I'm working on as we iterate on this plugin. However the goal of this article was to show how to extend ArgoCD to use a custom plugin, not necessarily to write the most efficient one. I'll be sure to follow up on this as I continue to make improvements.