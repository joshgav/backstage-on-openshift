## Backstage on OpenShift

Deploy a Backstage portal instance in an OpenShift cluster.

After deployment edit configMap `bs1-backstage-app-config` to dynamically
reconfigure the portal; or change it in the
[deploy/app-config.yaml](deploy/app-config.yaml) file here and run `deploy.sh`
to reconfigure. NOTE: **delete the current pod** so the modified configMap is
loaded.

For example, try uncommenting one of the commented URL locations in the initial
configMap, then deleting the pod, then refreshing Backstage.

### Dependencies

- [EDB Postgres][] - [openshift-services/postgres][]
- Create a Secret named `github-token` with key `GITHUB_TOKEN` with value set to
  a GitHub Token with repo and workflow permissions.
- Create a Secret name `argocd-token` with key `ARGOCD_AUTHENTICATION_TOKEN` set
  to an admin token for ArgoCD

## Build and deploy (first time)

1. Install [dependencies](#dependencies)
1. Clone this repo and change dir: `git clone https://github.com/joshgav/bs1.git
1. Set env vars in `.env` file or via `export`
1. Run `REBUILD_IMAGE=1 ./deploy/deploy.sh` to build and push the image and
   deploy the system

- The resolved URL is echoed at the end of `deploy.sh` (which can be run anytime)

## Iterate

- Visit your instance at <https://bs1-backstage-backstage.${openshift_ingress_domain}>,
  where `openshift_ingress_domain` is found via `oc get ingresses.config.openshift.io cluster -ojson | jq -r .spec.domain`

- Reconfigure and deploy with `deploy/deploy.sh` (it's idempotent)
- Rebuild, reconfigure and deploy with `REBUILD_IMAGE=1 deploy/deploy.sh`
- Follow logs: `kubectl logs --follow deployment/bs1-backstage`
- Troubleshoot the image: `kubectl run -it --image quay.io/${QUAY_USER_NAME}/bs1-backstage:latest --rm bs-test -- bash`

## Delete

Delete the namespace `backstage` (`kubectl delete namespace backstage`) and start over.

## Notes

- On the first deployment the Backstage pod is ready before the database cluster
  so it crashloops a few times and then stabilizes.
- This project uses app-config file in `deploy` only - not the ones in the root
  directory.
- If you have OpenTelemetry in your cluster uncomment the
  `base/instrumentation.yaml` file to add OpenTelemetry injection to the namespace
  and the Backstage deployment.
- You must use the latest LTS version of Node.js. Jump to it if you use nvm with
  `nvm use --lts --latest`.
- Try importing Janus' templates in the `/catalog-import` page from
  <https://github.com/janus-idp/software-templates/blob/main/showcase-templates.yaml>.
  They're included in this repo's default `app-config.yaml` file.
- To get an ArgoCD auth token, run [patch-argocd.sh](./patch-argocd.sh), then
  login with the admin account using the secret from namespace `openshift-gitops`,
  secret name `openshift-gitops-cluster`. Navigate to the Settings section and
  request a token valid for `365d`.

[EDB Postgres]: https://artifacthub.io/packages/olm/community-operators/cloud-native-postgresql
[openshift-services/postgres]: https://github.com/joshgav/devenv/tree/main/openshift-services/postgres
