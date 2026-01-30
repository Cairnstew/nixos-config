{ flake, config, pkgs, ... }:

let
  inherit (flake) inputs;
in
{

  programs.firefox = {

  	enable = true;

  	profiles.${flake.config.me.username} = {
  	  isDefault	= true;

  	  bookmarks = {
  	  			force = true;
  	    		settings = [
  	    		  {
  	    		    name = "wikipedia";
  	    		    tags = [ "wiki" ];
  	    		    keyword = "wiki";
  	    		    url = "https://en.wikipedia.org/wiki/Special:Search?search=%s&amp;go=Go";
  	    		  }
  	    		  {
  	    		    name = "kernel.org";
  	    		    url = "https://www.kernel.org";
  	    		  }
  	    		  "separator"
  	    		  {
  	    		    name = "Nix sites";
  	    		    toolbar = true;
  	    		    bookmarks = [
  	    		      {
  	    		        name = "homepage";
  	    		        url = "https://nixos.org/";
  	    		      }
  	    		      {
  	    		        name = "wiki";
  	    		        tags = [ "wiki" "nix" ];
  	    		        url = "https://wiki.nixos.org/";
  	    		      }
  	    		    ];
  	    		  }
  	    		];
  	};
  	
  		
  	};
  	
  };

  

}
