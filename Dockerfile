FROM alpine
WORKDIR /
COPY --chown=root:root [ "./sh/installation.sh", "/etc/profile.d/" ]
RUN mkdir /research
ENTRYPOINT [ "/bin/sh", "-c", "/etc/profile.d/installation.sh" ]