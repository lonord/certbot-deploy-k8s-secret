#!/bin/sh

if [ ! -d "/var/run/secrets/kubernetes.io/serviceaccount" ]; then
    echo "this image should run in k8s cluster with valid ServiceAccount"
    exit 1
fi

if [ -z "$CERT" ]; then
    echo "env CERT is required"
    exit 1
fi

if [ -z "$SECRET" ]; then
    echo "env SECRET is required"
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
fi

FORCE=
if [ "$1" == "--force" -o "$1" == "-f" ]; then
    FORCE=1
fi

CERT_DIR=/cert/$CERT

if [ ! -d "$CERT_DIR" ]; then
    echo "directory of cert not found: $CERT_DIR"
    exit 1
fi

CERT_MARK=$CERT_DIR/certbot-deploy-k8s-secret.mark

if [ -z "$FORCE" ]; then
    if [ -f "$CERT_MARK" ]; then
        last_update=$(cat $CERT_MARK)
        timestamp_cert=$(stat -c %Y $CERT_DIR/fullchain.pem)
        if [ "$last_update" == "$timestamp_cert" ]; then
            echo "cert is up-to-date, skip deploy"
            exit 0
        fi
    fi
fi

cat /secret-template.json | \
	sed "s/NAMESPACE/${NAMESPACE}/" | \
	sed "s/NAME/${SECRET}/" | \
	sed "s/TLSCERT/$(cat ${CERT_DIR}/fullchain.pem | base64 | tr -d '\n')/" | \
	sed "s/TLSKEY/$(cat ${CERT_DIR}/privkey.pem |  base64 | tr -d '\n')/" \
	> /secret.json

ls /secret.json || exit 1

# update secret
curl -k -s -w "\n%{http_code}" \
    --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    -XPATCH  \
    -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    -H "Accept: application/json, */*" \
    -H "Content-Type: application/strategic-merge-patch+json" \
    -d @/secret.json \
    https://kubernetes/api/v1/namespaces/${NAMESPACE}/secrets/${SECRET} \
    > /update_result.txt
result_code=$(tail -n 1 /update_result.txt)
if [ "$result_code" == "404" ]; then
    echo "Secret not found, do create..."
    curl -k \
    --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    -XPOST  \
    -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    -H "Accept: application/json, */*" \
    -H "Content-Type: application/json" \
    -d @/secret.json \
    https://kubernetes/api/v1/namespaces/${NAMESPACE}/secrets
else
    head -n -1 /update_result.txt
fi
