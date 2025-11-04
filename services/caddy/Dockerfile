FROM caddy:builder AS builder
 
RUN --mount=type=cache,target=/go/pkg,sharing=locked \
    xcaddy build \
    --with github.com/caddy-dns/duckdns \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddy-dns/dynv6
 
FROM caddy:latest
 
COPY --from=builder /usr/bin/caddy /usr/bin/caddy