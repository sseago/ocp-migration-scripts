#!/bin/bash

set -x
sleep 3

export KUBECONFIG=/.kube/config
export AWS_SHARED_CREDENTIALS_FILE=/.aws/credentials
# defines OC_USER, OC_PASSWORD, S3_BUCKET
. /migration-env.sh

if [ -z "$1" ]
then
    BACKUP_NAME=poc-backup
else
    BACKUP_NAME=$1
fi

BACKUP_MOUNTPOINT=/tmp
BACKUP_DIR=poc-out
BACKUP_LOCATION=$BACKUP_MOUNTPOINT/$BACKUP_DIR
rm -rf  $BACKUP_LOCATION
cd $BACKUP_MOUNTPOINT
aws s3 cp s3://$S3_BUCKET/$BACKUP_NAME.tar.gz .
tar xzvf $BACKUP_NAME.tar.gz

oc login -u $OC_USER -p $OC_PASSWORD
DOCKER_ENDPOINT=$(oc registry info)

NAMESPACE=$(ls $BACKUP_LOCATION)
oc create namespace $NAMESPACE||true
oc project $NAMESPACE
for this_name in $BACKUP_LOCATION/$NAMESPACE/*
do
  IMAGESTREAM_NAME=${this_name##*/}
  for this_tag in $BACKUP_LOCATION/$NAMESPACE/$IMAGESTREAM_NAME/*
  do
    TAG=${this_tag##*/}
    OC_IMAGE_NAME=$(ls $BACKUP_LOCATION/$NAMESPACE/$IMAGESTREAM_NAME/$TAG)

    IMAGE_BACKUP=$BACKUP_LOCATION/$NAMESPACE/$IMAGESTREAM_NAME/$TAG/$OC_IMAGE_NAME
    DOCKER_REPOSITORY=$DOCKER_ENDPOINT/$NAMESPACE/$IMAGESTREAM_NAME:$TAG

    skopeo copy --dest-creds=$OC_USER:$(oc whoami -t) --dest-tls-verify=false dir:$IMAGE_BACKUP docker://$DOCKER_REPOSITORY
  done
done
ark restore create -w --from-backup $BACKUP_NAME
