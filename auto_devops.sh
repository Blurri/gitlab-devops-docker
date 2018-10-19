#!/bin/bash

COMMAND=$0
echo "as you command: $COMMAND"
if [ "$COMMAND" == "ensure_namespace" ] ; then
  echo "Ensure Namespace $KUBE_NAMESPACE"
  kubectl describe namespace "$KUBE_NAMESPACE" || kubectl create namespace "$KUBE_NAMESPACE"
fi

if [ "$COMMAND" == "create_secret" ] ; then
  echo "Create secret..."
  if [[ "$CI_PROJECT_VISIBILITY" == "public" ]]; then
    return
  fi

  kubectl create secret -n "$KUBE_NAMESPACE" \
    docker-registry gitlab-registry \
    --docker-server="$CI_REGISTRY" \
    --docker-username="${CI_DEPLOY_USER:-$CI_REGISTRY_USER}" \
    --docker-password="${CI_DEPLOY_PASSWORD:-$CI_REGISTRY_PASSWORD}" \
    --docker-email="$GITLAB_USER_EMAIL" \
    -o yaml --dry-run | kubectl replace -n "$KUBE_NAMESPACE" --force -f -
fi

if [ "$COMMAND" == "deploy" ] ; then
  echo "Deploy to kubernetes"
  helm upgrade --install \
    --wait \
    --set releaseOverride="$CI_ENVIRONMENT_SLUG" \
    --set image.repository="$CI_REGISTRY_IMAGE" \
    --set image.tag="$CI_COMMIT_SHA" \
    --set image.pullPolicy=IfNotPresent \
    --set application.environment="$DEPLOY_ENVIRONMENT" \
    --set env.normal.ROOT_URL="$ROOT_URL" \
    --set env.normal.MONGO_URL="$MONGO_URL" \
    --namespace="$KUBE_NAMESPACE" \
    --version="$CI_PIPELINE_ID-$CI_JOB_ID" \
    "$CI_ENVIRONMENT_SLUG" \
    helm/
fi

if [ "$COMMAND" == "delete" ] ; then
  echo "Delete $name"
  name="$CI_ENVIRONMENT_SLUG"

  if [[ -n "$(helm ls -q "^$name$")" ]]; then
    helm delete --purge "$name"
  fi
fi
