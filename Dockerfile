FROM alpine:3.11

COPY secret-template.json /secret-template.json
COPY entrypoint.sh /entrypoint.sh

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
    && apk update \
    && apk add curl

# certificates
# /certs/abc.com/fullchain.pem
# /certs/abc.com/privkey.pem
VOLUME /certs

# cert need to deploy
ENV CERT ""
# name of Secret to create or update
ENV SECRET ""
# namespace of Secret, if not specified, namespace of ServiceAccount will be used
ENV NAMESPACE ""

ENTRYPOINT [ "/entrypoint.sh" ]