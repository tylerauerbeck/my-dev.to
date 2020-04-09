# Kubernetes Native Configuration For Sonatype Nexus With The Nexus Kubernetes Openshift Plugin 

Over the past two years, Sonatype's Nexus has been a common tool that my team has brought along on many engagements. For those unfamiliar with [Nexus](https://www.sonatype.com/product-nexus-repository), it is an artifact repository that supports almost any popular format you use ona daily basis. In our case, this is most commonly used for mirroring maven and npm repositories as well as storing the resulting artifacts from our builds.

Since most of our work takes place on OpenShift, it's always made the most sense for us to run Nexus on the cluster alongside the rest of our applications. And that's always worked out great! This has made a lot of the integration work fairly simple since everything is running in the same place. However one thing that had always made automation a bit of a pain had been steps that needed to be done as post-configuration steps (resetting the admin password, configuring additional repositories, etc.). The experience that I had been looking for was that I declare how I want my instance of Nexus to look and then a single set of automation took care of the rest. But with the current setup, we were having to launch our instance of nexus and then have a wait step (i.e. sit and do nothing for X number of seconds) between the deployment and configuration of anything. This always gave us varying levels of success. Sometimes the wait period wasn't long enough and Nexus wasn't ready to receive API requests. Other times things would go wrong with the deployment (ex: the image registry turned into a ghost 👻) and there would be no Nexus to receive our requests. This wasn't a Nexus only set of issues we were dealing with, but we certainly talked frequently enough about how it would be great to have a more enjoyable deployment story.

This is where my colleague [Deven Phillips](https://twitter.com/infosec812) comes in. In the latter part of last year, he was able to put these plans into action and built a [plugin](https://github.com/sonatype-nexus-community/nexus-kubernetes-openshift) for Nexus that allowed us to configure our Nexus instances in a more declarative manner. Instead of having to wait for the Nexus insance to come online, we're now able to declare our configurations (admin passwords, repositories, etc.) as part of our deployment using Secrets and ConfigMaps. Now we can create these configurations alongside the rest of our code and Nexus will ensure that everything is configured as it comes online. In my recent experience utilizing this plugin, this is much less prone to error and doesn't require any extra automation outside of making sure that our manifests for these objects get created.

So if you're anything like me, you may have gotten pretty excited when you heard about this (no more parsing error logs to see what went wrong with my deployment!), but it's actually way more exciting to see in action. So if that's more your speed.. then you've come to the right place.

![lets-do-this](https://media.makeameme.org/created/lets-do-this-5b4f67.jpg)

## Getting Started

For our deployment strategy, we'll lean on the Nexus Helm chart that lives [here](https://github.com/Oteemo/charts/tree/sonatype-nexus-1.27.1) and deploy everything using Helm (specifically v3.1.1 as of the time of this writing). In this set of examples, we'll be using version 1.27.1 of that chart. Depending on how you like to interact with Helm you can either clone the repository down locally or you can run the following

```sh
helm repo add oteemo https://oteemo.github.io/charts 
```

At this point, we're now set up to interact with the appropriate charts. So how do we get this thing running?

### Two approaches

Along with this chart, we also need to make sure that the plugin is added to our Nexus image so that it knows how to create our configurations. In order to do this, we have two options.

1. The first option is to have the plugin brought in as part of an initContainer. This is _less_ persistent, but it also doesn't add a lot of overhead either as it just curls the binary down and then it spins up the Nexus container as normal.

2. THe second option is to have a custom build of the Nexus image that includes our plugin. This essentially does the same thing as our initContainer does (curling down the plugin), but you initially only need to this once (and then again anytime there are updates needed for the Nexus container image or the plugin is updated).

I personally like option one because it's less maintenance that I have to worry about. While it's true that there is a small amount of overhead added to each time the Nexus container needs to spin up, it's really a negligable(?) amount of time compared to the long term maintenance required from now having to make sure that your custom build stays up to date with both the plugin and the base image itself.

With that being said, both options will take you to the same place. What we'll see below though will speak directly to option one.

### Let's override some chart values

Now that we know how we're going to move forward, let's go ahead and override the values that we need to replace in our chart. If you're interested in seeing what the default values for this chart are you, you can take a peek [here](https://github.com/oteemo/charts/tree/sonatype-nexus-1.27.1).

If you're unfamiliar with how Helm works; most charts provide a file called `values.yaml` that provides the default values for a chart. If you're happy with all of the defaults, then no worries! You can just go ahead and run `helm install...` without pointing to a local values file and it will begin installing the chart. However in most cases, there's likely something that you want to replace with your own set of values. In that case, you can create your own values file (ex: `my-custom-values.yaml`) and then tell your chart to use the values in that file by running `helm install -f my-custom-values.yaml ...`. This would overlay your values over the default values and then begin installing the chart. For any values that you didn't provide anything for, it would continue to utilize the values found in the default `values.yaml` file.

So with that bit of Helm knowledge in mind, what values do we actually need to override for the Nexus chart? I'll first provide you with my entire values file (for those of you who just want to move on with getting this deployed). A majority of this has nothing to do with including the plugin itself and has more to do with running on OpenShift (specifically `securityContextEnabled: false` and the values underneath `route:`). The rest is likely to work just fine on vanilla Kubernetes. What you'll want to make note of is everything underneath `deployment:`. Take a look at this as you're passing by the following YAML and then we'll talk about what all of that means.

```yaml
nexus:
  imageTag: 3.19.1
  securityContextEnabled: false
  service:
    type: ClusterIP
  podAnnotations: {}


route:
  enabled: true
  name: nexus
  portName: nexus-service
  path: '""'

nexusProxy:
  enabled: false

persistence:
  storageSize: 5Gi

serviceAccount:
  name: nexus
  annotations: {}

deployment:
  annotations: {}
  initContainers:
    - name: k8s-plugin-puller
      image: curlimages/curl:latest
      imagePullPolicy: Always
      command: ['sh','-c']
      args: ['curl -o /k8s-plugin/nexus-openshift-plugin.jar https://github.com/sonatype-nexus-community/nexus-kubernetes-openshift-releases/download/v0.2.8/nexus-openshift-plugin-0.2.8.jar']
      volumeMounts:
        - name: k8s-plugin
          mountPath: /k8s-plugin
  additionalVolumes:
    - name: k8s-plugin
      emptyDir: {}
  additionalVolumeMounts:
    - mountPath: /opt/sonatype/nexus/deploy/nexus-openshift-plugin.jar
      name: k8s-plugin
      subPath: nexus-openshift-plugin.jar

serviceAccount:
  create: false
  name: nexus
  annotations: {}

secret:
  enabled: false
  mountPath:
  readOnly:
  data:

service:
  enabled: true
  name: nexus-service
  labels: {}
  annotations: {}
  portName: nexus-service
  port: 8081
  targetPort: 8081
  ports: []
```

### Retrieving our plugin

Now as I mentioned, you want to take note of this section of the above values file:

```yaml
deployment:
  annotations: {}
  initContainers:
    - name: k8s-plugin-puller
      image: curlimages/curl:latest
      imagePullPolicy: Always
      command: ['sh','-c']
      args: ['curl -o /k8s-plugin/nexus-openshift-plugin.jar https://github.com/sonatype-nexus-community/nexus-kubernetes-openshift-releases/download/v0.2.8/nexus-openshift-plugin-0.2.8.jar']
      volumeMounts:
        - name: k8s-plugin
          mountPath: /k8s-plugin
  additionalVolumes:
    - name: k8s-plugin
      emptyDir: {}
  additionalVolumeMounts:
    - mountPath: /opt/sonatype/nexus/deploy/nexus-openshift-plugin.jar
      name: k8s-plugin
      subPath: nexus-openshift-plugin.jar
```

The first thing to note is `initContainers`. In this section we can list any number of initContainers that we would like to run prior to Nexus coming online. In our case, we only need one in order to curl our plugin. Since there's already a commonly used container image, we'll lean on this (`curlimages/curl:latest`) and give it a name (`k8s-plugin-puller`). From there, we can tell it what we want it to do when it runs.  In our case, we're telling it to retrieve our plugin from the releases page on GitHub repository and then save it to a path that we've given it (`/k8s-plugin/nexus-openshift-plugin.jar`). We also want to make sure to tell it to mount our volume (`k8s-plugin`) to a path that we expect it to be at (so that we actually have somewhere to save our plugin). We can change the name of this path and volume to anything we'd like, but it's important that wherever it is, we're saving our plugin there. Otherwise it won't actually get persisted for the Nexus container to use.

Now that we have our initContainer configured, we also need to make sure that the volume that we'll be utilizing inside of that container will exist. So under `additionalVolumes`, we can just create a simple [emptyDir]() volume so that we have somewhere to write this to. We give it a name that we expect to use and then we're in good shape.

The final step is to tell the `deployment` where to mount our volume. In the case of Nexus, it expects plugins to be under `/opt/sonatype/nexus/deploy`. So in our case, we tell the deployment to take  the `k8s-plugin` volume that we created (which will contain our plugin named `nexus-openshift-plugin.jar`) and mount it to this location. We also then lean on the [subPath]() key to tell it to mount just that file inside of that volume to this location. With all of this in place now, the Nexus container will now boot with our plugin already enabled.

## Nexus: Up and Running

So now that we've got our values file in good shape, we can actually kick this thing off right? Well..almost! The plugin expects that the [ServiceAccount]() that it is running as has at least enough permissions to read `Secrets` and `ConfigMaps`. By default, this isn't the case. So the first thing we'll want to do is create the `ServiceAccount` that we want to run Nexus as and then also apply the appropriate [RoleBinding]() to that `ServiceAccount`. To do that, you can run the following:

```sh
> oc create serviceaccount nexus
> oc create rolebinding nexus-admin --clusterrole=admin --serviceaccount=nexus 
```

🚨 **Note:** One thing to keep in mind here is that you don't have to/shouldn't grant your ServiceAccount admin within your project. This is being done for ease of use and because I don't necessarily have requirements for a RoleBinding at this point. You can custom create a Role/RoleBinding for your purposes and then apply it in a similar manner to fit your use. 🚨

After this, you should be able to deploy the chart as you normally would:

```sh
> helm install nexus oteemo/sonatype-nexus --version 1.27.1
```

Once this has been run, you should see something that looks like:

```sh
NAME                                    READY   STATUS    RESTARTS   AGE
nexus-sonatype-nexus-5b4dcccfb5-h5rzv   1/1     Running   0          2d2h
```

As long as you see a running pod, you'll be in good shape! However, this doesn't necessarily mean that our plugin is working as expected. If you'd like to confirm that the plugin is in good shape (or if after the following steps you don't see your repositories getting created) you can check the logs for something that look like:

```log
2020-04-05 16:33:13,204+0000 WARN  [FelixStartLevel] *SYSTEM com.redhat.labs.nexus.openshift.OpenShiftConfigPlugin - An
 error occurred while retrieving Secrets from OpenShift
io.kubernetes.client.ApiException: Forbidden
<...SNIP..>
2020-04-05 16:33:13,208+0000 ERROR [FelixStartLevel] *SYSTEM com.redhat.labs.nexus.openshift.OpenShiftConfigPlugin - Error reading ConfigMaps
io.kubernetes.client.ApiException: Forbidden
<...SNIP...>
```

This indicates that something has gone wrong with our RBAC and our ServiceAccount. So if you see these errors, just go back and make sure that your ServiceAccount has appropriate permissions to read these two types of objects.

But, 🤞 fingers crossed 🤞, you won't see any of that and you'll be ready to ready to start adding our desired repositories. Currently the Nexus chart doesn't provide a way to specify these ConfigMaps, so we'll need to do this manually for now. I'll also be sure to link to a list of issues that I've opened for better integration with our plugin at the end of this blog.

### Declarative Nexus Configuration: Setting up proxied Maven repositories and repository groups

So the first thing to do is realize that Nexus supports a number of different types of repositories, each with their own sets of requirements. So if you're interested in a specific type of repository, please take a look [here]() which will show a ton of examples of how to get yourself set up. For our example here, we'll take a look at the use case that I was working with; configuring all of the Red Hat Maven repositories.

In this instance, this includes creating a proxy for the following:

- https://repository.jboss.org/nexus/content/groups/public/
- https://maven.repository.redhat.com/ga/
- https://maven.repository.redhat.com/earlyaccess/all/

Then once we have these repositories created, we'll add them all to a single group called redhat-public. To get started here, we'll start with the repositories themselves. What we'll need to do is create a set of ConfigMaps that looks like

```yaml
apiVersion: v1
data:
  recipe: 'MavenProxy'
  remoteUrl: '<url-for-repository-proxy>'
  blobStoreName: 'default'
  strictContentTypeValidation: 'true'
  versionPolicy: 'RELEASE'
  layoutPolicy: 'STRICT'
kind: ConfigMap
metadata:
  name: <name-of-repository>
  labels:
    nexus-type: repository
```

So for example with `https://repository.jboss.org/nexus/content/groups/public/`, it would look something like:

```yaml
apiVersion: v1
data:
  recipe: 'MavenProxy'
  remoteUrl: 'https://repository.jboss.org/nexus/content/groups/public/'
  blobStoreName: 'default'
  strictContentTypeValidation: 'true'
  versionPolicy: 'RELEASE'
  layoutPolicy: 'STRICT'
kind: ConfigMap
metadata:
  name: jboss-public
  labels:
    nexus-type: repository
```

The name itself doesn't actually matter, just call it anything that makes sense to your scenario. As long as the Url is valid, you should be in good shape. Once you've done this, you can go ahead and do the same for the additional two we have listed above. Once you've got these three manifests pulled together we can go ahead and apply them.

```sh
> oc apply -f jboss-public.yaml
> oc apply -f redhat-ga.yaml
> oc apply -f redhat-earlyaccess.yaml
```

Afterwards, we can confirm that the `ConfigMaps` themselves were created and then we can check Nexus to see if our repository was created. To check for our `ConfigMaps`, we can run the following:

```sh
> oc get cm -n my-nexus-project

NAME           DATA   AGE
jboss-public   6      3d12h
redhat-ga      6      3d12h
redhat-earlyaccess 6  3d12h
```
Then inside of Nexus, we can login using our admin credentials (by default: admin\admin123) to validate that our repository now exists. 

TODO: Get screenshot

Great! Now we've got Nexus running and all of our repositories are being proxied. Now let's get them grouped together so that we can refer to them by one collective name. Similar to how we created our repositories in the first place, we'll just create another `ConfigMap` for our `MavenGroup`.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redhat-public
  labels:
    nexus-type: repository
data:
  recipe: MavenGroup
  members: jboss-public,redhat-ga,redhat-earlyaccess
  blobStoreName: default
```

As you'll notice, this is just another `ConfigMap`. However, since it's a different type of Nexus object it's expecting different values than the repositories we created. This is just a reminder that you should consult the examples for the type of object you're looking to create! After we've created this file, we can go ahead and apply it in a similar manner to our repositories

```sh
> oc apply -f redhat-public.yaml
```

Which should result in something that looks like this from a `ConfigMap` perspective.

```sh
> oc get cm -n my-nexus-project

NAME           DATA   AGE
jboss-public   6      3d12h
redhat-ga      6      3d12h
redhat-earlyaccess 6  3d12h
redhat-public  6      3d12h
```

Once it is created, we should then be able to confirm this via the Nexus interface:

TODO: Get Screenshot

## Wrapping Things Up

![spoken](https://i.imgflip.com/3sdxv6.jpg)

And just like that -- with minimal configuration we are now able to deploy a Nexus instance that allows us to declaratively configure the repositories that we're looking to use. No more crossing our fingers and hoping that the wait time is going to work! We can just declare these configurations with the rest of our code and Nexus will pick them up as soon as they're created! If you're interested in taking a closer look at this plugin or chart, please check out the following links and contribute!

- [https://github.com/oteemo/charts](https://github.com/oteemo/charts)
- [https://github.com/sonatype-nexus-community/nexus-kubernetes-openshift](https://github.com/sonatype-nexus-community/nexus-kubernetes-openshift)

# Appendix: Open Issues List

Now as you saw, some of these steps have to be done seperate from the Helm chart at this point. This _should_ hopefully only be a short-term issue as I've opened the following issues with the upstream chart:

Ideally these can be fixed in the near future and by the time you get to them they'll already be closed! However, if not.. please feel free to get involved and contribute some fixes for these!

- [Add ConfigMaps as part of Helm Chart](https://github.com/Oteemo/charts/issues/79)
- [Add Custom Role and RoleBinding as part of Helm Chart](https://github.com/Oteemo/charts/issues/75)
- [Create ServiceAccount with desired name](https://github.com/Oteemo/charts/issues/74)

As mentioned previously in the article, this plugin also allows you to configure the admin password via a `Secret`. However in recent versions of Nexus (> 3.19.X), Nexus can automatically generate a password for you. This has broken this functionality and is something that is currently being worked on. If you have any ideas in this area, I'm sure the creator would love some input and any contributions. An open issue for this can be found [here](https://github.com/sonatype-nexus-community/nexus-kubernetes-openshift/issues/46).