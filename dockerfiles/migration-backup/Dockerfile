FROM fedora:29
RUN yum -y install skopeo origin-clients docker awscli
COPY kube-config /.kube/config
COPY aws-credentials /.aws/credentials
COPY image-backup.sh /bin/image-backup.sh
COPY ark /bin/ark
COPY migration-env.sh /migration-env.sh
ENTRYPOINT ["/bin/image-backup.sh"]
