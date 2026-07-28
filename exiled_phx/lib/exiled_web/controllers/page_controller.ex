defmodule ExiledWeb.PageController do
  use ExiledWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
