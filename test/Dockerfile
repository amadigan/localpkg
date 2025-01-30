FROM alpine:latest AS localpkg-unit
RUN apk add --no-cache curl libarchive-tools jq zsh
WORKDIR /src
ADD . .
ENTRYPOINT ["/src/test/unit.zsh"]

FROM localpkg-unit AS localpkg-build
WORKDIR /dist
RUN /src/localpkg.zsh build -z @ /dist/localpkg

