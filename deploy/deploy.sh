#! /usr/bin/env bash

this_dir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
root_dir=$(cd ${this_dir}/.. && pwd)
if [[ -e "${root_dir}/.env" ]]; then source ${root_dir}/.env; fi
if [[ -e "${this_dir}/.env" ]]; then source ${this_dir}/.env; fi
source ${this_dir}/lib/kubernetes.sh

export bs_app_name=${1:-${BS_APP_NAME:-bs1}}
export quay_user_name=${2:-${QUAY_USER_NAME:-${USER}}}
export openshift_ingress_domain=$(oc get ingresses.config.openshift.io cluster -ojson | jq -r .spec.domain)
export registry_hostname=${REGISTRY_HOSTNAME:-quay.io}

if [[ "${REBUILD_IMAGE}" == "1" ]]; then
    image_url=${registry_hostname}/${quay_user_name}/${bs_app_name}-backstage:latest
    echo "INFO: build & push ${image_url}"
    pushd ${root_dir}
        yarn install
        yarn tsc
        yarn build
        yarn build-image
        docker tag backstage:latest ${image_url}
        docker push ${image_url}
    popd
fi

ensure_namespace backstage true

## TODO: test further, fix image and avoid this
oc adm policy add-scc-to-user --serviceaccount=default nonroot-v2
oc adm policy add-cluster-role-to-user --serviceaccount=default view

echo "INFO: apply resources from ${this_dir}/base/*.yaml"
for file in $(ls ${this_dir}/base/*.yaml); do
    lines=$(cat ${file} | awk '/^[^#].*$/ {print}' | wc -l)
    if [[ ${lines} > 0 ]]; then
        cat ${file} | envsubst '${bs_app_name} ${ARGOCD_AUTH_TOKEN} ${GITHUB_TOKEN}' | kubectl apply -f -
    fi
done

file_path=${this_dir}/app-config.yaml
if [[ -e "${file_path}" ]]; then
    echo "INFO: applying appconfig configmap from ${file_path}"
    kubectl delete configmap ${bs_app_name}-backstage-app-config 2> /dev/null

    tmpfile=$(mktemp)
    cat "${file_path}" | envsubst '${bs_app_name} ${quay_user_name} ${openshift_ingress_domain}' > ${tmpfile}
    kubectl create configmap ${bs_app_name}-backstage-app-config \
        --from-file "$(basename ${file_path})=${tmpfile}"
else
    echo "INFO: no file found at ${file_path}"
fi

github_app_creds_path=${this_dir}/github-app-credentials.yaml
if [[ -e ${github_app_creds_path} ]]; then
    echo "INFO: applying github-app-credentials.yaml as a secret"
    kubectl delete secret github-app-credentials 2> /dev/null
    kubectl create secret generic github-app-credentials --from-file=${github_app_creds_path}
fi

oc get clusterrolebinding backstage-backend-k8s &> /dev/null
if [[ $? != 0 ]]; then
    oc create clusterrolebinding backstage-backend-k8s --clusterrole=backstage-k8s-plugin --serviceaccount=backstage:default
fi
oc get clusterrolebinding backstage-backend-ocm &> /dev/null
if [[ $? != 0 ]]; then
    oc create clusterrolebinding backstage-backend-ocm --clusterrole=backstage-ocm-plugin --serviceaccount=backstage:default
fi
oc get clusterrolebinding backstage-backend-tekton &> /dev/null
if [[ $? != 0 ]]; then
    oc create clusterrolebinding backstage-backend-tekton --clusterrole=backstage-tekton-plugin --serviceaccount=backstage:default
fi

echo "INFO: helm upgrade --install"
ensure_helm_repo bitnami https://charts.bitnami.com/bitnami 1> /dev/null
ensure_helm_repo backstage https://backstage.github.io/charts 1> /dev/null
cat "${this_dir}/chart-values.yaml" | \
    envsubst '${bs_app_name} ${quay_user_name}  ${openshift_ingress_domain}' | \
        helm upgrade --install ${bs_app_name} backstage/backstage --values -

echo "INFO: Visit your Backstage instance at https://${bs_app_name}-backstage-backstage.${openshift_ingress_domain}/"
