#!/bin/bash
# image-backup.sh MIGRATION_REGISTRY MIGRATION_REGISTRY [BACKUP_NAME]

set -x
sleep 3

export KUBECONFIG=/.kube/config
export AWS_SHARED_CREDENTIALS_FILE=/.aws/credentials
# defines OC_USER, OC_PASSWORD, S3_BUCKET
. /migration-env.sh

MIGRATION_REGISTRY=$1
if [ -z "$2" ]
then
    BACKUP_NAME=poc-backup
else
    BACKUP_NAME=$2
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

    SRC_DOCKER_REF=$MIGRATION_REGISTRY/$NAMESPACE/$IMAGESTREAM_NAME@$OC_IMAGE_NAME
    DEST_DOCKER_REF=$DOCKER_ENDPOINT/$NAMESPACE/$IMAGESTREAM_NAME:$TAG

    skopeo copy --dest-creds=$OC_USER:$(oc whoami -t) --dest-tls-verify=false --src-tls-verify=false docker://$SRC_DOCKER_REF docker://$DEST_DOCKER_REF
  done
done
ark restore create -w --from-backup $BACKUP_NAME
