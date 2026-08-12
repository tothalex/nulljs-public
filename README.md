# NullJS

A serverless JavaScript platform in a **single binary**. Write TypeScript functions —
HTTP routes, cron jobs, event handlers, React sites — and NullJS runs them in pooled
QuickJS runtimes with a built-in gateway, dashboard, and deploy pipeline. No containers,
no Node processes per function, no separate server to install.

```ts
import { defineRoute, json } from "@tothalex/cloud";

export default defineRoute({
  name: "echo",
  route: "POST /echo",
  schema: {
    type: "object",
    required: ["text"],
    properties: { text: { type: "string" }, repeat: { type: "integer", maximum: 10 } },
  },
  handler: async (request) => {
    const { text, repeat = 1 } = request.body; // parsed, validated, and TYPED from the schema
    return json({ echo: Array(repeat).fill(text).join(" ") });
  },
});
```

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/tothalex/nulljs-public/main/install.sh | sh
```

Supported platforms: macOS (Apple Silicon), Linux x64, Linux arm64. Binaries are on the
[releases page](https://github.com/tothalex/nulljs-public/releases); pin a version with
`NULLJS_VERSION=vX.Y.Z` when running the installer.

## Quickstart

```sh
nulljs create my-app
cd my-app
nulljs dev
```

`nulljs dev` starts everything in one process: the API + dashboard on `:3000`, the
function gateway on `:3001`, a file watcher that deploys on save, and a live terminal UI.
Try the example route:

```sh
curl http://my-app.localhost:3001/hello
```

## What you get

- **Functions**: HTTP routes, cron schedules, and app-internal events, written in
  TypeScript with full inference — request bodies and event payloads are typed from
  their JSON Schemas, and validation runs before your handler does.
- **Runtime modules**: `cloud/postgres` (SQL), `cloud/cache` (KV), `cloud/got` (HTTP),
  `cloud/secret` (secrets + JWT + password hashing), `cloud/event`, `cloud/uuid` — no
  npm dependencies to bundle for the common cases.
- **React sites**: put a `Page` component in `src/index.tsx` and it deploys alongside
  your functions, with a Vite dev server in development.
- **Observability**: `nulljs logs --follow`, `nulljs invocations` (with error messages
  on failures), a web dashboard, and a machine-readable API (`/api/openapi.json`).
- **Testing**: handlers are unit-testable in milliseconds with `bun test` and the
  in-memory `cloud/*` doubles from `@tothalex/cloud/testing`.
- **AI-ready**: projects scaffold with agent docs and skills; `nulljs mcp` exposes
  deploy/logs/invoke as MCP tools; `nulljs dev --headless` emits NDJSON events for
  scripts and agents. All read commands take `--json`.
- **Production**: `nulljs serve` runs the same binary as a server; `nulljs host` sets it
  up under systemd. Deploys are signed with a local Ed25519 key.

## How it works

The `nulljs` binary embeds the platform server (Rust/Axum): a control plane for deploys
and telemetry, and a gateway that routes `{app}.{domain}` requests to your functions,
which execute as precompiled bytecode in pooled QuickJS runtimes. Deploys bundle your
TypeScript with a Rust-native bundler and upload over a signed API — the same API the
CLI, dashboard, and MCP tools all speak.

## License

MIT
