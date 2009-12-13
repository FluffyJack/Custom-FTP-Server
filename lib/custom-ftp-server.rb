%w[socket optparse ostruct lib/functions.rb].each  { |f| require f }

Thread.abort_on_exception = true

class CustomFTPServer
  
  # == The main class
  #   This is the class that actually runs the server process that is started in init.rb
  #   Usually you won't have to customise this file, and it's recommended that you don't.
  # 
  # == Customising the server
  #   This is how you customise the server, the core functions, and add extra functions to the core
  #   This is *NOT* how you customise FTP commands and please don't try to follow these steps to cusomise those
  #   
  #   1. Create a new file to put those functions in and add that file to the array at the top of custom-ftp-server.rb
  #   2. In that file you created, make a new module with whatever name you want and add your functions to it
  #   3. Include that module at the end of this class (Class CustomFTPServer)
  #   
  # == Getting your new functions into the core library
  #   If you think you've got something that could really contribute to the core of this library, send me a message on github telling me what you think and I'll have a look at it.
  #   
  # == Developers Info
  #   If your wanting to make some changes that you think would be good, or have found a bug you think you can fix, please fork my git on github and make your changes and send me a pull request.
  #   If you have any questions about what your doing, send me a message on github and I'll help you out.
  
  #--
  #  
  # == Internal Notes (not tracked by RDoc)
  #   If you want to take notes on something, put it in here, e.g. for To Do lists
  # 
  # == TODO
  # 
  #   * Need to work out the difference between passive and active and then implement both
  #   * Has issues with larger files (over 1024 bytes)
  #   * Error on connection timeout
  #   * Create all RFC 959 commands
  #   * Add all commands from RFC 959 extensions RFC 2228, RFC 3659, and RFC 4217
  #   * Test on a server
  #   * Test with other FTP clients
  #   
  #++
  
  
  VERSION = '0.1.4'

  # == Creates a CustomFTPServer
  #   This will create a new CustomFTPServer Object and will make start a TCPServer
  #   It does not start a loop for listening though, this must be done using CustomFTPServer.run()
  #   
  #   It sets up some default options, and calls the functions needed to set the chosen ones and will move to the "root" directory chosen
  #   
  def initialize(arguments)
    @arguments = arguments
    
    # Set defaults
    @options = OpenStruct.new
    @options.host = "127.0.0.1"
    @options.port = 21
    @options.root = "/"
    
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
    
    # Choose a root
    Dir.chdir(@options.root)
    
  end

  # == The server loop
  #   This functions starts up the loop to accept incomming connections and threads, it also calls a function that starts up thread management that will make sure threads don't just sit open when they're not being used.
  #   
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
        thread[:mode] = :binary
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
    
    # Call commands and return the response to the client
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
          when *PATHCOMMANDS
            __send__ command, real_folder(message)
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
  
    # Periodically kill inactive connections
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
    
    # Command not understood
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
      opts.on('--root ROOT')        { |root| @options.root = root; }
            
      opts.parse!(@arguments) rescue return false
      
      true      
    end
    
    # When using option -v or --version, this will output the current version
    def output_version
      puts "#{File.basename(__FILE__)} version #{VERSION}"
    end
    
    # Send data over a connection
    def send_data(data)
      bytes = 0
      begin
        data.each do |line|
          if thread[:mode] == :binary
            thread[:datasocket].syswrite(line)
          else
            puts line
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
    
    # Create virtual folder string
    def virtual_folder(folder)
      f_array = (folder.sub(@options.root, "")).split("/")
      if (f_array.length > 1)
        f_array = f_array.delete_if { |c| c.empty? or c.nil? or c == "" }
        return f_array.join("/")
      elsif (f_array.length == 0)
        return "/"
      else
        return folder
      end
    end
    
    # Find real folder
    def real_folder(folder)
      f_array = (Dir.pwd + "/" + folder).split("/")
      if (folder[0,1] == "/")
        return @options.root + folder
      elsif (f_array.length > 1)
        f_array = f_array.delete_if { |c| c.empty? or c.nil? or c == "" }
        return "/" + f_array.join("/")
      elsif (folder == "/")
        return @options.root
      else
        return folder
      end
    end
    
    # Functions Module
    include(CustomFTPServerFunctions)
    
end