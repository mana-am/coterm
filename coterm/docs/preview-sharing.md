# Preview Sharing

Coterm preview sharing lets a collaborator view a local web app running on the
host machine through the self-hosted `coterm-relay` Worker. There is no official
hosted preview service and no inbound port on the host machine.

## How it works

```text
Guest browser or Coterm browser
  -> self-hosted coterm-relay Worker
  -> PreviewSessionObject Durable Object
  -> Host Coterm outbound WebSocket
  -> http://127.0.0.1:<port>
```

The preview capability is deployed with `coterm-relay`; users do not deploy a
separate tunnel service.

## MVP limits

- Only local HTTP targets are allowed: `127.0.0.1` or `localhost`.
- HTTPS targets, WebSocket/HMR proxying, arbitrary LAN hosts, file uploads over
  10 MB, and iOS simulator streaming are not part of the first preview tunnel.
- Preview sessions close when the host disconnects or after idle cleanup.
- Anyone with the viewer URL can view the preview.
- The first viewer request sets a same-origin preview cookie so absolute asset
  paths such as `/assets/app.js` can resolve through the same preview session.
  If you open multiple previews on the same relay origin, the most recently
  opened preview owns those root-relative requests.

## Headless host

After creating a normal collaboration session, use its room code and
`shareSecret` to expose a local port:

```bash
bun run preview:host -- \
  --relay https://coterm-relay.<sub>.workers.dev \
  --room ABCD1234 \
  --share-secret "$COTERM_SHARE_SECRET" \
  --port 3000
```

The command prints a viewer URL:

```text
Preview URL: https://coterm-relay.<sub>.workers.dev/v1/preview/sessions/p_.../proxy/?t=...
```

Open that URL in a browser or Coterm browser surface.

## Security

Creating a preview requires the collaboration room's `shareSecret`. The Worker
stores token hashes, not the raw host/viewer tokens. The relay only asks the host
to fetch `127.0.0.1` or `localhost`, so the preview tunnel cannot be used as a
general LAN proxy.

For `hmac` deployments, collaboration joins still use the normal grant flow.
Preview URLs remain capability URLs for the MVP; a future control-plane flow can
mint scoped preview grants without changing the relay's host tunnel shape.
