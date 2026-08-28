defmodule QuicklimeWeb.PageController do
  use QuicklimeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
