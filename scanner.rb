require 'socket'
require 'timeout'
require 'thread'
class PortScanner # create our class
    attr_accessor :host, :ports, :qpool, :mpool, :threads # create getter/setter methods
    def initialize host # contructor
        @host = IPSocket.getaddress host
        @ports = (1..1024).to_a.freeze # most common ports
        @qpool = Queue.new # create new pool for threading
        @mpool = Mutex.new # handling pool threading
    end
    def port_open(host, port, tout=1)
        Timeout::timeout(tout) do
            begin
                TCPSocket.new(host, port).close
                "OPEN"
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
                "CLOSED"
            rescue => err
                $stderr.puts "[!] #{err}"
                exit
            end
        end
    rescue Timeout::Error
        "CLOSED"
    end
    def run
        @ports.each{ |port| @qpool << port }
        @ports.size.times.map do
            Thread.new do
                while not @qpool.empty?
                    port_in_pool=@qpool.pop(true) rescue nil # port_in_pool set to nil instead of exception
                    port_get_status=port_open(@host, port_in_pool)
                    @mpool.synchronize do
                        yield port_in_pool, port_get_status
                    end
               end
           end
       end.each(&:join)
   end
end
host = ARGV.shift
open = Array.new
puts "\nScanning... (#{host})"
PortScanner.new(host).run do |pp, ps|
    puts "PORT %-7s %-5s" % [pp, ps] if ps.eql? "OPEN"
end
