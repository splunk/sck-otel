# JWT Webhook Integration Tests Environment Setup

## Prerequsite
* Python version must be > 3.x
* Kubectl = v1.15.2
* Minikube = v1.20.0
* Helm = 3.3.x
* libseccomp2 and cri-o (optional)
## Setup local environment
#### Start Minikube  
    `minikube start --driver=docker --container-runtime=docker --cpus 3 --memory 8192 --kubernetes-version=v1.15.2 --no-vtx-check`  
    or  
    `minikube start --driver=docker --container-runtime=cri-o --cpus 3 --memory 8192 --kubernetes-version=v1.15.2 --no-vtx-check`  
    or  
    `minikube start --driver=docker --container-runtime=containerd --cpus 3 --memory 8192 --kubernetes-version=v1.15.2 --no-vtx-check`
#### Install Splunk  
    1. Install Splunk on minikube
        # Use .circleci/k8s-splunk.yml file to deploy splunk on minikube 
        kubectl apply -f .circleci/k8s-splunk.yml
        export CI_SPLUNK_HOST=$(kubectl get pod splunk --template={{.status.podIP}})
        # Setup Indexes
        curl -k -u admin:helloworld https://$CI_SPLUNK_HOST:8089/services/data/indexes -d name=circleci_events -d datatype=event
        curl -k -u admin:helloworld https://$CI_SPLUNK_HOST:8089/services/data/indexes -d name=ns-anno -d datatype=event
        curl -k -u admin:helloworld https://$CI_SPLUNK_HOST:8089/services/data/indexes -d name=pod-anno -d datatype=event
        # Enable HEC services
        curl -X POST -u admin:helloworld -k https://$CI_SPLUNK_HOST:8089/servicesNS/nobody/splunk_httpinput/data/inputs/http/http/enable
        # Create new HEC token
        curl -X POST -u admin:helloworld -k -d "name=splunk_hec_token&token=<YOUR_SPLUNK_TOKEN>&disabled=0&index=main&indexes=main,circleci_events,ns-anno,pod-anno" https://$CI_SPLUNK_HOST:8089/servicesNS/nobody/splunk_httpinput/data/inputs/http
        # Restart Splunk
        curl -k -u admin:helloworld https://$CI_SPLUNK_HOST:8089/services/server/control/restart -X POST
        
    2. Deploy sck otel connector
        # Edit YOUR_VALUES.yaml file for Splunk HEC token, HEC endpoint, image repository, and other desired configuration.
        # Default image repository: otel/opentelemetry-collector-contrib 
        helm install sck -f <YOUR_VALUES.yaml> charts/opentelemetry-collector/
        
    3. Deploy log generator
        docker pull rock1017/log-generator:2.2.4
        kubectl apply -f test/test_setup.yaml
## Testing Instructions
0. (Optional) Use a virtual environment for the test  
    `virtualenv --python=python3.6 venv`  
    `source venv/bin/activate`
1. Install the dependencies  
    `pip install -r requirements.txt`  
2. Start the test with the required options configured  
    `python -m pytest <options>`  

    **Options are:**  
    --splunkd-url
    * Description: splunkd url used to send test data to. Eg: https://localhost:8089  
    * Default: https://localhost:8089

    --splunk-user
    * Description: splunk username  
    * Default: admin

    --splunk-password
    * Description: splunk user password  
    * Default: changeme

