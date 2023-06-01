#! /usr/bin/env bash

this_dir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
root_dir=$(cd ${this_dir}/../../.. && pwd)
if [[ -e "${root_dir}/.env" ]]; then source ${root_dir}/.env; fi
if [[ -e "${this_dir}/.env" ]]; then source ${this_dir}/.env; fi
source ${root_dir}/lib/kubernetes.sh

export bs_app_name=${1:-${BS_APP_NAME:-bs1}}
export quay_user_name=${2:-${QUAY_USER_NAME:-${USER}}}

# nvm use --latest --lts

yarn add --cwd packages/app @backstage/plugin-kubernetes
yarn add --cwd packages/backend @backstage/plugin-kubernetes-backend
yarn add --cwd packages/app @roadiehq/backstage-plugin-argo-cd
