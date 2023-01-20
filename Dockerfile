FROM alpine
RUN \
	apk -U --no-cache add samba tini

ADD smb.conf /etc/samba

RUN \
	rm -rf /var/cache/apk/*

EXPOSE 139 445
ENTRYPOINT ["/usr/sbin/smbd","-F","--no-process-group"]
