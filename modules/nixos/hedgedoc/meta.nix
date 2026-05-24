{
  name = "hedgedoc";
  description = "HedgeDoc collaborative markdown editor with nginx reverse proxy";
  category = "services";
  tags = [ "hedgedoc" "markdown" "collaboration" "nginx" ];
  provides = [ "my.services.hedgedoc" ];
  expects = [ "my.secrets" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
  homepage = "https://hedgedoc.org";
}
