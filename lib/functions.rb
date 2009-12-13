module CustomFTPServerFunctions
  
  # Standard newline code
  LNBR = "\r\n"
  
  # Supported Non-File Commands
  COMMANDS = %w[user quit port type mode stru noop syst pass list nlst pwd]
  
  # Supported File Commands
  PATHCOMMANDS = %w[cwd dele mkd rmd rnfr rnto retr stor]
  
  # == USER
  #   
  #   This gets a user name and checks if it is a current user
  #   
  #   This will return:
  #   [Sucessful]   331 Username is correct, still need a password
  #   [Failed]      530 Username is incorrect
  #
  def user(msg)  #   :yields: username
    return "530 Username is incorrect" if msg != 'fluffyjack'
    thread[:user] = msg
    "331 Username is correct, still need a password"
  end
  
  # == PASS
  #   
  #   This gets a password and checks if it is the specified users password
  #   
  #   This will return:
  #   [Sucessful]   230 Logged in successfully
  #   [Failed]      530 Password is incorrect
  #
  def pass(msg)  #   :yields: password
    return "530 Password is incorrect" if msg != 'password'
    thread[:pass] = msg
    "230 Logged in successfully"
  end
  
  # == QUIT
  #   
  #   Destroys connections and ends the thread
  #   
  #   This will return:
  #   [Sucessful]   221 Logged out successfully
  #
  def quit(msg)  #   :yields: nil
    thread[:session].close
    thread[:session] = nil
    "221 Logged out successfully"
  end
  
  # == PORT
  #   
  #   Opens up a data-connection port to use for data transport
  #   
  #   This will return:
  #   [Sucessful]   200 Passive connection established (#{port})
  #
  def port(msg)  #   :yields: socket address
    nums = msg.split(',')
    port = nums[4].to_i * 256 + nums[5].to_i
    host = nums[0..3].join('.')
    if thread[:datasocket]
      thread[:datasocket].close
      thread[:datasocket] = nil
    end
    thread[:datasocket] = TCPSocket.new(host, port)
    "200 Passive connection established (#{port})"
  end
  
  # == TYPE
  #   
  #   Changes transfer data type
  #   
  #   This will return:
  #   [Sucessful - ASCII]   200 Type set to ASCII
  #   [Succesful - Binary]  200 Type set to binary
  #
  def type(msg)  #   :yields: type
    if (msg == 'A')
      thread[:mode] = :ascii
      "200 Type set to ASCII"
    elsif (msg == 'I')
      thread[:mode] = :binary
      "200 Type set to binary"
    end
  end
  
  # == MODE
  #   
  #   Changes transfer mode, currently only accepts STREAM
  #   
  #   This will return:
  #   [Always]   202 Only accepts stream
  #
  def mode(msg); "202 Only accepts stream"; end  #   :yields: mode
  
  # == STRU
  #   
  #   Changes transfer structure, currently only accepts FILE
  #   
  #   This will return:
  #   [Always]   202 Only accepts file
  #
  def stru(msg); "202 Only accepts file"; end  #   :yields: structure
  
  # == RETR
  #   
  #   Sends a file to the user client
  #   
  #   This will return:
  #   [On Start]    125 Data transfer starting
  #   [On Complete] 226 Closing data connection, sent #{bytes} bytes
  #
  def retr(msg)  #   :yields: mode
    response "125 Data transfer starting"
    bytes = send_data(File.new(msg, 'r'))
    "226 Closing data connection, sent #{bytes} bytes"      
  end
  
  # == STOR
  #   
  #   Receives a file from the user client
  #   
  #   This will return:
  #   [On Start]    125 Data transfer starting
  #   [On Complete] 226 Closing data connection, sent #{bytes} bytes
  #
  def stor(msg)  #   :yields: mode
    file = File.open(msg, 'w')
    response "125 Data transfer starting"
    bytes = 0
    while (data = thread[:datasocket].recv(1024))
      if (data.nil? or data.empty? or data == "")
        file.close
        return "226 Closing data connection, sent #{bytes} bytes"
      else
        bytes += file.write data
      end
    end
  end
  
  # == NOOP
  #   
  #   Wants a 200 reply
  #   
  #   This will return:
  #   [Always]    200
  #
  def noop(msg); "200 "; end  #   :yields: nil
  
  # == SYST
  #   
  #   Asks for server description
  #   
  #   This will return:
  #   [Always]    215 FluffyJack's Custom FTP Server v#{VERSION}
  #
  def syst(msg); "215 FluffyJack's Custom FTP Server v#{VERSION}"; end  #   :yields: nil
    
  # == LIST
  #   
  #   Asks for a list of files in the current working directory to be sent to the user client
  #   
  #   This will return:
  #   [On Start]    125 Opening ASCII mode data connection for file list
  #   [On Complete] 226 Transfer complete
  #
  def list(msg)  #   :yields: nil
    response "125 Opening ASCII mode data connection for file list"
    send_data(`ls -l`.split("\n").join(LNBR) << LNBR)
    "226 Transfer complete"
  end

  # == NLST
  #   
  #   Sends a list of all file names in the currect working directory
  #
  def nlst(msg)  #   :yields: nil
    Dir["*"].join " "   
  end
  
  # == PWD
  #   
  #   Sends the user client the current working directory
  #
  def pwd(msg)  #   :yields: nil 
    %[257 "#{virtual_folder(Dir.pwd)}" is the current directory]
  end
  
  # == CWD
  #   
  #   Changes the current working directory to the one asked for
  #   
  #   This will return:
  #   [Successful]  250 Directory changed to #{virtual_folder(Dir.pwd)}
  #   [Failed] 550 Directory not found
  #
  def cwd(msg)  #   :yields: directory
    begin
      Dir.chdir(msg)
    rescue Errno::ENOENT
      "550 Directory not found"
    else 
      "250 Directory changed to " << virtual_folder(Dir.pwd)
    end
  end
  
  # == DELE
  #   
  #   Deletes a file
  #   
  #   This will return:
  #   [Successful]  200 OK, deleted #{virtual_folder(msg)}
  #
  def dele(msg); rmd(msg); end  #   :yields: file

  # == RMD
  #   
  #   Deletes a directory
  #   
  #   This will return:
  #   [Successful]  200 OK, deleted #{virtual_folder(msg)}
  #
  def rmd(msg)  #   :yields: directory or file
    if File.directory? msg
      Dir::delete msg
    elsif File.file? msg
      File::delete msg
    end
    "200 OK, deleted #{virtual_folder(msg)}"
  end
  
  # == MKD
  #   
  #   Creates a directory
  #   
  #   This will return:
  #   [Successful]  257 #{virtual_folder(msg)} created
  #
  def mkd(msg)  #   :yields: directory
    Dir.mkdir(msg)
    "257 #{virtual_folder(msg)} created"
  end
  
  # == RNFR
  #   
  #   Part 1 of renaming a file or folder, stores the file to be renamed in thread[:rnfr]
  #   
  #   This will return:
  #   [Successful]  350 Awating RNTO for file
  #
  def rnfr(msg) #   :yields: file or directory
    thread[:rnfr] = msg
    "350 Awating RNTO for file"
  end
  
  # == RNTO
  #   
  #   Part 2 of renaming a file or folder, renames file or directory thread[:rnfr] to specified name
  #   
  #   This will return:
  #   [Successful]  250 File renamed to #{virtual_folder(msg)}
  #
  def rnto(msg)  #   :yields: file or directory
    File.rename(thread[:rnfr], msg)
    thread[:rnfr] = nil
    "250 File renamed to #{virtual_folder(msg)}"
  end
  
end