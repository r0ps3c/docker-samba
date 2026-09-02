FROM alpine:3.24
RUN \
	apk --no-cache add samba=4.21.9-r1 && \
	apk upgrade --no-cache && \
	mkdir -p /etc/samba/smb.conf.d && \
	touch /etc/samba/smb.conf.d/override.conf

COPY smb.conf /etc/samba/smb.conf

EXPOSE 139 445
ENTRYPOINT ["/usr/sbin/smbd", "-F", "--no-process-group"]
