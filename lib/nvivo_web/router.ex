defmodule NvivoWeb.Router do
  use NvivoWeb, :router

  import NvivoWeb.UsersAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NvivoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_users
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", NvivoWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Chat room routes - available to all users (logged in and guests)
    live_session :chat_rooms,
      on_mount: [{NvivoWeb.UsersAuth, :mount_current_users}] do
      live "/chat_rooms", ChatRoomLive.Index, :index
      live "/chat_rooms/new", ChatRoomLive.Index, :new
      live "/chat_rooms/:room_code", ChatRoomLive.Show, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", NvivoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:nvivo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: NvivoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", NvivoWeb do
    pipe_through [:browser, :redirect_if_users_is_authenticated]

    live_session :redirect_if_users_is_authenticated,
      on_mount: [{NvivoWeb.UsersAuth, :redirect_if_users_is_authenticated}] do
      live "/users/register", UsersRegistrationLive, :new
      live "/users/log_in", UsersLoginLive, :new
      live "/users/reset_password", UsersForgotPasswordLive, :new
      live "/users/reset_password/:token", UsersResetPasswordLive, :edit
    end

    post "/users/log_in", UsersSessionController, :create
  end

  scope "/", NvivoWeb do
    pipe_through [:browser, :require_authenticated_users]

    live_session :require_authenticated_users,
      on_mount: [{NvivoWeb.UsersAuth, :ensure_authenticated}] do
      live "/users/settings", UsersSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UsersSettingsLive, :confirm_email
    end
  end

  scope "/", NvivoWeb do
    pipe_through [:browser]

    delete "/users/log_out", UsersSessionController, :delete

    live_session :current_users,
      on_mount: [{NvivoWeb.UsersAuth, :mount_current_users}] do
      live "/users/confirm/:token", UsersConfirmationLive, :edit
      live "/users/confirm", UsersConfirmationInstructionsLive, :new
    end
  end
end
