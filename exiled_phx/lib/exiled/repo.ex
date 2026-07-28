defmodule Exiled.Repo do
  use Ecto.Repo,
    otp_app: :exiled,
    adapter: Ecto.Adapters.Postgres
end
