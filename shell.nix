{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    jq
    nmap
    sqlcmd 
  ];

  shellHook = ''
    echo "Development environment loaded with:"
    echo "- jq: JSON processor"
    echo "- nmap: Network security scanner"
    echo "- sqlcmd: Microsoft SQL Server"
  '';
}
