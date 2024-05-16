FROM debian:buster-slim

RUN apt-get update && apt-get install -y git jq bash sed
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
