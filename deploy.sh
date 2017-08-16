#!/bin/bash
: ''

echo "checking if az, kubectl, awk, sleep and xargs are present"
command -v az >/dev/null 2>&1 || { echo >&2 "I require az but it's not installed.  Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo >&2 "I require kubectl but it's not installed.  Aborting."; exit 1; }
command -v awk >/dev/null 2>&1 || { echo >&2 "I require awk but it's not installed.  Aborting."; exit 1; }
command -v xargs >/dev/null 2>&1 || { echo >&2 "I require xargs but it's not installed.  Aborting."; exit 1; }
command -v sleep >/dev/null 2>&1 || { echo >&2 "I require sleep but it's not installed.  Aborting."; exit 1; }

SEED=`echo ${RANDOM} | tr '[0-9]' '[a-zA-Z]'`
while read -p 'Please enter azure subscription id: ' SUBSCRIPTION_ID && [[ -z "$SUBSCRIPTION_ID" ]] ; do echo -n; done
while read -p 'Please enter azure tenant id: ' TENANT_ID && [[ -z "$TENANT_ID" ]] ; do echo -n; done

read -p 'If you pre-created a service principal, enter the client ID now, leave blank to create: ' CLIENT_ID
read -p 'If you pre-created a service principal, enter the client KEY now, leave blank to create: ' CLIENT_KEY

RESOURCE_GROUP_DEFAULT="ACS-Training-"${SEED}

read -p "Please enter resource group [${RESOURCE_GROUP_DEFAULT}]: " RESOURCE_GROUP
RESOURCE_GROUP="${RESOURCE_GROUP:-$RESOURCE_GROUP_DEFAULT}"

LOCATION_DEFAULT="westcentralus"
read -p "Please enter deployment region [${LOCATION_DEFAULT}]: " LOCATION
LOCATION="${LOCATION:-$LOCATION_DEFAULT}"

IMAGE_DEFAULT="progrium/stress"
read -p "Please enter docker image path [${IMAGE_DEFAULT}]: " IMAGE
IMAGE="${IMAGE:-$IMAGE_DEFAULT}"

AGENT_VM_DEFAULT="Standard_DS2_v2"
read -p "Please enter k8s agent vm size [${AGENT_VM_DEFAULT}]: " AGENT_VM
AGENT_VM="${AGENT_VM:-$AGENT_VM_DEFAULT}"

AGENT_COUNT_DEFAULT="1"
read -p "Please enter how many k8s agent nodes you'd like [${AGENT_COUNT_DEFAULT}]: " AGENT_COUNT
AGENT_COUNT="${AGENT_COUNT:-$AGENT_COUNT_DEFAULT}"

ACS_NAME="acs"${SEED}
DNS_NAME="acs"${SEED}
MASTER_COUNT=1

if [ -z "$CLIENT_ID" ]
then
	az login
	echo "creating a new service principal as owner of subscription ${SUBSCRIPTION_ID}..."
	TMP=$(az ad sp create-for-rbac --role="Owner" --scopes="/subscriptions/${SUBSCRIPTION_ID}" --output tsv)
	CLIENT_ID=$(echo $TMP | awk '{print $1}' | xargs) #xargs trims spaces
	CLIENT_KEY=$(echo $TMP | awk '{print $4}' | xargs) #xargs trims spaces
	echo "created new service principal, id: ${CLIENT_ID}, key: ${CLIENT_KEY}"
else 
	echo "Attempting login..."
	az login -u "${CLIENT_ID}" -p "${CLIENT_KEY}" -t "${TENANT_ID}"
fi

az account set --subscription "${SUBSCRIPTION_ID}"
az configure --defaults location="${LOCATION}"
echo "Creating Resource Group..."
until az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}"; do
	echo "sleeping for 5 seconds and repeating..."
	sleep 5
done

echo "Creating ACS k8s instance..."
until az acs create --name "${ACS_NAME}" --dns-prefix "${DNS_NAME}" \
	--resource-group "${RESOURCE_GROUP}" --admin-username "${DNS_NAME}" \
	--generate-ssh-keys --orchestrator-type kubernetes \
	--master-count "${MASTER_COUNT}" --agent-count "${AGENT_COUNT}" \
	--agent-vm-size "${AGENT_VM}" --service-principal "${CLIENT_ID}" \
	--client-secret "${CLIENT_KEY}"; do
	echo "sleeping for 5 seconds and repeating..."
	sleep 5
done

echo "Getting credentials, repeating until the ACS instance is fully up..."
until az acs kubernetes get-credentials --resource-group="${RESOURCE_GROUP}" --name="${ACS_NAME}"; do 
	echo "sleeping for 5 seconds and repeating..."
	sleep 5
done

echo 'Preparing yaml for k8s'
eval "cat <<EOF
$(<./aci-connector-template.yaml)
EOF
" 2> /dev/null > ./aci-connector.yaml

eval "cat <<EOF
$(<./deploy-stress-template.yaml)
EOF
" 2> /dev/null > ./deploy-stress.yaml

echo 'Deploying ACI connector'
until kubectl create -f ./aci-connector.yaml; do 
	echo "sleeping for 5 seconds and repeating..."
	sleep 5
done

echo "Deploying ${IMAGE}"
kubectl create -f ./deploy-stress.yaml

echo 'Deploying horizontal autoscaler (50% CPU target, between 1 to 10 pods)'
until kubectl autoscale deployment stress --cpu-percent=50 --min=1 --max=10; do 
	echo "sleeping for 5 seconds and repeating..."
	sleep 5
done

echo 'Warpipng time and enabling tunnel to k8s management ui'
echo 'To re-enable, run'
echo "az acs kubernetes browse --resource-group="${RESOURCE_GROUP}" --name="${ACS_NAME}"
"
echo "That's all folks, don't dorget to clean up after you're finished playing"

until az acs kubernetes browse --resource-group="${RESOURCE_GROUP}" --name="${ACS_NAME}"; do
	echo "sleeping for 5 seconds and repeating..."
	sleep 5
done

exit 0
