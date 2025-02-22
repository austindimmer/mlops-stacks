# 🥙 GCP Cloud Composer Airflow Stack Recipe

There can be many motivations behind taking your ML application setup to a cloud environment, from needing specialized compute 💪 for training jobs to having a 24x7 load-balanced deployment of your trained model serving user requests 🚀.

We know that the process to set up an MLOps stack can be daunting. There are many components (ever increasing) and each have their own requirements. To make your life easier, we already have a [documentation page](https://docs.zenml.io/cloud-guide/overview) that takes you step-by-step through the entire journey in a cloud platform of your choice (AWS, GCP and Azure supported for now). This recipe, however, goes one step further. 

You can have a simple MLOps stack ready for running your machine learning workloads after you execute this recipe 😍. It sets up the following resources: 
- A managed Airflow deployment on GCP using Cloud Composer as an [orchestrator](https://docs.zenml.io/mlops-stacks/orchestrators) for your workloads.
- A GCS Bucket as an [artifact store](https://docs.zenml.io/mlops-stacks/artifact-stores), which can be used to store all your ML artifacts like the model, checkpoints, etc. 
- A [secrets manager](https://docs.zenml.io/mlops-stacks/secrets-managers) enabled for storing your secrets. 


## Prerequisites

* You must have a GCP project where you have sufficient permissions to create and destroy resources that will be created as part of this recipe. Supply the name of your project in the `locals.tf` file.
* Have [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform) and [Helm](https://helm.sh/docs/intro/install/#from-script) installed on your system.


## 🍏 Inputs

Before starting, you should know the values that you have to keep ready for use in the script. 
- Check out the `locals.tf` file to configure basic information about your deployments.
- Take a look at the `values.tfvars.json` file to know what values have to be supplied during the execution of the script. These are mostly sensitive values like MLflow passwords, etc. Make sure you don't commit them!

> **Warning** 
> The `prefix` local variable you assign should have a unique value for each stack. This ensures that the stack you create doesn't interfere with the stacks somebody else in your organization has created with this script.

## 🧑‍🍳 Cooking the recipe

It is not necessary to use the MLOps stacks recipes presented here alongside the
[ZenML](https://github.com/zenml-io/zenml) framework. You can simply use the Terraform scripts
directly.

However, ZenML works seamlessly with the infrastructure provisioned through these recipes. The ZenML CLI has an integration with this repository that makes it really simple to pull and deploy these recipes. A simple flow could look like the following:

1. Pull this recipe to your local system.

    ```shell
    zenml stack recipe pull gcp-airflow
    ```
2. 🎨 Customize your deployment by editing the default values in the `locals.tf` file.

3. 🔐 Add your secret information like keys and passwords into the `values.tfvars.json` file which is not committed and only exists locally.

5. 🚀 Deploy the recipe with this simple command.

    ```
    zenml stack recipe deploy gcp-airflow
    ```

    > **Note**
    > If you want to allow ZenML to automatically import the created resources as a ZenML stack, pass the `--import` flag to the command above. By default, the imported stack will have the same name as the stack recipe and you can provide your own with the `--stack-name` option.
    

6. You'll notice that a ZenML stack configuration file gets created after the previous command executes 🤯! This YAML file can be imported as a ZenML stack manually by running the following command.

    ```
    zenml stack import <STACK_NAME> -f <PATH_TO_THE_CREATED_STACK_CONFIG_YAML>
    ```

> **Note**
>
>  You need to have your GCP credentials saved locally for the `apply` function to work.

### 📢 Important

In case you see an error like the following, follow the steps listed after the error message to resolve it.

```
HTTP response body: {"kind":"Status","apiVersion":"v1","metadata":{},"status":"Failure","message":"pods is forbidden: User \"system:serviceaccount:composer-x-x-x-airflow-x-x-x-fe36b202:default\" cannot list resource \"pods\" in API group \"\" in the namespace \"composer-user-workloads\"","reason":"Forbidden","details":{"kind":"pods"},"code":403}
```

You need to add a [Role](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole) and a [RoleBinding](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#rolebinding-and-clusterrolebinding) to allow the service account in your composer namespace to perform actions on your Kubernetes resources like your pods. Your local kubectl client should already be configured to talk to the Kubernetes cluster that Cloud Composer is using.

Apply the following Role and RoleBinding to your cluster after replacing the namespace under `subjects` with the namespace of your Cloud Composer deployment:

```shell
kubectl apply -n composer-user-workloads -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-list-reader
  namespace: composer-user-workloads
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods", "pods/log", "secrets", "serviceaccounts"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-list-reader-binding
  namespace: composer-user-workloads
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-list-reader
subjects:
- kind: ServiceAccount
  name: default
  namespace: composer-x-x-x-airflow-x-x-x-fe36b202
EOF
```


## 🥧 Outputs 

The script, after running, outputs the following.
| Output | Description |
--- | ---
gke-cluster-name | Name of the GKE cluster that is created as part of the Cloud Composer environment |
airflow-uri | The URI to access the Airflow UI on GCP |
dag-gcs-uri | The URI to the GCS bucket that the Cloud Composer environment uses. Upload the zip file created by ZenML to the DAGs folder here |
gcs-bucket-path | The path of the GCS bucket. Useful while registering the artifact store|
container-registry-URI | The GCP Container Registry URI |

For outputs that are sensitive, you'll see that they are not shown directly on the logs. To view the full list of outputs, run the following command.

```bash
terraform output
```

To view individual sensitive outputs, use the following format. Here, the metadata password is being obtained. 

```bash
terraform output metadata-db-password
```

## Deleting Resources

Using the ZenML stack recipe CLI commands, you can run the following commands to delete your resources and optionally clean up the recipe files that you had downloaded to your local system.

1. 🗑️ Run the destroy command which removes all resources and their dependencies from the cloud.

    ```shell
    zenml stack recipe destroy gcp-airflow
    ```

2. (Optional) 🧹 Clean up all stack recipe files that you had pulled to your local system.

    ```shell
    zenml stack recipe clean
    ```

## Using the recipes without the ZenML CLI

As mentioned above, you can still use the recipe without having using the `zenml stack recipe` CLI commands or even without installing ZenML. Since each recipe is a group of Terraform modules, you can simply employ the terraform CLI to perform `apply` and `destroy` operations.

### Create the resources

1. 🎨 Customize your deployment by editing the default values in the `locals.tf` file.

2. 🔐 Add your secret information like keys and passwords into the `values.tfvars.json` file which is not committed and only exists locally.

3. Initialize Terraform modules and download provider definitions.
    ```bash
    terraform init
    ```

4. Apply the recipe.
    ```bash
    terraform apply
    ```

### Deleting resources

1. 🗑️ Run the destroy function to clean up all resources.

    ```
    terraform destroy
    ```


## Troubleshoot Known Problems

These are some known problems that might arise out of running this recipe. Some of these 
are terraform commands but running `zenml stack recipe apply` would also achieve similar results as `terraform init` and `terraform apply`.

*  When executing terraform commands, an error like this one: `timeout while waiting for plugin to start` 
\
    💡 Fix - If you encounter this error with `apply`, `plan` or `destroy`, do `terraform init` and run your command again.

* While running `terraform init`, an error which says `Failed to query available provider packages... No available releases match the given constraint`
\
    💡 Fix - First of all, you should create an issue so that we can take a look. Meanwhile, if you know Terraform, make sure all the modules that are being used are on their latest version.

* While running a terraform command, this error might appear too: `context deadline exceeded`
\
    💡 Fix - This problem could arise due to strained system resources. Try running the command again after some time.
