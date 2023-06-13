require 'yaml'
require 'zlib'
class QW
    attr_accessor :dump
    attr_accessor :running    
    REG = {}
    
    def self.R(reg, lb = nil, &bl)
        block = lb || bl
        REG[reg] = {reg: reg, block: block}
    end        
    
    def initialize(dump)
        self.dump = dump
        @running   = true
    end
    
    def self.fromScript(name)
        code = File.read(name).split("\n")
        QW.new({
          :code  => code,
          :stack => [],
          :heap  => {}, 
        })
    end 
    
    def toImage(name, d = dump, options = {})
        if options[:zip]
            IO.binwrite name, Zlib::Deflate.deflate(d)
        else            
            IO.binwrite name, YAML.dump(d)            
        end            
    end        
    
    
    def copy
        YAML.load YAML.dump(dump) 
    end        
    
    def load(d)
        self.dump = d
    end        
    
    def self.fromImage(name, options = {})
        ff = File.binread(name)
        if options[:zip]
            ff = Zlib::Inflate.inflate(ff)
        end            
        rr = YAML.load ff
        QW.new(rr)             
    end
    
    def code
        self.dump[:code]
    end
    
    def stack
        self.dump[:stack]
    end
    
    def step
        if code.empty?
             @running = false
             return
        end
        
        @prev = prev = copy
        codeline = @cur = code.shift
        REG.each{|k, v|
            if v[:reg] =~ codeline
                match = $~
                run_one match, v, prev
                return
            end
        }
    end     
    
    def run_one(match, data, prev)
       begin
           instance_exec match, &data[:block]
       rescue Interrupt
           exception_handler    
       end           
    end        
    
    def exception_handler(prev)
       p $!
       puts "when running \"#@cur\""
       puts "What to do?"
       puts "1. To Next Line"
       puts "2. Dump current state"
       puts "3. Retry Prev Line"
       puts "0. Exit"
       loop do
           r = gets.to_i
           case r
           when 0
               exit
           when 1 
               puts "aborted"
               return
           when 2
               puts "What file name? "
               begin
                   filename = gets.strip
                   toImage(filename, prev)
                   puts "dumped"
                   @running = false
                   return
               rescue 
                   p $!
                   puts "Can not save"
               end                       
           when 3
               load(prev)
               puts "restored"
               return
           else   
               puts "Enter 1-3"
           end       
        end               
    end            
end

class QW
    R /^compute: (.*)$/ do |m|
       x = m[1].split
       self.code = x.map{|x| "compute-push: #{x}"}.concat(["compute-done"]).concat(self.code)
       self.stack.push "!"
    end
    
    R /^compute-push: (.*)$/ do |m|
       rr = Integer(m[1]) rescue m[1] 
       self.stack.push(rr)
       while self.stack.size >= 3 && ["+", "-", "*", "/", "%"].include?(self.stack[-3]) &&
              self.stack[-2].is_a?(Integer) &&
              self.stack[-1].is_a?(Integer)
          op, s, t = self.stack.pop(3)
          self.stack.push(s.send(op, t))
       end
    end
    
    
    R /^compute-done$/ do |m|
        if self.stack.size >= 2 && self.stack[-2] == '!'
           stack[-2] = stack[-1]
           stack.pop
        end            
    end        
    
    R /^print$/ do
        p stack.pop
    end
    
    R /^eval: (.*)/ do |m|
        begin
            stack.push(eval(m[1]))
        rescue
            exception_handler(@prev)
        end             
    end
    
    R /^eval-except: (.*)/ do |m|
        begin
            stack.push(eval(m[1]))
        rescue
            stack.push($!)
        end             
    end
    
    R /^eval-at: (.*)/ do |m|
        begin
            stack.push(stack.pop.instance_eval(m[1]))
        rescue
            stack.push($!)
        end             
    end
    
    
    
    R /^loop$/ do
        loop do end
    end       
    
    
            
end    



qw = QW.fromScript('ttt.txt')
while qw.running
    qw.step
end

