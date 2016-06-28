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

  @doc """
  Handles initial request for LinkedIn authentication.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)
    state =
      conn.params["state"] || Base.encode64(:crypto.strong_rand_bytes(16))

    opts = [scope: scopes,
            state: state,
            redirect_uri: callback_url(conn)]

    redirect!(conn, Ueberauth.Strategy.LinkedIn.OAuth.authorize_url!(opts))
  end

  @doc """
  Handles the callback from LinkedIn.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code,
                                            "state" => state}} = conn) do
    opts = [redirect_uri: callback_url(conn)]
    token = Ueberauth.Strategy.LinkedIn.OAuth.get_token!([code: code], opts)

    send :state_holder, {self, state}

    if token.access_token == nil do
      token_error = token.other_params["error"]
      token_error_description = token.other_params["error_description"]
      set_errors!(conn, [error(token_error, token_error_description)])
    else
      receive do
        {:ok, _state} -> fetch_user(conn, token)
        {:error, reason} -> set_errors!(conn, [error("csrf", reason)])
      end
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc false
  def handle_cleanup!(conn) do
    conn
    |> put_private(:linkedin_user, nil)
    |> put_private(:linkedin_token, nil)
  end

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
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.linkedin_token,
        user: conn.private.linkedin_user
      }
    }
  end

  defp skip_url_encode_option, do: [hackney: [path_encode_fun: fn(a) -> a end]]

  defp user_query do
    "/v1/people/~:(id,picture-url,email-address,firstName,lastName)?format=json"
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :linkedin_token, token)
    resp = OAuth2.AccessToken.get(token, user_query, [], skip_url_encode_option)

    case resp do
      { :ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])
      { :ok, %OAuth2.Response{status_code: status_code, body: user} }
        when status_code in 200..399 ->
          put_private(conn, :linkedin_user, user)
      { :error, %OAuth2.Error{reason: reason} } ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp option(conn, key) do
    Dict.get(options(conn), key, Dict.get(default_options, key))
  end

  defp csrf_protection(initial_state) do
    receive do
      {sender, ^initial_state} -> send sender, {:ok, initial_state}
      {sender, _} -> send sender, {:error, "CSRF token mismatch"}
    end
  end
end
