FROM catthehacker/ubuntu:act-latest
# Docker 29.x's docker cp rejects "mkdirat var/run" when /var/run is a symlink
# to /run. Replacing it with a real directory fixes the issue.
RUN rm -rf /var/run && mkdir -p /var/run/act
