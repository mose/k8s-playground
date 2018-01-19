Kubeless playground
========================

Let's try to do something like https://serverless.com/blog/serverless-github-webhook-slack/ as an exercise to understand how kubeless works.

Setup a sandbox
-------------------

So I start by launching a kubernetes sandbox from https://bitnami.com/stack/kubernetes-sandbox

For my comfort I want to access the Kubernetes API from home, so I had to tweak a little:

First find the token, by getting on the server, which is configured to trust any local user to be cluster admin with kubectl
```
TOKEN=$(kubectl get secrets -n kube-system | grep default-token | awk '{print $2}')
kubectl describe secret $TOKEN -n kube-system | grep token:
```
Now give that default user the cluster admin role
```
kubectl create clusterrolebinding admin-role --clusterrole=cluster-admin --serviceaccount=kube-system:default
```

Then create a local `~/.kube/config-sandbox`
```
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://<ip>:6443
  name: default
contexts:
- context:
    cluster: default
    namespace: default
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    token: <xxx>
```
where
- `<ip>` is the ip of the server
- `<xxx>` is the `default-token-xxxx` in the secrets

Now I can, locally
```
export KUBECONFIG=$KUBECONFIG:$HOME/.kube/config-sandbox
kubectl get pods --all-namespaces
```

I'm a kubenoob so I have no idea if this is the right way to do things, but well, this worked for me.


Install Kubeless
-------------------

Instructions from https://github.com/kubeless/kubeless#installation are really straightforward, but the links are not updated with the most recent version. So I adjusted with the `v0.3.4` version.

- downlaoded kubeless and put it in my `/usr/local/bin`
- created kubeless namespace and pods with the RBAC-enabled manifest (as kubernetes-sandbox is RBAC-enabled)


Prepare Slack
--------------

So I created a new channel on one of my slack group where I'm admin. I added an app of type `Incoming Webhook` so it created an url I could use to post to. That operation is pretty well described on https://serverless.com/blog/serverless-github-webhook-slack/


Prepare a function
-------------------

Because I'm a ruby geek I wanna try that flavor. So I created a test file that just outputs the request just for testing.

    $ kubeless function deploy stargazers --runtime ruby2.4 --from-file ./test.rb --handler test.handler --trigger-http

Now that function shows

```
$ kubeless function ls stargazers
NAME        NAMESPACE HANDLER       RUNTIME TYPE  TOPIC DEPENDENCIES  STATUS   
stargazers  default   test.handler  ruby2.4 HTTP                      1/1 READY
```

Great. Updating the function is pretty simple, so I went directly with a real script
```
$ kubeless function update stargazers --from-file stargazers.rb --handler stargazers.handler
$ kubeless function update stargazers --env "WEBHOOK_URL=https://hooks.slack.com/services/blahblah"
$ kubeless function describe stargazers
Name:         stargazers                                                                      
Namespace:    default                                                                         
Handler:      stargazers.handler                                                       
Runtime:      ruby2.4                                                                         
Type:         HTTP                                                                            
Topic:                                                                                        
Label:        {"created-by":"kubeless"}                                                       
Envvar:       [{"name":"WEBHOOK_URL","value":"https://hooks.slack.com/services/T02LCNBF8/B8...
Memory:       0                                                                               
Dependencies:                                                                                 
```

The webhook url obviously is the one I got from slack, with random alphanum instead of blahblah.

Now, to access the function through Ingress there is this magnificent doc on https://github.com/kubeless/kubeless/blob/master/docs/routing.md so a simple command did the job
```
$ kubeless route create stargazers --function stargazers
$ kubeless route list
NAME        NAMESPACE HOST                              PATH  SERVICE NAME  SERVICE PORT
stargazers  default   stargazers.<ip>.nip.io            /     stargazers    8080
```

(where `<ip>` is the IP of my kubernetes sandbox VM on GCE)

So now I can curl and test with a fake payload:
```
$ curl --data @payload.json stargazers.<ip>.nip.io --header "Content-Type:application/json"
```

The hostname will do the job in Ingress to lead it to the right function, visibly.

After some time debugging my ruby code, I had the message displayed in Slack!

Note, for debugging I had a log tail open in a console, restarted each time I updated the code:
```
# edit the code
$ kubeless function update stargazers --from-file stargazers.rb
$ kubeless function logs stargazers -f | grep -v healthz
```

Very convenient.

Setup the github webhooks
------------------------------

So now that we have a reliable endpoint, the last stage is to configure projects in github with webhooks, using the `http://stargazers.<ip>.nip.io` endpoint, selecting only the `watch` individual event (the last one in the list). Many projects can be configured to send webhooks to that same endpoint now.

What next?
--------------

- That would be good to include in the ruby code some secret token verification to avoid mis-use.
- the ruby code right now is very basic, it would be nice to have more error handling
- there should be some way to write a test for the function somehow, however basic it is
