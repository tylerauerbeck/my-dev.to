<h1> Deprec-oh no: Using Deprek8 and GitHub Actions To Detect Deprecated Kubernetes APIs </h1> 

As of late, deprecated API's have been wreaking havoc on everyones Kubernetes manifests. Why is this happening!? Because the objects that we've come to love and know are moving on to their new homes. And it's not that this happened overnight. Deprecations warnings have been in place for quite a few releases now. We've all just been lazy and thought the day would never come. WELL IT'S HERE!

So maybe this caught up to us this time. But we'll be prepared next time right!? Yeah, I'm sure that's what we all said last time. But what if we could put something in place that makes sure that this doesn't happen? This is where `Deprek8` comes in!

<h1> What is Deprek8? </h1>

<a  target="_blank" href="https://github.com/naquada/deprek8">Deprek8</a> is a set of <a href="https://github.com/open-policy-agent/opa">Open Policy Agent (OPA)</a> policies that allow you to check your repository for usage of deprecated API versions. So with these policies in hand, we now have a way of both providing warnings and errors depending on whether something is in the process of being deprecated or has already been deprecated. But `Deprek8` is just the set of policies that define what to watch for. How do we actually actively use these policies in order to monitor for these deprecations?

There are a number of ways and tools that you can use to do this. But what we'll be looking at today will use the following:

<h2> OPA Deprek8 Policy </h2>

We've mentioned OPA a few times up to this point, but haven't really addressed what it is. They describe themselves as "an open source, general-purpose policy engine that enables unified, context-aware policy enforcement". What this means is that they give you a means of establishing a set of policies and then enforcing those policies based upon a policy file. These policies are defined in a file (or set of files) using the <a target="_blank" href="https://blog.openpolicyagent.org/opas-full-stack-policy-language-caeaadb1e077">Rego query language</a>. In our particular use case, we won't necessarily be relying on the OPA application, but more specifically we'll be relying on this query language to do the heavy lifting.Using Rego, you can check to see whether various manifests match certain criteria and then either warn or error out based on your definition. For example, in Kubernetes 1.16, the Deployment object was no longer able to be served from the extensions/v1beta1 apiVersion. So in our rego file, we could have something that looks like the following:

```
_deny = msg {
  resources := ["Deployment"]
  input.apiVersion == "extensions/v1beta1"
  input.kind == resources[_]
  msg := sprintf("%s/%s: API extensions/v1beta1 for %s is no longer served by default, use apps/v1 instead.", [input.kind, input.metadata.name, input.kind])
}
```

This could then alert us to the fact that we have a deprecated manifest and would print the message:
> Deployment/myDeployment: API extensions/v1beta1 for Deployment is no longer served by default, use apps/v1 instead.

That's great! This is exactly what I was looking for when trying to avoid having old manifests laying around. But these are just the policies themselves. We also need something that will allow us to check these policies and put them into action.

<h2> Conftest </h2>

This is where <a  target="_blank" href="https://github.com/instrumenta/conftest">Conftest</a> comes in! Conftest is just a utility that allows us to put our Rego policies into action against any number of configuration files. According to the repo, conftest currently supports:

```yaml
 - YAML
 - JSON
 - INI
 - TOML
 - HOCON
 - HCL
 - CUE
 - Dockerfile
 - HCL2 (Experimental)
 - EDN
 - VCL
 - XML
```

It has some fairly strict defaults (i.e. expecting policy files to be in certain locations), but all of this can be overridden with the appropriate flags in case you have a layout that you prefer. If you care to know more about those specifics, please consult the documentation found in the repository.

For a quick example on conftest, you can run any policy file you'd like with a command like the following:

```
helm template --set podSecurityPolicy.enabled=true --set server.ingress.enabled=true . | conftest -p mypolicy.rego -
```

What this would do is generate the appropriate output from a helm template and then pipe it directly to the conftest utility. Conftest would then inspect that output against any policies define in the `mypolicy.rego` file and then give any appropriate warnings or errors for objects that matched against those policies. You can of course swap out any templating tooling of your choice in this scenario, or you can feed specific files directly to the conftest tool.

So now we've got the tools we need to both set our policies and then enforce them against our configuration files. But how do we tie these two things together? Better yet! How do we automate this process so that we can continuously monitor our codebase to make sure that we never fall behind the deprecation line again? 

## GitHub Actions

Enter -- GitHub Actions. There are many ways and tools that will allow us to run checks against our code. By adding similar steps to your CI tooling (Jenkins, Tekton, etc.) you will be able to accomplish the same goal. However in this very basic use case, I just wanted to see something work and this happened to be available right where my code was living.

So what does GitHub Actions buy us? It allows us to automate our entire workflow so that we don't have to sit in front of our keyboards and hack all of this together. With Actions, we're able to string together any number of steps into a workflow  (or multiple workflows). This can be done either by rolling your own actions if you're doing something custom or, in most cases, using something that already exists in the <a target="_blank" href="https://github.com/marketplace?type=actions">marketplace</a>. Luckily for us, the things we need to do are already provided by actions that have been created by others, so we can lean on the communities expertise to pull our workflow together.

As we've seen in each of the individual steps above, the workflow here looks something like the following:
1. Retrieve the Deprek8 policy that we need and store it somewhere for later use.
2. Run conftest against the appropriate files/charts with the policy file that we grabbed in step 1.

So what does this boil down to? Well all we really need to do is use `curl` to pull our policy file and then run it through conftest after pointing to our code. What this leads us to are the following actions: <a target="_blank" href="https://github.com/marketplace/actions/github-action-for-curl">curl</a> and <a target="_blank" href="https://github.com/instrumenta/conftest-action">conftest</a>. Since these actions already exist, we don't need to write any custom code! And as I'm sure you can tell by the names, they just allow us to run the associated commands without having to do any custom work to pre-process anything or pull down any binaries.


So now that we've got the actions we need to use, how do we pull them together? Well this is where our workflow comes into play. While Actions are the pieces of code that get things done — they're useless without a way of stringing them together so that they can be triggered by some event. A GitHub Action workflow will look something like the following:

```yaml
name: Some Awesome Workflow Name
on: An Event That Triggers Our Workflow
jobs:
  awesome-job-name:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master
      - name: awesome-step-name
        uses: someorg/someaction@version
        with:
          args: some args that I might pass to someaction
```

As you can see, we have a workflow that has multiple steps, can be triggered by a specific GitHub event and can be passed a set of parameters if that is applicable to that specific action. The above example is _extremly basic_. But luckily for us, the workflow we're trying to put together is equally as simple. This shouldn't be taken as a comprehensive example of a GitHub action as there are many more complicated (and elegant) things you can do.  If you're interested in learning more about GitHub Actions, you can take a look at the documention here[linky linky].

As for our example, we now have an idea of what a workflow looks like and we know what actions we're interested in using. So let's take a run at plugging the two together now. If we remember our use case, we want to make sure that anytime our code is updated that we check to make sure that we're not using any deprecated APIs. So let's first rig up our workflow with some names and the events that we want to trigger off of.

```yaml
name: API Deprecation Check
on: pull_request, push
jobs:
  deprecation-check:
```

As you can see above, we give our workflow and job a useful name that will help us identify it (and what it does). We then tell it that we want to trigger these actions based off of both a `pull_request` and any `push` that happens to this repository. This is because these are the two main events that will occur that allow us to get new code into our repositories. We do this by utilizing the `on` keyword.

```yaml
name: API Deprecation Check
on: pull_request, push
jobs:
  deprecation-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master
```

The next thing that we'll want to add is where we want these actions to run and how  this action can get our code. We can tell our action where to run by using the `runs-on` keyword. We have a few options here: Windows, Mac and Ubuntu. In most cases, using Ubuntu is fine as you'll frequently rely on actions that run inside of their own container (versus running on the base OS that you define here). It's also very important to understand that an action does not check out your code by default. When you need to do something that interacts with your code, you need to make sure to use the action `actions/checkout`. Once this is included, your code will be available within your action and you can pass that through to the next step in your workflow.

```yaml
name: API Deprecation Check
on: pull_request, push
name: API Deprecation Check
jobs:
  deprecation-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master
      - name: curl
        uses: wei/curl@master
        with:
          args: https://raw.githubusercontent.com/naquada/deprek8/master/policy/deprek8.rego > /github/home/deprek8.rego
```

So now that we've got our code checked out, we can start preparing to do something with it. Like we mentioned before — before we can check our code for deprecations, we first need the file that contains the policies that we'll be checking for. All we need to do here is retrieve that file using the `curl` action that we looked at before. This is a fairly straightforward action in that it just accepts whatever parameters that you would normally pass in to the curl command. If we were doing something more complication, this is where we could pass in things like specific HTTP actions, headers, etc. However in this case, we're just trying to retrieve a file, so all we need to pass to our action is th URL that we want to retrieve (in this case one that contains our raw policy file) and then we tell it where we would like to write that file. In our case we're going to have it write to `/github/home` ? Why are we writing this file here? Because this is a filesystem that persists between steps and will allow us to use our policy file within this next step.

```yaml
name: API Deprecation Check
on: pull_request, push
jobs:
  deprecation-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master
      - name: curl
        uses: wei/curl@master
        with:
          args: https://raw.githubusercontent.com/naquada/deprek8/master/policy/deprek8.rego > /github/home/deprek8.rego
      - name: Check helm chart for deprecation
        uses: instrumenta/conftest-action/helm@master
        with:
          chart: nginx-test
          policy: /github/home/deprek8.rego
```

Now that we have our policy file, it's just a matter of running it against our code via `conftest`. Similar to the `curl` action, the `conftest` action just expects a series of parameters to understand how it should run against our code. In the above example, we're going to be running against a helm chart. However, it is also possible to just run against a specific file (or set of files) by changing the `uses` value to `instrumenta/conftest-action@master`. In our case though, we just point to the path that our chart sits at in our repository and then we provide the path to our policy file (which we specified in the previous step). Once we have all of this together, we now have a complete workflow. But what does this actually look like (assuming that we've got some bad code in our helm chart)? For this, let's take a look at our example repository, which can be found <a target="_blank" href="https://github.com/tylerauerbeck/deprek8-example">here</a>.

If you look at our nginx helm chart, you'll notice that one of the templates is a statefulset (which you can see <a target="_blank" href="https://raw.githubusercontent.com/tylerauerbeck/deprek8-example/master/nginx-test/templates/statefulset.yaml">here</a>). You may also notice that the apiVersion that the StatefulSet is using is `apps/v1beta1`. This API was deprecated in Kubernetes 1.16 and is now hosted in `apps/v1`. So when our GitHub Actions workflow runs, it should detect this issue and then serve us an error that looks like the following:

```
FAIL - StatefulSetf/web: API apps/v1beta1 is no longer served by default, use apps/v1 instead.
Error: plugin "conftest" exited with error
##[error]Docker run failed with exit code 1
```

As you can see, the action itself lets us know that there is something wrong and then fails the rest of the action. You can see the full workflow <a target="_blank" href="https://github.com/tylerauerbeck/deprek8-example/runs/426774566?check_suite_focus=true">here</a> if you are interested.

## Wrap-Up

Now with all of this in place, we have a workflow that will save us some heartache in the future by alerting us to any deprecated API's that we try to slip into our codebase. To be clear, this is an **alerting** mechanism. This isn't going to prevent you from merging bad code into your codebase. But as long as you pay attention to your actions, you should be completely aware prior to (or even just after) merging problematic code.

So where do we go from here? Well there are a few things to keep in mind. Currently Deprek8 is up to date as of Kubernetes 1.16. So if you're interested in more recent versions than this, I'm sure Deprek8 would be happy to accept your PR <a  target="_blank" href="https://github.com/naquada/deprek8">here</a>. The other shortcoming of this method is that the `conftest` github actions are currently a bit limited in that they only allow you to point at specific files or a single chart at a time. What if we have multiple directories of manifests that we just want to point at? Or maybe we have multiple charts inside of our repository! Well currently the only way to get around that now is to either list out every single file that you're interested in or in the case of having multiple charts, you can have multiple steps inside of your workflow. There are other scenarios of course that would become problematic (i.e. other templating engines that would require some custom logic to pair the parameters and template files together). But a simple workaround for that would just be to have a step in your workflow that pulled down conftest and then had a tiny inline script that would loop through some of this. I'm sure we could all come up more elegant solutions for this (and of course if you do — I'm sure these projects would be more than happy to take a look at your PR ).

But regardless of how we get there, we now have a mechanism in place that allows us to sleep a bit easier when it comes checking in our code! Hopefully this will help you on your way to building even more robust workflows to protect your code.
