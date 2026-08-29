FROM alpine:3.20 AS builder
RUN apk add --no-cache build-base git
RUN git clone --depth 1 --branch v1.0.5 https://github.com/rofl0r/microsocks.git /src
WORKDIR /src
RUN make

FROM alpine:3.20
RUN adduser -D -H -u 10001 proxy
COPY --from=builder /src/microsocks /usr/local/bin/microsocks
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER proxy
EXPOSE 1080
ENTRYPOINT ["/entrypoint.sh"]
