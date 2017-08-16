# Azure Container Service (ACS) bursting into Container Instances (ACI) 

Microsoft introduced Container Instances that take little time to spin up, are billed per second and one of the standard usage patterns is to use them as a 'spill-over' capacity when horizontally scaling your Kubernetes (k8s) deploymens. 

More info on [Kubernetes](https://kubernetes.io/), [ACS](https://azure.microsoft.com/en-au/services/container-service/), [ACI](https://azure.microsoft.com/en-au/services/container-instances/) and the [k8s-to-ACI connector](https://github.com/Azure/aci-connector-k8s).

This demo will provision a k8s cluster using ACS, enable the ACI connector, deploy a [stress](https://github.com/progrium/docker-stress) docker container and set up autoscaling rules such that k8s will eventually start spilling (deploying pods) to ACI once it's depleted the capacity of its agent nodes

### Getting Started

* make sure you have an active Azure subscription (you can get a trial one [here](https://azure.microsoft.com/en-au/free/))
* use `bash` ([Bash for Windows](https://msdn.microsoft.com/en-au/commandline/wsl/about?f=255&MSPPError=-2147217396) will work too)
* install [Azure cli 2.0](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* install `kubectl` enther [natively](https://kubernetes.io/docs/tasks/tools/install-kubectl/) or by running `az acs kubernetes install-cli` 
* clone or download this repo

### Running

* Move to the directory where you cloned the repo to
* Run `bash ./deploy.sh` and follow the propmps. 
  * You will be asked to enter your subscription id and tenant id. Follow the instructions [here](https://stackoverflow.com/a/44733469) to find out how.
  * If you have set up a service principal already with sufficient privileges (e.g. Owner of / Contributor to the subscription) the script will allow you to use it (you need to know the id and key though), alternatively it will create a new service principal for you.
* Wait (can take up to 10 minutes)
* Using your browser navigate to the [k8s management ui](http://127.0.0.1:8001/ui) and observe how it will deplete the ACS agent node capacity first and then start deploying new pods as ACI instances (use the [Azure Portal](https://portal.azure.com) to observe)
```
You can also run kubectl get deployment and kubectl get pod to observe the behaviour 
```
* Don't forget to tear down the Resource Groups (there'll be two) created by this script

## Built With

* [Visual Studio Code](https://code.visualstudio.com/)
* [Google](https://google.com)
* [Coffee](https://en.wikipedia.org/wiki/Coffee)

## Authors & Collaborators

* **Igor Izotov** - code - [iizotov](https://github.com/iizotov)
* **Michael Friedrich** - collaborator - [fredderf204](https://github.com/fredderf204)
* **Mike Freeman** - collaborator - [mikefreeman27](https://www.linkedin.com/in/mikefreeman27/?ppe=1)
