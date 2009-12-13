# == Synopsis 
#   Custom FTP Server is a command line based Ruby FTP Server solution that allows you to customise how it reacts to FTP commands
#
# == Examples
#   ruby init.rb
#   ruby init.rb --host 127.0.0.1 --port 21
#   ruby init.rb --root "/root/websites/website_root"
#
# == Usage 
#   cd /your/custom-ftp-server/folder
#   ruby init.rb [options]
#
# == Options
#   -v, --version       Display the version, then exit
#   --port              Set a port to use
#   --host              Set a host to use
#   --root              Set a root directory to use
#
# == Author
#   FluffyJack - Jack Dean Watson-Hamblin
#
# == Copyright
#   Copyright (c) 2009 Jack Dean Watson-Hamblin. Licensed under the MIT License:
#   http://www.opensource.org/licenses/mit-license.php

# Include libraries
require File.join(File.dirname(__FILE__), "lib", "custom-ftp-server")

# Create and run the application
ftpserver = CustomFTPServer.new(ARGV)
ftpserver.run