defmodule Ueberauth.Strategy.LinkedIn do
  @moduledoc """
  LinkedIn Strategy for Überauth.
  """

  use Ueberauth.Strategy,
    uid_field: :id,
    default_scope: "r_basicprofile r_emailaddress"

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @state_cookie_name "ueberauth_linkedin_state"

  @doc """
  Handles initial request for LinkedIn authentication.
  """
  def handle_request!(conn) do
    state = conn.params["state"] || Base.encode64(:crypto.strong_rand_bytes(16))

    conn
    |> put_resp_cookie(@state_cookie_name, state)
    |> redirect!(
      Ueberauth.Strategy.LinkedIn.OAuth.authorize_url!(
        scope: conn.params["scope"] || option(conn, :default_scope),
        state: state,
        redirect_uri: callback_url(conn)
      )
    )
  end

  @doc """
  Handles the callback from LinkedIn.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code, "state" => state}} = conn) do
    opts = [redirect_uri: callback_url(conn)]

    %OAuth2.Client{token: token} =
      Ueberauth.Strategy.LinkedIn.OAuth.get_token!([code: code], opts)

    if token.access_token == nil do
      conn
      |> delete_resp_cookie(@state_cookie_name)
      |> set_errors!([
        error(
          token.other_params["error"],
          token.other_params["error_description"]
        )
      ])
    else
      if conn.cookies[@state_cookie_name] == state do
        conn
        |> delete_resp_cookie(@state_cookie_name)
        |> fetch_user(token)
      else
        conn
        |> delete_resp_cookie(@state_cookie_name)
        |> set_errors!([error("csrf", "CSRF token mismatch")])
      end
    end
  end

  @doc false
  def handle_callback!(conn),
    do:
      conn
      |> delete_resp_cookie(@state_cookie_name)
      |> set_errors!([error("missing_code", "No code received")])

  @doc false
  def handle_cleanup!(conn),
    do:
      conn
      |> put_private(:linkedin_user, nil)
      |> put_private(:linkedin_token, nil)

  @doc """
  Fetches the uid field from the response.
  """
  def uid(conn) do
    uid_field =
      conn
      |> option(:uid_field)
      |> to_string

    conn.private.linkedin_user[uid_field]
  end

  @doc """
  Includes the credentials from the linkedin response.
  """
  def credentials(conn) do
    token = conn.private.linkedin_token

    %Credentials{
      expires: !!token.expires_at,
      expires_at: token.expires_at,
      refresh_token: token.refresh_token,
      token: token.access_token
    }
  end

  @doc """
  Fetches the fields to populate the info section of `Ueberauth.Auth` struct.
  """
  def info(conn) do
    user = conn.private.linkedin_user

    %Info{
      email: user["emailAddress"],
      first_name: user["firstName"],
      image: user["pictureUrl"],
      last_name: user["lastName"]
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from
  the linkedin callback.
  """
  def extra(conn),
    do: %Extra{
      raw_info: %{
        token: conn.private.linkedin_token,
        user: conn.private.linkedin_user
      }
    }

  defp skip_url_encode_option, do: [path_encode_fun: fn a -> a end]

  defp fetch_user(conn, token) do
    conn = put_private(conn, :linkedin_token, token)

    token
    |> Ueberauth.Strategy.LinkedIn.OAuth.get("/v2/me", [], skip_url_encode_option())
    |> case do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        put_private(conn, :linkedin_user, user)

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp option(conn, key) do
    Dict.get(options(conn), key, Dict.get(default_options(), key))
  end
end
