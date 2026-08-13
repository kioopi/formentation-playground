defmodule FrmnPlayWeb.PageController do
  use FrmnPlayWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
