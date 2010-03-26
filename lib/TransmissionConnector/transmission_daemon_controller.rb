module TransmissionConnector
  class DaemonController
    def initialize(parameters)
      @config_dir = parameters[:config_dir]
      @host       = parameters[:host]
      @port       = parameters[:port]
    end
    
    def start
      @pid = fork
      
      if(@pid)
        puts "Spawned process with pid #{@pid}"
      else
        exec "/usr/bin/transmission-daemon --foreground --config-dir #{@config_dir} --port #{@port}"
      end
    end
    
    def start_and_wait
      start
      wait_for_transmission
    end
    
    def wait_for_transmission(max_wait_time = 30)
      start = Time.new.to_i
      
      while(Time.new.to_i < (start + max_wait_time))
        puts "Waiting for transmission to get ready..."
        begin
          Timeout::timeout(1) do
            begin
              socket = TCPSocket.new(@host, @port)
              socket.close
              return true #Up and running, continue program
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
              # Probably not up, continue loop
              sleep 0.2
            end
          end
        rescue Timeout::Error
          # One second timeout, continue loop
        end        
      end
      
      #If code ends up here then it's because we never got a connection
      raise "Transmission daemon did not start in #{max_wait_time} seconds"
    end
    
    def stop
      Process.kill('TERM', @pid)
      Process.waitpid(@pid)
    end
    
    def show_status
      begin
        Process.kill(0, @pid)
        puts "#{@pid} is alive."
      rescue Errno::EPERM
        puts "#{@pid} has detached.";
      rescue Errno::ESRCH
        puts "#{@pid} is dead.";
      rescue
        puts "Status of #{@pid} unavailable : #{$!}"
      end      
    end
  end
end