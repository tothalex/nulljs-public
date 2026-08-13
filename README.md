# NullJS

A serverless JavaScript platform in a **single binary**. Write TypeScript functions —
HTTP routes, cron jobs, event handlers — and full sites in **React, Svelte, or Solid**
(server-rendered pages and client-rendered SPAs), and NullJS runs them in pooled,
sandboxed runtimes with a built-in gateway, dashboard, and deploy pipeline. No
containers, no Node processes per function, no separate server to install.

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
`NULLJS_VERSION=vX.Y.Z` when running the installer. Later, `nulljs update` upgrades
in place (`nulljs update --check` to just look).

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

## Declaring functions

Every function is one file that default-exports its definition. The directory decides
the trigger type: `src/function/api/` for HTTP routes, `src/function/cron/` for
schedules, `src/function/event/` for event handlers.

**HTTP route** — `route` is `"METHOD /path"` with `:params` and `*` catch-alls; a
`schema` validates the body before your handler runs and types `request.body`:

```ts
import { defineRoute, json } from "@tothalex/cloud";

export default defineRoute({
  name: "get-user",
  route: "GET /users/:id",
  handler: async (request) => json({ id: request.params.id }),
});
```

**Cron** — 5- or 6-field expressions; the handler takes no arguments:

```ts
import { defineCron } from "@tothalex/cloud";
import { send } from "cloud/event";

export default defineCron({
  name: "ticker",
  cron: "*/10 * * * * *",
  handler: async () => {
    await send("tick", { at: new Date().toISOString() });
  },
});
```

**Event** — receives payloads sent with `cloud/event`'s `send()`; declare a `schema`
and the payload arrives parsed, validated, and typed:

```ts
import { defineEvent } from "@tothalex/cloud";

export default defineEvent({
  name: "on-tick",
  event: "tick",
  schema: { type: "object", required: ["at"], properties: { at: { type: "string" } } },
  handler: async (payload) => {
    console.log("tick at", payload.at);
  },
});
```

Shared config across all types: `timeout` (seconds), `size`
(`small`/`medium`/`large`/`xlarge`), and `secrets` (which secrets to inject as
`process.env` — list exactly what the function needs).

## Server-side-rendered pages

A file under `src/page/` is an SSR page: the platform renders it to HTML per request
and hydrates it in the browser with the same props. `props(request)` runs server-side
with secrets and `cloud/*` access; returning a response-shaped value (a `redirect()`,
a `notFound()`) short-circuits rendering. Pick your framework per page:

**React** (`src/page/home.tsx`):

```tsx
import { defineReactPage } from "@tothalex/cloud";

type Props = { message: string };

export const Page = ({ message }: Props) => <h1>{message}</h1>;

export default defineReactPage<Props>({
  name: "home",
  route: "/",
  props: async (request) => ({ message: `Hello ${request.query_params.name ?? "World"}` }),
});
```

**Svelte** (`src/page/docs.svelte` + sibling `src/page/docs.ts` config — a `.svelte`
file can't hold the config export; `name`/`route` default from the file stem):

```svelte
<script lang="ts">
  let { topic } = $props();
  let clicks = $state(0);
</script>

<h1>Docs: {topic}</h1>
<button onclick={() => clicks++}>clicked {clicks}</button>

<style>
  h1 { color: rebeccapurple; } /* scoped, ships as a stylesheet automatically */
</style>
```

```ts
import { defineSveltePage } from "@tothalex/cloud";

export default defineSveltePage<{ topic: string }>({
  props: async (request) => ({ topic: request.query_params.topic ?? "intro" }),
});
```

**Solid** (`src/page/board.tsx` — same single-file shape as React; the
`defineSolidPage` call is what marks the page as Solid, and the page's JSX stays in
this one file):

```tsx
/** @jsxImportSource solid-js */
import { createSignal } from "solid-js";
import { defineSolidPage } from "@tothalex/cloud";

type Props = { title: string };

export const Page = (props: Props) => {
  const [n, setN] = createSignal(0);
  return <button onClick={() => setN(n() + 1)}>{props.title}: {n()}</button>;
};

export default defineSolidPage<Props>({
  name: "board",
  route: "/board",
  props: async () => ({ title: "welcome" }),
});
```

## Single-page apps

The SPA entry is `src/index.tsx` (React by default, Solid when it imports `solid-js`)
or `src/index.svelte` (Svelte). The server serves a static shell plus your bundled
assets; the app mounts client-side. Only `route` is read from the config — `"*"` (the
default) makes the SPA the app-wide fallback.

```tsx
// src/index.tsx — React SPA
export const Page: React.FC = () => <div>Hello, World</div>;
export const config = { name: "index", route: "*" };
```

```svelte
<!-- src/index.svelte — Svelte SPA (route in an optional sibling src/index.ts) -->
<script>
  let count = $state(0);
</script>
<button onclick={() => count++}>hits {count}</button>
```

```tsx
/** @jsxImportSource solid-js */
// src/index.tsx — Solid SPA (the solid-js import is what selects Solid)
import { createSignal } from "solid-js";
export const Page = () => {
  const [n, setN] = createSignal(0);
  return <button onClick={() => setN(n() + 1)}>hits {n()}</button>;
};
export const config = { name: "index", route: "*" };
```

## How routing composes

One app can serve API routes, SSR pages, and a routed SPA together. Requests match by
**specificity, not declaration order**: exact path segments beat `:params`, which beat
the `*` catch-all.

- API routes and SSR pages own their exact paths (`/`, `/docs`, `GET /users/:id`).
- An SPA at `route: "*"` takes everything else — including client-router deep links
  like `/account/settings`, which serve the SPA shell so the router can take over.
- Mount an SPA under a subtree with `route: "/app/*"`: it serves `/app`, `/app/`, and
  every path below, while more specific routes still win theirs.

Two rules to remember: the SPA fallback answers GET only (an unmatched POST is still a
404), and an unknown path under an SPA mount returns the shell with status 200 —
"not found" under an SPA mount is the client router's job.

## Performance

Server-render latency per request, measured on the platform's production pipeline and
runtime limits (Apple M4; react 19.2, svelte 5.56, solid-js 1.9; p50 of 100
renders — p95 within ~4% everywhere):

| page | React | Svelte | Solid |
|---|---|---|---|
| simple (~20 elements) | 0.09 ms | 0.02 ms | 0.02 ms |
| medium (100 cards, ~900 elements) | 3.78 ms | 0.78 ms | 1.34 ms |
| heavy (3,200 dynamic cells + deep recursion) | 44.8 ms | 15.0 ms | 11.1 ms |
| server bundle size | ~445 KB | ~54 KB | ~60 KB |
| client assets | ~187 KB | ~35–42 KB | ~10–12 KB |

Svelte and Solid pages render 3–5× faster than React and ship far smaller bundles —
worth preferring for new pages unless you need the React ecosystem.

## What you get

- **Functions**: HTTP routes, cron schedules, and app-internal events, written in
  TypeScript with full inference — request bodies and event payloads are typed from
  their JSON Schemas, and validation runs before your handler does.
- **Runtime modules**: `cloud/postgres` (SQL), `cloud/cache` (KV), `cloud/got` (HTTP),
  `cloud/secret` (secrets + JWT + password hashing), `cloud/event`, `cloud/uuid` — no
  npm dependencies to bundle for the common cases.
- **Sites**: SSR pages and SPAs in React, Svelte, or Solid, deployed alongside your
  functions with live reload in development — no separate frontend toolchain to
  install or configure.
- **Observability**: `nulljs logs --follow`, `nulljs invocations` (with error messages
  on failures), a web dashboard, and a machine-readable API (`/api/openapi.json`).
- **Testing**: handlers are unit-testable in milliseconds with the in-memory `cloud/*`
  doubles from `@tothalex/cloud/testing`.
- **AI-ready**: projects scaffold with agent docs and skills; `nulljs mcp` exposes
  deploy/logs/invoke as MCP tools; `nulljs dev --headless` emits NDJSON events for
  scripts and agents. All read commands take `--json`.
- **Production**: `nulljs serve` runs the same binary as a server; `nulljs host` sets it
  up under systemd. Deploys are signed with a local private key that never leaves your
  machine.

## How it works

The `nulljs` binary embeds the whole platform: a control plane for deploys and
telemetry, and a gateway that routes `{app}.{domain}` requests to your functions,
which execute inside pooled, memory-isolated runtimes with per-function CPU, memory,
and timeout limits. Deploys bundle your TypeScript natively — no Node toolchain
involved — and upload over a signed API, the same API the CLI, dashboard, and MCP
tools all speak.

## License

MIT
