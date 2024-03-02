FROM caddy:builder AS builder
 
RUN --mount=type=cache,target=/go/pkg,sharing=locked \
    xcaddy build \
    --with github.com/mholt/caddy-dynamicdns \
    --with github.com/caddy-dns/cloudflare
 
FROM caddy:latest
 
COPY --from=builder /usr/bin/caddy /usr/bin/caddy