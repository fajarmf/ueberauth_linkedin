defmodule UeberauthLinkedinTest do
  use ExUnit.Case
  doctest UeberauthLinkedin

  test "Scope must be separated by spaces and encoded as URI (empty)" do
    result = Ueberauth.Strategy.LinkedIn.OAuth.authorize_url!([])
    assert(result == scope_empty_uri)
  end

  test "Scope must be separated by spaces and encoded as URI (default)" do
    result = Ueberauth.Strategy.LinkedIn.OAuth.authorize_url!(scope_default)
    %{ "scope" => scope } = URI.decode_query(result)
    assert(result == scope_default_uri)
    assert(scope == "r_liteprofile r_emailaddress w_member_social")
    assert(result != scope_default_uri_plus)
  end

  defp scope_default do
    [scope: "r_liteprofile r_emailaddress w_member_social"]
  end
  
  defp scope_empty_uri do
    "https://www.linkedin.com/oauth/v2/authorization?client_id=&redirect_uri=" <>
      "&response_type=code&scope="
  end
  
  defp scope_default_uri do
    "https://www.linkedin.com/oauth/v2/authorization?client_id=&redirect_uri=" <>
      "&response_type=code&scope=r_liteprofile%20r_emailaddress%20w_member_social"
  end

  defp scope_default_uri_plus do
    "https://www.linkedin.com/oauth/v2/authorization?client_id=&redirect_uri=" <>
      "&response_type=code&scope=r_liteprofile+r_emailaddress+w_member_social"
  end
end
