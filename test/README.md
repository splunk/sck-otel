# SCK-OTEL Integration Tests Environment Setup

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
        
        # Run following command to check if Splunk is ready. User should see "Ansible playbook complete, will begin streaming splunkd_stderr.log"
        kubectl logs splunk
        
        # Forward local ports to ports on the Splunk Pod
        kubectl port-forward pods/splunk 8089
        kubectl port-forward pods/splunk 8088
        
        # Setup Indexes
        curl -k -u admin:helloworld https://localhost:8089/services/data/indexes -d name=circleci_events -d datatype=event
        curl -k -u admin:helloworld https://localhost:8089/services/data/indexes -d name=ns-anno -d datatype=event
        curl -k -u admin:helloworld https://localhost:8089/services/data/indexes -d name=pod-anno -d datatype=event
        
        # Enable HEC services
        curl -X POST -u admin:helloworld -k https://localhost:8089/servicesNS/nobody/splunk_httpinput/data/inputs/http/http/enable
        
        # Create new HEC token
        curl -X POST -u admin:helloworld -k -d "name=splunk_hec_token&token=a6b5e77f-d5f6-415a-bd43-930cecb12959&disabled=0&index=main&indexes=main,circleci_events,ns-anno,pod-anno" https://localhost:8089/servicesNS/nobody/splunk_httpinput/data/inputs/http
        
        # Restart Splunk
        curl -k -u admin:helloworld https://localhost:8089/services/server/control/restart -X POST
               
    2. Deploy sck otel connector
        # Get Splunk Host IP
        export SPLUNK_HOST=$(kubectl get pod splunk --template={{.status.podIP}})
        
        # Use .circleci/sck_otel_values.yaml file to deploy sck otel connector
        # Default image repository: otel/opentelemetry-collector-contrib 
        helm install sck-otel --set splunk_hec.index=circleci_events \
        --set splunk_hec.token=a6b5e77f-d5f6-415a-bd43-930cecb12959 \
        --set splunk_hec.endpoint=https://$SPLUNK_HOST:8088/services/collector \
        --set containers.containerRuntime=docker \
        -f .circleci/sck_otel_values.yaml charts/opentelemetry-collector/
        
    3. Deploy log generator
        kubectl apply -f test/test_setup.yaml
## Testing Instructions
0. (Optional) Use a virtual environment for the test  
    `virtualenv --python=python3.6 venv`  
    `source venv/bin/activate`
1. Install the dependencies  
    `pip install -r requirements.txt`  
2. Start the test with the required options configured  
    `python -m pytest \
	--splunkd-url https://localhost:8089 \
	--splunk-user admin \
	--splunk-password helloworld \
	-p no:warnings -s`  

    **Options are:**  
    --splunkd-url
    * Description: splunkd url used to send test data to. 
    * Default: https://localhost:8089

    --splunk-user
    * Description: splunk username  
    * Default: admin

    --splunk-password
    * Description: splunk user password   
    * Default: changeme

