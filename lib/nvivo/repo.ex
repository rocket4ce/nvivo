defmodule Nvivo.Repo do
  use Ecto.Repo,
    otp_app: :nvivo,
    adapter: Ecto.Adapters.Postgres
end
