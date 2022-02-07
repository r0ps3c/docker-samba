FROM alpine
RUN \
	apk -U add samba tini

ADD smb.conf /etc/samba

RUN \
	rm -rf /var/cache/apk/*

EXPOSE 139 445
ENTRYPOINT /usr/sbin/smbd -FS --no-process-group < /dev/null
