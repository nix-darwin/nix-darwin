
{ config, pkgs, ... }:

{
  networking.computerName = "\"Quotey McQuote's Macbook Pro\"";
  networking.hostName = "\"Quotey-McQuote's-Macbook-Pro\"";

  test = ''
    echo checking hostname in /activate >&2
    grep "scutil --set ComputerName '"\""Quotey McQuote's Macbook Pro"\""'" ${config.out}/activate
    grep "scutil --set LocalHostName '"\""Quotey-McQuote's-Macbook-Pro"\""'" ${config.out}/activate
    grep "scutil --set HostName "'"\""Quotey-McQuote's-Macbook-Pro"\""'"  ${config.out}/activate
  '';
}
