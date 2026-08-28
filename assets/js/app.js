import "phoenix_html"
import { Socket } from "phoenix"
import { Elm } from "../elm.js"

const node = document.getElementById("quicklime-app")

if (node) {
  const app = Elm.Main.init({node})
  const sessionKey = "quicklime:session-id"
  let sessionId = sessionStorage.getItem(sessionKey)
  let socket = null
  let channel = null

  if (!sessionId) {
    sessionId = crypto.randomUUID()
    sessionStorage.setItem(sessionKey, sessionId)
  }

  const send = (event) => app.ports.socketEvent.send(event)

  const connect = (name) => {
    if (!socket) {
      socket = new Socket("/socket")
      socket.onOpen(() => send({type: "connection", status: "connected"}))
      socket.onError(() => send({type: "connection", status: "disconnected"}))
      socket.onClose(() => send({type: "connection", status: "disconnected"}))
      socket.connect()
    }

    if (channel) {
      channel.leave()
    }

    send({type: "connection", status: "connecting"})
    channel = socket.channel("game:regional", {name, session_id: sessionId})

    channel.on("tile_opened", payload => send({...payload, type: "tile_opened"}))
    channel.on("tile_won", payload => send({...payload, type: "tile_won"}))
    channel.on("tile_expired", payload => send({...payload, type: "tile_expired"}))
    channel.on("leaderboard", payload => send({...payload, type: "leaderboard"}))

    channel.join()
      .receive("ok", payload => send({...payload, type: "joined"}))
      .receive("error", payload => send({...payload, type: "join_error"}))
  }

  app.ports.socketCommand.subscribe(command => {
    if (command.action === "join") {
      connect(command.name)
    }

    if (command.action === "claim" && channel) {
      channel.push("claim_tile", {
        tile_id: command.tileId,
        tile_index: command.tileIndex,
      })
        .receive("ok", payload => send({...payload, type: "claim_result"}))
        .receive("error", payload => send({...payload, type: "claim_error"}))
    }
  })
}
