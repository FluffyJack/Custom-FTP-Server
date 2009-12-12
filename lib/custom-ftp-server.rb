%w[socket logger optparse ostruct].each  { |f| require f }

class CustomFTPServer
  VERSION = '0.0.1'
  
  # FTP says this is the end of a line
  LNBR = "\r\n"

  # Parse Options, Open a server, and look out for shut down
  def initialize(arguments)
    @arguments = arguments
    
    # Set defaults
    @options = OpenStruct.new
    @options.host = "127.0.0.1"
    @options.port = 21
    
    # Set custom options
    parse_options
    
    # Setup Exit Shortcut
    trap('INT') { puts "\n\nShutting down server..."; @status = :dead; Thread.exit }
    
    # Start a server
    begin
      @server = TCPServer.new(@options.host, @options.port)
    rescue Errno::EADDRINUSE
      puts "The address is already in use"
      exit(0)
    rescue Errno::EACCES
      puts "The port is already in use"
      exit(0)
    end
    
  end

  # The server process
  def run
    
    # Explain how to shut down server
    puts "Server starting up...\n"
    puts "To shut down server press ctrl+c"
    
    @status = :alive
    
    while (@status == :alive)
      
      Thread.start(@server.accept) do |session|
        
        
        
      end

    end
      
  end
  
  protected
  
    # Parse the option passed through the command line
    def parse_options
      
      # Specify options
      opts = OptionParser.new 
      opts.on('-v', '--version')    { output_version; exit 0 }
      opts.on('--host HOST')        { |host| @options.host = host; }
      opts.on('--port PORT')        { |port| @options.port = port; }
            
      opts.parse!(@arguments) rescue return false
      
      true      
    end
    
    # When using option -v or --version, this will output the current version
    def output_version
      puts "#{File.basename(__FILE__)} version #{VERSION}"
    end
    
end