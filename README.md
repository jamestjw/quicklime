# Quicklime

Quicklime is an always-running regional reaction game. An Elm client renders the arena while a supervised Phoenix process owns game timing, scoring, and first-click arbitration.

## Run locally

Requirements:

- Elixir 1.15 or newer
- Erlang/OTP 26 or newer
- Node.js 22 or newer

Install dependencies and build the assets:

```sh
mix setup
```

Start the development server:

```sh
mix phx.server
```

Visit [localhost:4000](http://localhost:4000). The server is expected to keep running until stopped with `Ctrl+C`.

## Architecture

- `Quicklime.Game` contains pure authoritative game-state transitions.
- `Quicklime.RegionalGame` owns the live regional match, timers, and reconnect grace.
- `QuicklimeWeb.GameChannel` validates players and forwards tile claims.
- `assets/src/Main.elm` owns client state and rendering.
- `assets/js/app.js` is the narrow Phoenix Socket to Elm ports bridge.

Claims are processed by the regional game server in arrival order. The first correct claim scores 100 points, every wrong claim costs 40 points, and players can keep trying until the tile is won. Disconnected players retain their score for 20 seconds.

## Checks

```sh
mix precommit
mix assets.build
npm --prefix assets run build:elm:optimize
```
