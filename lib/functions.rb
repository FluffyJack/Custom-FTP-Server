module CustomFTPServerFunctions
  
  # ftp says this is a new line
  LNBR = "\r\n"
  
  # Supported Commands
  COMMANDS = %w[user quit port type mode stru retr stor noop syst pass list nlst pwd cwd dele rmd mkd]
  
  # USER - msg = username
  def user(msg)
    return "530 Username is incorrect" if msg != 'fluffyjack'
    thread[:user] = msg
    "331 Username is correct, still need a password"
  end
  
  # PASS - msg = password
  def pass(msg)
    return "530 Password is incorrect" if msg != 'password'
    thread[:pass] = msg
    "230 Logged in successfully"
  end
  
  # QUIT - msg = nil
  def quit(msg)
    thread[:session].close
    thread[:session] = nil
    "221 Logged out successfully"
  end
  
  # PORT - msg = new port details
  def port(msg)
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
  
  # TYPE - msg = type (A = ascii, I = binary)
  def type(msg)
    if (msg == 'A')
      thread[:mode] = :ascii
      "200 Type set to ASCII"
    elsif (msg == 'I')
      thread[:mode] = :binary
      "200 Type set to binary"
    end
  end
  
  # MODE - msg = mode-code
  def mode(msg); "202 Only accepts stream"; end
  
  # STRU - msg = structure code
  def stru(msg); "202 Only accepts file"; end
  
  # RETR - msg = pathname
  def retr(msg)
    response "125 Data transfer starting"
    bytes = send_data(File.new(msg, 'r'))
    "226 Closing data connection, sent #{bytes} bytes"      
  end
  
  # STOR - msg = pathname
  def stor(msg)
    file = File.new(msg, 'w')
    response "125 Data transfer starting"
    bytes = 0
    data = thread[:datasocket].recvfrom(1024)
    bytes += data.length
    file.write data
    "226 Files recieved - total bytes #{bytes}"
  end
  
  # NOOP - msg = nil
  def noop(msg); "200 "; end
  
  # SYST - msg = nil
  def syst(msg); "215 FluffyJack's Custom FTP Server v#{VERSION}"; end
    
  # LIST - msg = nil
  def list(msg)
    response "125 Opening ASCII mode data connection for file list"
    
    # Dir["*"].each do |entry|
    #   file_data[] = ""
    #   
    #   data_lines[] = file_data.join(' ')
    # end
    # 
    # send_data(data_lines.join(LNBR) << LNBR)
    
    send_data(`ls -l`.split("\n").join(LNBR) << LNBR)
    
    "226 Transfer complete"
  end

  # NLST - msg = nil
  def nlst(msg)
    Dir["*"].join " "   
  end
  
  # PWD - msg = nil
  def pwd(msg)
    %[257 "#{Dir.pwd}" is the current directory]
  end
  
  # CWD - msg = pathname
  def cwd(msg)
    begin
      Dir.chdir(msg)
    rescue Errno::ENOENT
      "550 Directory not found"
    else 
      "250 Directory changed to " << Dir.pwd
    end
  end
  
  # DELE - msg = pathname
  def dele(msg); rmd(msg); end

  # RMD - msg = pathname (also runs DELE code)
  def rmd(msg)
    if File.directory? msg
      Dir::delete msg
    elsif File.file? msg
      File::delete msg
    end
    "200 OK, deleted #{msg}"
  end
  
  # MKD - msg = pathname
  def mkd(msg)
    Dir.mkdir(msg)
    "257 #{msg} created"
  end
  
end