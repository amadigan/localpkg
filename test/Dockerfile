FROM alpine:latest
RUN apk add --no-cache curl libarchive-tools jq zsh
WORKDIR /src
ADD . .
ENTRYPOINT ["/src/test/unit.zsh"]
