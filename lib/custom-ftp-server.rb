%w[socket logger optparse ostruct functions.rb].each  { |f| require f }

Thread.abort_on_exception = true

class CustomFTPServer
  VERSION = '0.1.1'
  
  # FTP says this is the end of a line
  LNBR = "\r\n"

  # Supported Commands
  COMMANDS = %w[user quit port type mode stru retr stor noop syst pass list nlst pwd cwd dele rmd mkd]

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
    #trap('INT') { puts "\n\nShutting down server..."; @status = :dead; Thread.exit }
    
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
    @threads = []
    
    kill_dead_connections
    
    while (@status == :alive)
      
        begin
          session = @server.accept
          @threads << new_connection_thread(session)
        rescue Interrupt
          @status = :dead
          puts "\n\nShutting down server..."
        rescue Exception => ex
          @status = :dead
          puts "#{ex.class}: #{ex.message} - \n\t#{ex.backtrace[0]}"
          exit(0)
        end

    end
      
  end
  
  protected
  
    # Creates a new thread for people to work on
    def new_connection_thread(session)
      Thread.new(session) do |session|
        thread[:session] = session
        thread[:mode] = :ascii
        client_info = session.peeraddr
        thread[:addr] = [client_info[1], client_info[3]]
        response "220 Connection Established"
        
        # listen for commands
        while session.nil? == false and session.closed? == false
          puts "Command start"
          request = session.gets
          puts "#{request}"
          reply = handler(request)
          puts reply
          response reply
        end
        
      end
    end
    
    # call commands and return the response to the client
    def handler(request)
      thread[:stamp] = Time.now
      return if request.nil? or request.to_s == ''
      
      begin
        command = request[0,4].downcase.strip
        rqarray = request.split(' ')
        message = rqarray.length > 2 ? rqarray[1..rqarray.length].join(' ') : rqarray[1]
        case command
          when *COMMANDS
            __send__ command, message
          else
            bad_command command, message
        end
      rescue Errno::EACCES, Errno::EPERM
        "553 Permission denied"
      rescue Errno::ENOENT
        "553 File doesn't exist"
      rescue Exception => e
        "500 Server Error: #{e.class}: #{e.message} - \n\t#{e.backtrace[0]}"
      end
      
    end
  
    # Send data back to the client
    def response(msg)
      session = thread[:session]
      session.print msg << LNBR unless msg.nil? or session.nil? or session.closed?
      session.print "500 Server Error" if msg.nil?
    end
  
    # periodically kill inactive connections
    def kill_dead_connections
      Thread.new do
        loop do
          @threads.delete_if do |t|
            if Time.now - t[:stamp] > 400
              t[:session].close
              t.kill
              debug "Killed inactive connection."
              true
            end
          end
          sleep 20
        end
      end    
    end
    
    # Returns current thread
    def thread; Thread.current; end
    
    # command not understood
    def bad_command(name, *params)
      "502 Command not implemented"
    end
  
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
    
    # send data over a connection
    def send_data(data)
      bytes = 0
      begin
        data.each do |line|
          if thread[:mode] == :binary
            thread[:datasocket].syswrite(line)
          else
            thread[:datasocket].send(line, 0)
          end
          bytes += line.length
        end
      rescue Errno::EPIPE 
        return quit
      else
        # do nothing
      ensure
        thread[:datasocket].close
        thread[:datasocket] = nil    
      end
      bytes
    end
    
    # Functions Module
    include(CustomFTPServerFunctions)
    
end