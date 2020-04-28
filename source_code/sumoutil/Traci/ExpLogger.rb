#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = Logger for Experiments
## Author:: Anonymous3
## Version:: 0.0 2014/06/11 Anonymous3
##
## === History
## * [2014/06/11]: copy this from WithLogger.rb
##                 WithLogger has conflicts with ItkLogger
## * [2014/11/09]: Compress Mode
## == Usage
## * ...

require 'time' ;
require 'zlib' ;

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'WithConfParam.rb' ;

#--======================================================================
#++
## Itk package
module Itk

  #--============================================================
  #++
  ## utilities
  module ExpLogUtility
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## Logging Level
    Level = {
      :none => LevelAll = 0,
      :debug => LevelDebug = 1,
      :info => LevelInfo = 2,
      :warn => LevelWarn = 3,
      :error => LevelError = 4,
      :fatal => LevelFatal = 5,
      :top => LevelNone = 6,
    } ;
    ## Table for Logging Level
    LevelName = {} ;
    Level.each{|key, value| LevelName[value] = key.to_s.capitalize} ;

    #--------------------------------------------------
    #++
    ## generate timestamp form
    def getLevelVal(level)
      if(level.is_a?(Numeric)) then
        return level ;
      elsif(level.is_a?(String))
        return Level[level.intern] ;
      elsif(level.is_a?(Symbol))
        return Level[level] ;
      else
        return nil ;
      end
    end
    
    #--------------------------------------------------
    #++
    ## generate timestamp form
    def getTimestamp()
      return Time.now.strftime(TimestampFormat)
    end
    TimestampFormat = "%Y-%m-%dT%H:%M:%S" ;
    
    #--------------------------------------------------
    #++
    ## generic function for logging objects for each type of objects.
    def putOne(strm, obj, newlinep = true)
      if(obj.is_a?(Array))
        putOne_Array(strm, obj) ;
      elsif(obj.is_a?(Hash))
        putOne_Hash(strm, obj) ;
      elsif(obj.is_a?(Time))
        putOne_Time(strm, obj) ;
      elsif(obj.is_a?(Numeric))
        putOne_Atom(strm, obj) ;
      elsif(obj.is_a?(String))
        putOne_String(strm, obj) ;
      elsif(obj.is_a?(Symbol))
        putOne_Atom(strm, obj) ;
      elsif(obj.is_a?(Class))
        putOne_Atom(strm, obj) ;
      elsif(obj == true || obj == false || obj == nil)
        putOne_Atom(strm, obj) ;
      else
        putOne_Object(strm, obj) ;
      end
      strm << "\n" if(newlinep) ;
    end

    #--------------------------------------------------
    #++
    ## log output of Array
    def putOne_Array(strm, obj)
      strm << '[' ;
      initp = true ;
      obj.each{|value| 
        strm << ', ' if(!initp) ;
        initp = false ;
        putOne(strm, value, false) ;
      }
      strm << ']' ;
    end

    #--------------------------------------------------
    #++
    ## log output of Hash
    def putOne_Hash(strm, obj)
      strm << '{' ;
      initp = true ;
      obj.each{|key,value| 
        strm << ', ' if(!initp) ;
        initp = false ;
        putOne(strm, key, false) ;
        strm << '=>'
        putOne(strm, value, false) ;
      }
      strm << '}' ;
    end

    #--------------------------------------------------
    #++
    ## log output of Time
    def putOne_Time(strm, obj)
      strm << 'Time.parse(' ;
      strm << obj.strftime("%Y-%m-%dT%H:%M:%S%z").inspect
      strm << ')' ;
    end

    #--------------------------------------------------
    #++
    ## log output of other Objects
    def putOne_Object(strm, obj)
      strm << '{' ;
      strm << ':__class__' << '=>' << obj.class.inspect ;
      obj.instance_variables.each{|var|
        strm << ', ' ;
        strm << (var.slice(1...var.size).intern.inspect) ;
        strm << '=>'
        putOne(strm, obj.instance_eval("#{var}"), false) ;
      }
      strm << '}' ;
    end

    #--------------------------------------------------
    #++
    ## log output of Atomic or Primitive Objects
    def putOne_Atom(strm, obj)
      strm << obj.inspect ;
    end

    #--------------------------------------------------
    #++
    ## log output of Atomic or Primitive Objects
    def putOne_String(strm, obj)
      if(@quoteString) then
        strm << obj.inspect ;
      else
        strm << obj ;
      end
    end
    #--------------------------------------------------
    #++
    ## output message if level is higher than the current log level.
    # _level_ :: log level of this message.
    # _*messageList_ :: a list of objects to output for logging.
    # _&body_ :: a procedure to generate the final message.
    def logging(level,*messageList, &body)
      raise("logging(level,*messageList, &body) is not implemented for this instance" + 
            self.inspect) ;
    end

    #--------------------------------------------------
    #++
    ## force logging
    # _message_ :: message or object
    def <<(message)
      logging(LevelNone,message) ;
    end

    #--------------------------------------------------
    #++
    ## logging info debug level
    # _*messageList_ :: a list of objects to output for logging.
    # _&body_ :: a procedure to generate the final message.
    def debug(*messageList,&body)
      logging(LevelDebug, *messageList, &body) ;
    end

    #--------------------------------------------------
    #++
    ## logging info level
    # _*messageList_ :: a list of objects to output for logging.
    # _&body_ :: a procedure to generate the final message.
    def info(*messageList,&body)
      logging(LevelInfo, *messageList, &body) ;
    end

    #--------------------------------------------------
    #++
    ## logging warn level
    # _*messageList_ :: a list of objects to output for logging.
    # _&body_ :: a procedure to generate the final message.
    def warn(*messageList,&body)
      logging(LevelWarn, *messageList, &body) ;
    end

    #--------------------------------------------------
    #++
    ## logging error level
    # _*messageList_ :: a list of objects to output for logging.
    # _&body_ :: a procedure to generate the final message.
    def error(*messageList,&body)
      logging(LevelError, *messageList, &body) ;
    end

    #--------------------------------------------------
    #++
    ## logging fatal level
    # _*messageList_ :: a list of objects to output for logging.
    # _&body_ :: a procedure to generate the final message.
    def fatal(*messageList,&body)
      logging(LevelFatal, *messageList, &body) ;
    end

  end ## module Itk::ExpLogUtility

  module ExpLogUtility ; extend ExpLogUtility ; end

  #--============================================================
  #++
  ## Logger class
  class ExpLogger < WithConfParam
    include ExpLogUtility
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## defaults for initialization
    DefaultConf = {
      :stream => $stdout,
      :file => nil,
      :tee => false, ## if true and :file is given, make log both.
      :chain => nil,
      :append => false,
      :level => LevelInfo,
      :withLevel => false,
      :compress => false,
      :timestamp => false,
      :quoteString => true,
    } ;

    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## log stream
    attr :stream, true ;
    ## logfile
    attr :file, true ;
    ## log level
    attr :level, true ;
    ## flag to output level info in the log
    attr :withLevel, true ;
    ## flag to output stimestamp in the log
    attr :withTimestamp, true ;
    ## flat to output string with quotation mark
    attr :quoteString, true ;
    ## flag to output stream and chained logger
    attr :tee, true ;
    ## chained logger
    attr :chain, true ;  ## chained logger
    ## compress mode
    attr :compress, true ;  ## flag whether compress or not


    #--------------------------------------------------
    #++
    ## initialization with config
    def initialize(conf = {})
      super(conf) ;
      setup() ;
    end

    #--------------------------------------------------
    #++
    ## setup using config
    def setup()
      @append = getConf(:append) ;
      @tee = getConf(:tee) ;
      @chain = getConf(:chain) ;
      @file = getConf(:file) ;
      @compress = getConf(:compress) ;
      openFile(@file) if(@file) ;
      @stream = @stream || getConf(:stream) ;
      setLevel(getConf(:level)) ;
      @withLevel = getConf(:withLevel) ;
      @withTimestamp = getConf(:withTimestamp) ;
      @quoteString = getConf(:quoteString) ;
      @stream ;
    end

    #--------------------------------------------------
    #++
    ## open file
    # _file_ :: log file name
    # _mode_ :: open mode. one of nil, 'w', 'a','r'
    # *return* :: IO stream for the opened file.
    def openFile(file, mode=nil) # mode = nil | 'w' | 'a' | 'r'
      if(mode.nil?)
        mode = @appendp ? 'a' : 'w' ;
      end

      if(@tee) then
        newConf = @conf.dup.update({ :file => nil,
                                     :stream => @stream,
                                     :compress => false,
                                     :tee => false }) ;
        @chain = self.class.new(newConf) ;
      end

      @file = file ;

      if(@compress) then
        # check suffix of file
        fname = ((@file =~ /\.gz$/) ? @file : @file + ".gz") ;
        @stream = Zlib::GzipWriter.open(fname) ;
      else
        @stream = open(@file, mode) ;
      end
    end

    #--------------------------------------------------
    #++
    ## set log level
    # _level_ :: log level. one of {:debug, :info, :error, :fatal}
    # *return* :: the level.
    def setLevel(level)
      @chain.setLevel(level) if(@chain) ;
      @level = getLevelVal(level) ;

      raise("unknown LogLevel:" + level.inspect) if (@level.nil?) ;

      return @level ;
    end

    #--------------------------------------------------
    #++
    ## set flag to specify log output with log level
    # _flag_ :: true or false.
    def setWithLevel(flag = true)
      @chain.setWithLevel(flag) if(@chain) ;
      @withLevel = flag ;
    end

    #--------------------------------------------------
    #++
    ## set flag to specify log output with timestamp
    # _flag_ :: true or false.
    def setWithTimestamp(flag = true)
      @chain.setWithTimestmap(flag) if(@chain) ;
      @withTimestamp = flag ;
    end

    #--------------------------------------------------
    #++
    ## set flag to output string with quotation
    # _flag_ :: true or false.
    def setQuoteString(flag = true)
      @chain.setQuoteString(flag) if(@chain) ;
      @quoteString = flag ;
    end

    #--------------------------------------------------
    #++
    ## output message if level is higher than the current log level.
    # _level_ :: log level of this message.
    # _*messageList_ :: a list of objects to output for logging.
    # _&body_ :: a procedure to generate the final message.
    def logging(level,*messageList, &body)
      level = getLevelVal(level) ;
      ## call chained logger
      @chain.logging(level,*messageList, &body) if(@chain) ;
      
      if(@stream && level >= @level)
        ## check length of messageList
        l = messageList.length ;
        l += 1 if(body) ;

        ## output separator if multiple message.
        @stream << "-" * 10 << "\n" if(l > 1) ;
        
        ## header
        @stream << LevelName[level] << ":" if(@withLevel) ;
        @stream << "[" << getTimestamp() << "]:" if (@withTimestamp) ;

        ## output body
        messageList.each{|message|
          putOne(@stream, message, true) ;
        }
        putOne(@stream, body.call(), true) if(body) ;
      end
    end

    #--------------------------------------------------
    #++
    ## close log file
    def close()
      @stream.close() if(@file) ;
    end

  end # class ExpLogger

  #--============================================================
  #++
  # class methods for ExpLogger
  class << ExpLogger
    extend ExpLogUtility ;
    include ExpLogUtility ;

    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## logger instance
    Entity = ExpLogger.new() ;

    #--------------------------------------------------
    #++
    ## get logger instance
    # *return* :: the instance stored in ExpLogger::Entity
    def logger()
      Entity ;
    end

    #--------------------------------------------------
    #++
    ## open log file for the logger instance
    def openFile(file, mode = nil)
      logger().openFile(file,mode) ;
    end

    #--------------------------------------------------
    #++
    ## set level for the logger instance
    def setLevel(level)
      logger().setLevel(level) ;
    end

    #--------------------------------------------------
    #++
    ## set withLevel for the logger instance
    def setWithLevel(flag=true)
      logger().setWithLevel(flag) ;
    end

    #--------------------------------------------------
    #++
    ## set withTimestamp for the logger instance
    def setWithTimestamp(flag=true)
      logger().setWithTimestamp(flag) ;
    end

    #--------------------------------------------------
    #++
    # _level_ :: log level of this message.
    # _*messageList_ :: a list of objects to output for logging.
    # _&body_ :: a procedure to generate the final message.
    ## output for the logger instance
    def logging(level,*messageList, &body)
      logger().logging(level, *messageList, &body) ;
    end

    #--------------------------------------------------
    #++
    ## close the log file.
    def close()
      logger().close() ;
    end

    #--------------------------------------------------
    #++
    ## execute something with a logger
    def withExpLogger(conf = {}, &block)
      _logger = ExpLogger.new(conf) ;
      begin
        block.call(_logger) ;
      ensure
        _logger.close() ;
      end
    end

  end # class << ExpLogger

  #--------------------------------------------------
  #++
  ## execute something with a logger (def for Itk module)
  def withExpLogger(conf = {}, &block)
    ExpLogger::withExpLogger(conf, &block) ;
  end

  extend Itk ;

end ## module Itk



######################################################################
######################################################################
######################################################################
if($0 == __FILE__) then
  require 'test/unit'

  ##============================================================
  class TC_WithExpLogger < Test::Unit::TestCase

    ##----------------------------------------
    def setup
      name = "#{(@method_name||@__name__)}(#{self.class.name})" ;
      puts ('*' * 5 ) + ' ' + [:run, name].inspect + ' ' + ('*' * 5) ;
      super
    end

    ##----------------------------------------
    def test_a()
      data = [:foo,
              [true, false, nil, :foo, Array],
              [1, 2.0, -3.4, 0x3],
              Time.now,
              {:a => [1,2,3], :c => Hash, :d => {1 => 2, "bar" => 'baz'}},
              Foo.new()] ;
      Itk::ExpLogUtility::putOne($stdout , data) ;
      str = "" ;
      Itk::ExpLogUtility::putOne(str, data) ;
      p str ;
      d = eval(str) ;
      p [:eval, d] ;
      Itk::ExpLogUtility::putOne($stdout, d) ;
    end

    class Foo
      def initialize()
        @bar = "" ;
        @baz = :abcde ;
        @foo = [1,2,3,4,5] ;
      end
    end

    ##----------------------------------------
    def test_b()
      test_b_sub() ;
      Itk::ExpLogger.setWithLevel() ;
      test_b_sub() ;
    end

    ##----------------------------------------
    def test_b_sub()
      Itk::ExpLogger << "foo" ;
      Itk::ExpLogger << [:a, "b", Foo.new(), {:a => 1, 2 => 3.1415, "3" => [1,2,3]}] ;
      [Itk::ExpLogger::LevelInfo, Itk::ExpLogger::LevelDebug,
       Itk::ExpLogger::LevelError, Itk::ExpLogger::LevelFatal].each{|lv|
        Itk::ExpLogger.setLevel(lv) ;
        Itk::ExpLogger.info([:info, [:level, lv]]) ;
        Itk::ExpLogger.debug([:info, [:level, lv]]) ;
        Itk::ExpLogger.error([:info, [:level, lv]]) ;
        Itk::ExpLogger.fatal([:info, [:level, lv]]) ;
      } ;
    end

    ##----------------------------------------
    def test_c()
      data = [:foo,
              [true, false, nil, :foo, Array],
              [1, 2.0, -3.4, 0x3],
              Time.now,
              {:a => [1,2,3], :c => Hash, :d => {1 => 2, "bar" => 'baz'}},
              Foo.new()] ;

      Itk::withExpLogger({ :file => "/tmp/#{File::basename($0)}.#{$$}.log",
                           :compress => false }) {|logger|
        logger << ["hogehoge", data] ;
        logger << ["hogehoge", data] ;
        logger << ["hogehoge", data] ;
      }
      Itk::withExpLogger({ :file => "/tmp/#{File::basename($0)}.#{$$}.log",
                           :compress => true }) {|logger|
        logger << ["hogehoge", data] ;
        logger << ["hogehoge", data] ;
        logger << ["hogehoge", data] ;
      }
    end

    ##----------------------------------------
    description "test of multiple message and call-body."
    def test_d()
      Itk::ExpLogger.setLevel(:info) ;
      Itk::ExpLogger.setWithTimestamp() ;
      Itk::ExpLogger.info("foo","bar","baz"){"x" * 10}
    end
    
  end ##   class TC_WithExpLogger

end
