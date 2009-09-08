$:.unshift File.join(File.dirname(__FILE__))

%w( highrise
    highrise_ldap_extensions
    yaml 
    erb
    etc
    fileutils 
    logger
    thread 
    ldap/server 
    ldap/server/schema 
    resolv-replace
    active_record_operation
    pid_file 
    daemon
).each do |lib|
  require lib
end    

class Server
  attr_accessor :config, :logger, :pidfile
  include Daemon  

  @@def_config_file_name = File.expand_path(File.join(File.dirname(__FILE__), "..", "conf", "ldap-server.yml"))
  @@basedir = File.expand_path(File.join(File.dirname(__FILE__), ".."))
  
  def initialize(config_file_name = nil)
    config_file_name ||= @@def_config_file_name
    
    @config = YAML.load(ERB.new(File.read(config_file_name)).result)
    @config.symbolize_keys!
    
    self.logger = Logger.new(@config["log_file"] || File.join(@@basedir, *%w(log ldap-server.log)))
    self.logger.level = @config["debug"] ? Logger::DEBUG : Logger::INFO 
    self.logger.datetime_format = "%H:%M:%S"    
    self.logger.info ""

    @pidfile = PidFile.new(@config["pid_file"] || File.join(@@basedir, *%w(log ldap-server.pid)))
  end
  
  def become_user(username = 'nobody', chroot = false)
    user = Etc::getpwnam(username) 

    Dir.chroot(user.dir) and Dir.chdir('/') if chroot

    Process::initgroups(username, user.gid) 
    Process::Sys::setegid(user.gid) 
    Process::Sys::setgid(user.gid) 
    Process::Sys::setuid(user.uid) 
  end
  
  def start
    pidfile.ensure_empty! "ERROR: It looks like I'm already running.  Not starting."
    
    logger.info "Starting LDAP server"
    daemonize(logger)

    logger.info "Became daemon with process id: #{$$}"
    begin
      pidfile.create
    rescue Exception => e
      logger.info "Exception caught while creating pidfile: #{e}"
      exit
    end

    trap("TERM") do 
      logger.info("Received TERM signal.  Exiting.") if logger
      pidfile.remove if pidfile
      exit
    end
    
    logger.info "Attaching to #{@config[:highrise_api_url]}"
    begin
      Highrise::Base.site = @config[:highrise_api_url]
    rescue Exception => e
      logger.info "Exception caught: #{e}"
      exit
    end

    s = LDAP::Server.new(
    	:port			        => @config[:port],
    	:bindaddr         => @config[:bind_address],
    	:nodelay		      => @config[:tcp_nodelay],
    	:listen			      => @config[:prefork_threads],
    	:namingContexts		=> [@config[:basedn]],
    	:user             => @config[:user],
    	:group            => @config[:group],
    	:operation_class	=> ActiveRecordOperation,
    	:operation_args		=> [@config, logger]
    )
    s.run_tcpserver
    logger.info "Listening on port #{@config[:port]}."
    
    s.join
  end

  def stop
    if @pidfile.pid
      puts "Sending TERM signal to process #{@pidfile.pid}" if @config[:debug]
      logger.info("Killing server at #{@pidfile.pid}")
      Process.kill("TERM", @pidfile.pid.to_i)
    else
      puts "Can't find pid.  Are you sure I'm running?"
    end
  end

  def restart
    stop
    sleep 5
    start
  end  
end
