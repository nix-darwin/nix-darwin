
{ config, pkgs, ... }:

{
  networking.computerName = "\"Quotey McQuote's Macbook Pro\"";

  test = ''
    echo checking hostname in /activate >&2
    grep -F "scutil --set ComputerName '\"Quotey McQuote'\'''s Macbook Pro\"'" ${config.out}/activate
  '';
}
