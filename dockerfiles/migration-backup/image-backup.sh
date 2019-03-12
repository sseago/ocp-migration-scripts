#!/bin/bash

set -x
sleep 3

export KUBECONFIG=/.kube/config
export AWS_SHARED_CREDENTIALS_FILE=/.aws/credentials
# defines OC_USER, OC_PASSWORD, S3_BUCKET
. /migration-env.sh

NAMESPACE=$1
if [ -z "$2" ]
then
    BACKUP_NAME=poc-backup
else
    BACKUP_NAME=$2
fi

BACKUP_MOUNTPOINT=/tmp
BACKUP_DIR=poc-out
BACKUP_LOCATION=$BACKUP_MOUNTPOINT/$BACKUP_DIR
mkdir -p $BACKUP_LOCATION
rm -rf  $BACKUP_LOCATION/*
oc login -u $OC_USER -p $OC_PASSWORD
oc project $NAMESPACE

ark backup delete --confirm $BACKUP_NAME

IMAGESTREAM_NAMES_STR=`oc get imagestreams -o jsonpath='{.items[*].metadata.name}'`
IFS=' ' read -a IMAGESTREAM_NAMES <<< $IMAGESTREAM_NAMES_STR
for IMAGESTREAM_NAME in "${IMAGESTREAM_NAMES[@]}"
do
  TAGS_STR=`oc get imagestream $IMAGESTREAM_NAME -o jsonpath='{range .status.tags[*]}{.tag},{.items[0].dockerImageReference},{.items[0].image} '`
  IFS=' ' read -a TAGS <<< $TAGS_STR
  for i in "${TAGS[@]}"
  do
    IFS=',' read -a ITEMS <<< $i
    TAG=${ITEMS[0]}
    DOCKER_REF=${ITEMS[1]}
    OC_IMAGE_NAME=${ITEMS[2]}

    NS_BACKUP_PATH=$BACKUP_LOCATION/$NAMESPACE/$IMAGESTREAM_NAME/$TAG/$OC_IMAGE_NAME
    mkdir -p $NS_BACKUP_PATH
    skopeo copy --src-creds=$OC_USER:$(oc whoami -t) --src-tls-verify=false docker://$DOCKER_REF dir:$NS_BACKUP_PATH
  done
done
cd $BACKUP_MOUNTPOINT
tar czvf $BACKUP_NAME.tar.gz  $BACKUP_DIR
aws s3 cp ./$BACKUP_NAME.tar.gz s3://$S3_BUCKET
ark backup create $BACKUP_NAME -w --include-namespaces=$NAMESPACE --include-resources=service,deploymentconfig.apps.openshift.io,buildconfig.build.openshift.io,route.route.openshift.io
