FROM alpine AS base
RUN apk add --no-cache curl libarchive-tools zsh openssl

FROM base AS build
WORKDIR /src
ADD . .
WORKDIR /dist
ARG GITHUB_REPOSITORY
ARG RELEASE_TAG
ENV GITHUB_REPOSITORY=$GITHUB_REPOSITORY
ENV RELEASE_TAG=$RELEASE_TAG
RUN /src/build-release.zsh

FROM base AS localpkg
ARG GITHUB_REPOSITORY=""
LABEL org.opencontainers.image.source=https://github.com/$GITHUB_REPOSITORY
LABEL org.opencontainers.image.description="localpkg docker image"
LABEL org.opencontainers.image.license=CC0-1.0
COPY --from=build /dist/localpkg /bin/localpkg
WORKDIR /home
ENTRYPOINT ["/bin/localpkg"]

FROM scratch AS release
COPY --from=build /dist/* ./
