{ variables, ... }:

{
  home.username = "${variables.username}";
  home.homeDirectory = "/home/${variables.username}";
}
