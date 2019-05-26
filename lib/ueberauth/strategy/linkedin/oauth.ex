defmodule Ueberauth.Strategy.LinkedIn.OAuth do
  @moduledoc """
  OAuth2 for LinkedIn.

  Add `client_id` and `client_secret` to your configuration:

  config :ueberauth, Ueberauth.Strategy.LinkedIn.OAuth,
    client_id: System.get_env("LINKEDIN_CLIENT_ID"),
    client_secret: System.get_env("LINKEDIN_CLIENT_SECRET")
  """
  use OAuth2.Strategy

  @defaults [
     strategy: __MODULE__,
     site: "https://api.linkedin.com",
     authorize_url: "https://www.linkedin.com/oauth/v2/authorization",
     token_url: "https://www.linkedin.com/oauth/v2/accessToken",
  ]

  @doc """
  Construct a client for requests to LinkedIn.

  This will be setup automatically for you in `Ueberauth.Strategy.LinkedIn`.

  These options are only useful for usage outside the normal callback phase of
  Ueberauth.
  """
  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.LinkedIn.OAuth, [])
    opts =
      @defaults
      |> Keyword.merge(config)
      |> Keyword.merge(opts)
    OAuth2.Client.new(opts)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth.
  No need to call this usually.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    scopes = params |> Keyword.get(:scope, "")
    scope_url = "&" <> "scope=" <> URI.encode(scopes)
    ret = opts
    |> client
    |> OAuth2.Client.authorize_url!(params |> Keyword.delete(:scope))
    ret <> scope_url
  end

  def get_token!(params \\ [], opts \\ []) do
    opts
    |> client 
    |> OAuth2.Client.get_token!(params)
  end

  def get(token, url, headers \\ [], opts \\ []) do
    client([token: token])
    |> OAuth2.Client.get(url, headers, opts)
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_param("client_secret", client.client_secret)
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end
end
