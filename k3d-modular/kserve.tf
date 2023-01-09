# create kserve module
module "kserve" {
  source = "../modules/kserve-module"

  count = local.kserve.enable ? 1 : 0

  depends_on = [
    k3d_cluster.zenml-cluster,
    module.istio
  ]

  knative_version = local.kserve.knative_version
  kserve_version = local.kserve.version
  kserve_domain = "${local.kserve.ingress_host_prefix}.${module.istio[0].ingress-ip-address}.nip.io"
}

# the namespace where zenml will deploy kserve models
resource "kubernetes_namespace" "kserve-workloads" {

  count = local.kserve.enable ? 1 : 0

  metadata {
    name = local.kserve.workloads_namespace
  }

  depends_on = [
    module.kserve,
  ]
}

# add role to allow kubeflow to access kserve
#
# NOTE: the kserve zenml model deployer pipeline steps need to be able to create
# secrets, serviceaccounts, and Kserve inference services in the namespace where
# it will deploy models
resource "kubernetes_cluster_role_v1" "kserve" {

  count = local.kserve.enable ? 1 : 0

  metadata {
    name = "kserve-workloads"
    labels = {
      app = "zenml"
    }
  }

  rule {
    api_groups = ["serving.kserve.io", ""]
    resources  = ["inferenceservices", "secrets", "serviceaccounts"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  depends_on = [
    module.kserve,
  ]
}

# assign role to kubeflow pipeline runner
resource "kubernetes_role_binding_v1" "kubeflow-kserve" {

  count =  (local.kserve.enable && local.kubeflow.enable) ? 1 : 0

  metadata {
    name = "kubeflow-kserve"
    namespace = kubernetes_namespace.kserve-workloads[0].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.kserve[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "pipeline-runner"
    namespace = "kubeflow"
  }

  depends_on = [
    module.kserve,
    module.kubeflow-pipelines,
  ]
}


# assign role to kubernetes pipeline runner
resource "kubernetes_role_binding_v1" "k8s-kserve" {

  count = local.kserve.enable ? 1 : 0

  metadata {
    name = "k8s-kserve"
    namespace = kubernetes_namespace.kserve-workloads[0].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.kserve[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = kubernetes_namespace.k8s-workloads.metadata[0].name
  }

  depends_on = [
    module.kserve,
    k3d_cluster.zenml-cluster,
  ]
}
