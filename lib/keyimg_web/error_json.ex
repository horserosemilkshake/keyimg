defmodule KeyimgWeb.ErrorJSON do
  def render("404.json", _assigns), do: %{error: "not_found"}
  def render("500.json", _assigns), do: %{error: "internal_error"}
end
