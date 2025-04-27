FROM alpine:3.21
RUN \
	apk -U --no-cache add samba

ADD smb.conf /etc/samba

RUN \
	rm -rf /var/cache/apk/*

EXPOSE 139 445
ENTRYPOINT ["/usr/sbin/smbd","-F","--no-process-group"]
