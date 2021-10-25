defmodule Ueberauth.Strategy.LinkedIn do
  @moduledoc """
  LinkedIn Strategy for Überauth.
  """
  @user_url "https://api.linkedin.com/v2/me?projection=(id,localizedFirstName,localizedLastName,profilePicture(displayImage~:playableStreams))"
  @primary_contact_url "https://api.linkedin.com/v2/clientAwareMemberHandles?q=members&projection=(elements*(primary,type,handle~))"

  use Ueberauth.Strategy,
    uid_field: :id,
    default_scope: "r_liteprofile r_emailaddress"

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @doc """
  Handles initial request for LinkedIn authentication.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)

    opts =
      [scope: scopes, redirect_uri: callback_url(conn)]
      |> with_state_param(conn)

    redirect!(conn, Ueberauth.Strategy.LinkedIn.OAuth.authorize_url!(opts))
  end

  @doc """
  Handles the callback from LinkedIn.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    opts = [redirect_uri: callback_url(conn)]

    %OAuth2.Client{token: token} =
      Ueberauth.Strategy.LinkedIn.OAuth.get_token!([code: code], opts)

    if token.access_token == nil do
      token_error = token.other_params["error"]
      token_error_description = token.other_params["error_description"]

      set_errors!(conn, [error(token_error, token_error_description)])
    else
      conn
      |> fetch_user(token)
      |> fetch_primary_contact()
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
    primary_contact = conn.private.linkedin_primary_contact

    %Info{
      first_name: user["localizedFirstName"],
      image: info_image(user),
      last_name: user["localizedLastName"],
      email: email_from_primary_contact(primary_contact)
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
        user: conn.private.linkedin_user,
        primary_contact: conn.private.linkedin_primary_contact
      }
    }
  end

  defp skip_url_encode_option, do: [path_encode_fun: fn a -> a end]

  defp fetch_user(conn, token) do
    conn = put_private(conn, :linkedin_token, token)
    resp = Ueberauth.Strategy.LinkedIn.OAuth.get(token, @user_url, [], skip_url_encode_option())

    case resp do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        put_private(conn, :linkedin_user, user)

      {:error, %OAuth2.Response{status_code: 403, body: body}} ->
        set_errors!(conn, [error("token", body.message)])

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp fetch_primary_contact(conn) do
    token = conn.private.linkedin_token

    resp =
      Ueberauth.Strategy.LinkedIn.OAuth.get(
        token,
        @primary_contact_url,
        [],
        skip_url_encode_option()
      )

    case resp do
      {:ok, %OAuth2.Response{status_code: status_code, body: primary_contact}}
      when status_code in 200..399 ->
        put_private(conn, :linkedin_primary_contact, primary_contact)

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp info_image(%{"profilePicture" => profilePicture} = _user) do
    profilePicture
    |> get_in(["displayImage~", "elements"])
    |> List.last()
    |> get_in(["identifiers"])
    |> List.last()
    |> get_in(["identifier"])
  end

  defp info_image(_user), do: nil

  defp email_from_primary_contact(primary_contact) do
    email_element =
      primary_contact["elements"]
      |> Enum.find(fn element ->
        element["primary"] == true && element["type"] == "EMAIL"
      end)

    if email = email_element |> get_in(["handle~", "emailAddress"]), do: email, else: nil
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
