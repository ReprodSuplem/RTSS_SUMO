#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Traci Client
## Author:: Anonymous3
## Version:: 0.0 2014/06/13 Anonymous3
##
## === History
## * [2014/06/13]: Create This File.
## * [2014/06/28]: add socket connection
## == Usage
## * to prepare client
##	traci = Sumo::Traci::Client.new({ :port => port, 
##                                        :logLevel => :info,
##                                        :logDev => [:stdout,:file] }) ;
##
## * to send a command
##	com = Sumo::Traci::Command_XXXXX(...) ;
##      traci.execCommands(com) ;
##      # in the case the command return some value
##      returnValue = com.responseValue() 
##   * please see "TraciCommand.rb" to find details about possible Commnd_XXXX.
##
## * to finalize simulation
##      traci.execCommands(Sumo::Traci::Command_Close.new()) ;
##      traci.close() ;
##

require 'pp' ;
require 'socket' ;
require 'singleton' ;

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");

$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'WithConfParam.rb' ;
require 'ExpLogger.rb' ;

require 'TraciUtil.rb' ;
require 'TraciDataType.rb' ;
require 'TraciCommand.rb' ;

#--===========================================================================
#++
## package for SUMO
module Sumo

  #--======================================================================
  #++
  ## module for Traci
  module Traci

    #--======================================================================
    #++
    ## Traci::Client
    class Client < WithConfParam
      #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      #++
      ## description of DefaultValues.
      DefaultConf = { 
        :host => 'localhost',
        :port => 12345,
        :openSocket => true,
        :logDev => [:file], # :file, :stdout, :stderr
        :logLevel => :info, # [:debug, :info, :warn, :fatal, :none]
        :logDir => "./,Log",
        :logFilename => ("traciClient.%s.log" % 
                         Time::now.strftime("%Y-%m%d-%H%M%S")),
        nil => nil 
      } ;

      _LoggingTag = ({ :debug => ["D", 100],
                      :info =>  ["I", 200],
                      :warn =>  ["W", 300],
                      :error => ["E", 400],
                      :fatal => ["F", 500] })

      DefaultRecvMaxLength = 2 ** 16 ; ## (not used)

      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## hostname that run SUMO
      attr :host, true ;
      ## port of Traci Server at SUMO
      attr :port, true ;
      ## socket for Traci communication
      attr :socket, true ;
      ## a list of log stream
      ## attr :logStreamList, true ;
      attr :logger, true ;

      #--------------------------------------------------------------
      #++
      ## initializatoin
      ## _conf_:: configuation
      def initialize(conf)
        super(conf) ;
        @host = getConf(:host) ;
        @port = getConf(:port) ;
        setupLog() ;
        setupSocket() if getConf(:openSocket) ;
      end

      #--------------------------------------------------------------
      #++
      ## setup log
      def setupLog_old()
        @logLevelName = getConf(:logLevel) ;
        @logLevel = LoggingTag[@logLevelName][1] ;
        @logStreamList = [] ;
        getConf(:logDev).each{|dev|
          case(dev)
          when(:file)
            logfile = "#{getConf(:logDir)}/#{getConf(:logFilename)}" ;
            system("mkdir -p #{File::dirname(logfile)}") ;
            strm = File::open(logfile, "w") ;
            @logStreamList.push(strm) ;
          when(:stdout)
            @logStreamList.push($stdout) ;
          when(:stderr)
            @logStreamList.push($stderr) ;
          else
            raise SumoException.new("unknown log device tag: #{dev.inspect}",
                                    { :dev => dev }) ;
          end
        }
      end

      #--------------------------------------------------------------
      #++
      ## setup log
      def setupLog()
        @logger = nil ;
        getConf(:logDev).each{|dev|
          logConf = { :chain => @logger,
                      :level => getConf(:logLevel),
                      :quoteString => false,
                      :withLogLevel => true,
                      :withTimestamp => true } ;
          case(dev)
          when(:file)
            logfile = "#{getConf(:logDir)}/#{getConf(:logFilename)}" ;
            system("mkdir -p #{File::dirname(logfile)}") ;
            logConf[:file] = logfile ;
          when(:stdout)
            logConf[:stream] = $stdout ;
          when(:stderr)
            logConf[:stream] = $stderr ;
          else
            raise SumoException.new("unknown log device tag: #{dev.inspect}",
                                    { :dev => dev }) ;
          end
          @logger = Itk::ExpLogger.new(logConf) ;
        }
      end
        
      #--------------------------------------------------------------
      #++
      ## close log stream
      def closeLog_old()
        @logStreamList.each{|strm|
          strm.close() if(strm.is_a?(File)) ;
        }
      end

      #--------------------------------------------------------------
      #++
      ## close log stream
      def closeLog()
        @logger.close() ;
      end
      
      #--------------------------------------------------------------
      #++
      ## log output
      ## _tag_:: tag string to print the top
      ## _messageList_:: message to output
      ## _body_:: procedure to generate message. 
      ##          this should return array or string.
      def loggingBody_old(tag, *messageList, &body)
        return if(@logStreamList.empty?) ; ## reduce time
        # append results of body
        if(body)
          bodyResult = body.call() ;
          if(bodyResult.is_a?(Array)) then
            messageList.concat(bodyResult)
          else
            messageList.push(bodyResult) ;
          end
        end
        # output
        timestr = Time.now.strftime("[%Y-%m-%dT%H:%M:%S]") ;
        @logStreamList.each{|strm|
          strm << "-----\n[" << tag << "]:" << timestr << ": " ;
          first = true ;
          messageList.each{|message|
            strm << message << "\n" ;
          }
        }
      end

      #--------------------------------------------------------------
      #++
      ## logging(level, *messageList, body
      ## level:: tag string to print the top
      ## _messageList_:: message to output
      ## _body_:: procedure to generate message. 
      ##          this should return array or string.
      def logging_old(level, *messageList, &body)
        tagInfo = LoggingTag[level] ;
        if(tagInfo[1] >= @logLevel) then
          loggingBody(tagInfo[0], *messageList, &body) ;
        end
      end

      #--------------------------------------------------------------
      #++
      ## logging(level, *messageList, body
      ## level:: tag string to print the top
      ## _messageList_:: message to output
      ## _body_:: procedure to generate message. 
      ##          this should return array or string.
      def logging(level, *messageList, &body)
        @logger.logging(level, *messageList, &body) ;
      end
      
      #--------------------------------------------------------------
      #++
      ## setup socket
      ## _waitp_:: if true, wait until the port is available.
      ## _host_:: if not nil, specify hostname to run Sumo.
      ## _port_:: if not nil, specify TCP port for TRACI.
      ## *return*:: socket to open
      def setupSocket(waitp = true, host = nil, port = nil)
        # setup host/port
        @host = host || @host ;
        @port = port || @port ;
        logging(:info){ "set TCP port = #{@host}:#{@port}." } ;

        # wait until the port open
        if(@host == 'localhost')
          Util::waitTcpPortIsReady(@port) ;
        end

        #open socket
        logging(:info){ "try to open TCP socket to #{@host}:#{@port}." } ;
        @socket = TCPSocket::new(@host, @port) ;
        logging(:info){ "success to open TCP socket to #{@host}:#{@port}." } ;

        return @socket ;
      end

      #--------------------------------------------------------------
      #++
      ## close socket
      def close()
        logging(:info){ "shutdown TCP socket to #{@host}:#{@port}." } ;
        @socket.shutdown() ;
        logging(:info){ "Done: shutdown TCP socket to #{@host}:#{@port}." } ;
        closeLog() ;
      end

      #--------------------------------------------------------------
      #++
      ## execute commands
      ## send list of commands and receive their responses
      ## _commands_:: list of message to send. an instance of CommandBase
      ## *return*:: list of scanned response
      def execCommands(*commands)
        logging(:debug){
          ("enter: execCommands(" +
           commands.map{|com| com.class.name}.inspect +
           ")") ; } ;
        logging(:debug, "execCommands: commands:"){ commands.pretty_inspect } ;
        # get message body
        comBuffer = "" ;
        commands.each{|com|
          comBuffer << com.genMessage() ;
        }
        # send message exactly
        sendExact(comBuffer) ;
        # receive response exactly
        resBuffer = recvExact() ;
        # scan and set result code
        resList = []
        commands.each{|com|
          res = com.scanResponse(resBuffer) ;
          resList.push(res) ;
        }
        logging(:debug, "execCommands: responses:"){
          commands.map{|com| [com.class.name, 
                              com._resultCode, 
                              com._response]}.pretty_inspect }
        logging(:debug){
          ("exit: execCommands(" +
           commands.map{|com| com.class.name}.inspect +
           ")") ; } ;
        return resList ;
      end

      #--------------------------------------------------------------
      #++
      ## send exactly
      ## _message_:: message byte string (String object)
      ## *return*:: response of @socket.send
      def sendExact(message)
        length = message.size + CommandBase::MesssagSize_WholeLength ;
        ## should use BigEndian (Network Byte Order)
#        wholeMessage = [length].pack("I") + message ;
        @rawMessage = [length].pack("N") + message ;
        # send messagre
        logging(:debug, "sendExact: dump="){ Util::octalDump(@rawMessage); }
        r = @socket.send(@rawMessage,0) ;
        @socket.flush ;
        return r ;
      end

      #--------------------------------------------------------------
      #++
      ## recv exactly.
      ## Whole message is recorded to @wholeMessage
      ## *return*:: received message (without length header)
      def recvExact()
        wholeLengthHeader = recvExactNBytes(DataType_Integer.size) ;
        wholeLength = wholeLengthHeader.unpack("N").first() ;
        length = wholeLength - DataType_Integer.size ;
        buffer = recvExactNBytes(length) ;
        @rawResponse = wholeLengthHeader + buffer ;
        logging(:debug, "recvExact: dump="){ Util::octalDump(@rawResponse); }
        return buffer ;
      end

      ## Size of Integer

      #--------------------------------------------------------------
      #++
      ## recv exactly N bytes
      ## *return*:: received message
      def recvExactNBytes(n)
        buffer = "" ;
        while(buffer.size < n)
          IO::select([@socket]) ;
          buf = @socket.recv(n-buffer.size) ;
          if(buf == "") # in the case of EOF
            raise SumoException.new("TCP socket return EOF",
                                    { :n => n }) ;
          end
          buffer << buf ;
        end
        return buffer ;
      end

      #--------------------------------------------------------------
      #++
      ## split response pack
      ## _responsePack_:: response pack (packed responses)
      ## *return*:: [response, response, ...]
      def splitResponsePack(responsePack)
        responseList = [] ;
        while(responsePack.length > 0)
          # get length
          len = DataType_UByte.unpack!(responsePack) ;
          len -= DataType_UByte.size ; # reduced len
          # in the case of long response
          if(len < 0) # If the original len=0, then reduce len < 0.
            len = DataType_Integer.unpack!(responsePack) ;
            len -= DataType_Integer.size ; #reduced len
          end
          # get response body
          responseBody = responsePack.slice!(0,len) ;
          # check length value
          if(len.nil? || responseBody.size != len)
            $stderr << "Exception!!\n" ;
            $stderr << "  @rawResponse=\n" ;
            $stderr << Sumo::Util::octalDump(@rawResponse) ;
            $stderr << "  responseBody=\n" ;
            $stderr << Sumo::Util::octalDump(responseBody) ;
            $stderr << "  currentResponse=\n" ;
            $stderr << Sumo::Util::octalDump(responsePack) ;
            raise SumoException.new("wrong length header for response item.") ;
          end
          # collect to the list
          responseList.push(responseBody) ;
        end
        # return
        return responseList ;
      end

#      #--------------------------------------------------------------
#      #++
#      ## scan result code
#      ## _responseItem_:: response item
#      ## *return*:: [comId, code, message]
#      def scanResultCode(responseItem)
#        comId = DataType_UByte.unpack!(responseItem) ;
#        resultCode = DataType_UByte.unpack!(responseItem) ;
#        messageLen = DataType_Integer.unpack!(responseItem) ;
#        resultMessage = responseItem.slice!(0,messageLen) ;
#
#        resultCodeDesc = ResultCodeDescTable.getById(resultCode) ;
#
#        return [comId, resultCodeDesc, resultMessage] ;
#      end

      #--------------------------------------------------------------
      #++
      ## close and shutdown SUMO server
      def closeServer()
        com = Sumo::Traci::Command_Close.new() ;
        execCommands(com) ;
        close() ;
      end

      #--------------------------------------------------------------
      #++
      ## get simulation time
      def fetchSimulationTime()
        com = Sumo::Traci::Command_GetVariable.new(:sim, :timeStep, "") ;
        execCommands(com) ;
        time = com.responseValue() ;
        return time ;
      end

      #--============================================================
      #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      SumoCommand_Gui_Quit = "/usr/bin/env sumo-gui -v -S --quit-on-end true" ;
      SumoCommand_Gui = "/usr/bin/env sumo-gui -v -S --quit-on-end false" ;
      SumoCommand_Cui = "/usr/bin/env sumo -v -S" ;
      SumoTraciPort_ScanFrom = 12345 ;
      #--============================================================
      #--------------------------------------------------------------
      #++
      ## prepare SUMO server
      ## _sumoConfigFile_ :: config file for SUMO. (usually, .sumocfg suffix)
      ## _guiMode_ :: one of {nil, :none, nil, :gui, :guiQuit}
      ## _portScanFrom_ :: start port number to scan free port for TRACI
      ## *return* :: list of [<port_number>, <process_status>].
      ##             <port_number> is for TRACI.
      ##             <process_status> is an instance of Process::Status.
      def self.prepareServer(sumoConfigFile,
                             guiMode = :guiQuit,
                             portScanFrom = SumoTraciPort_ScanFrom)
        port = Sumo::Util::scanFreeTcpPort(portScanFrom) ;
        Sumo::Util::waitTcpPortIsFree(port) ;

        case(guiMode)
        when nil, :none, :cui ; sumoCom = SumoCommand_Cui ;
        when :gui ;       sumoCom = SumoCommand_Gui ;
        when :guiQuit ;   sumoCom = SumoCommand_Gui_Quit ;
        else raise "Unknown GUI Mode: #{guiMode}." ;
        end
        
        sumoCom << " -c #{sumoConfigFile} --remote-port #{port}" ;
        Itk::ExpLogger.info([:sumoCom, sumoCom]) ;
        system(sumoCom + " &") ;
        return [port, $?] ;
      end

      #--============================================================
      #--------------------------------------------------------------
      #++
      ## prepare SUMO server and open Client
      ## _sumoConfigFile_ :: config file for SUMO. (usually, .sumocfg suffix)
      ## _clientConfig_ :: config for Traci::Client
      ## _guiMode_ :: one of {nil, :none, nil, :gui, :guiQuit}
      ## _portScanFrom_ :: start port number to scan free port for TRACI
      ## *return* :: list of [<port_number>, <process_status>].
      ##             <port_number> is for TRACI.
      ##             <process_status> is an instance of Process::Status.
      def self.newWithServer(sumoConfigFile,
                             clientConfig = {},
                             guiMode = :guiQuit,
                             portScanFrom = SumoTraciPort_ScanFrom)
        (port, procStatus) = self.prepareServer(sumoConfigFile,
                                                guiMode, portScanFrom) ;
        Sumo::Util::waitTcpPortIsReady(port) ;
        clientConfig[:port] = port ;
        return self.new(clientConfig) ;
      end
      
      #--============================================================
      #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #--------------------------------------------------------------
      
    end # class Client

  end # module Traci

end # module Sumo

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_TraciClient < Test::Unit::TestCase
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## desc. for TestData
    TestData = nil ;

    #----------------------------------------------------
    #++
    ## show separator and title of the test.
    def setup
#      puts ('*' * 5) + ' ' + [:run, name].inspect + ' ' + ('*' * 5) ;
      name = "#{(@method_name||@__name__)}(#{self.class.name})" ;
      puts ('*' * 5) + ' ' + [:run, name].inspect + ' ' + ('*' * 5) ;
      super
    end

    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    SampleDir = "#{Sumo::SumoSrcBase}/docs/examples/sumo"
    SampleConfFile = "#{SampleDir}/hokkaido/hokkaido.sumocfg" ;

    #----------------------------------------------------
    #++
    ## run server and connect
    def test_a
      ## SUMO を TraCI モードで立ち上げ。TraCI サーバのポートは port
      (port,_) = Sumo::Traci::Client.prepareServer(SampleConfFile)
      Sumo::Util::waitTcpPortIsReady(port) ;

      ## クライアント作成。TraCI サーバのポートは port
      ## ログは、$stdout に吐き出す。
      traci = Sumo::Traci::Client.new({ :port => port, 
                                        :logLevel => :debug,
#                                        :logLevel => :info,
                                        :logDev => [:stdout,:file] }) ;

      ## バージョン情報をゲット。
      ## 多重コマンドを送れるテスト。
      com0 = Sumo::Traci::Command_GetVersion.new() ;
      com1 = Sumo::Traci::Command_GetVersion.new() ;
      traci.execCommands(com0,com1) ;

      ## Variable の値を取ってくるテスト。
      ## この例は、シミュレーションステップを取りに行く。
      ## ドメイン・変数指定は、数字でもできる。
      com2 = Sumo::Traci::Command_GetVariable.new(0xab, 0x70, "")
      traci.execCommands(com2) ;

      ## シミュレーションを進める。100000ms まで。
      com3 = Sumo::Traci::Command_SimulationStep.new(100000) ;
      traci.execCommands(com3) ;

      ## ふたたびシミュレーションステップを取りに行く。
      com4 = Sumo::Traci::Command_GetVariable.new(0xab, 0x70, "")
      traci.execCommands(com4) ;

      ## 同じく、シミュレーションステップを取りに行く。
      ## 今度はドメイン・変数指定をシンボルでやってみる。
      com5 = Sumo::Traci::Command_GetVariable.new(:sim, :timeStep, "")
      traci.execCommands(com5) ;

      ## エッジのIDリストを取ってきてみる。
      com6 = Sumo::Traci::Command_GetVariable.new(:edge, :idList, "")
      traci.execCommands(com6) ;

      ## シミュレーション終了
      comE = Sumo::Traci::Command_Close.new() ;
      traci.execCommands(comE) ;

      ## コネクションを close
      traci.close() ;
    end

    #----------------------------------------------------
    #++
    ## get variables
    def test_b
      traci =
        Sumo::Traci::Client.newWithServer(SampleConfFile,
                                          { :logDev => [:stdout],
                                            :logLevel => :debug,
#                                            :logLevel => :info,
                                          }) ;

      ## ジャンクションの ID リストを取ってきてみる。
      com = Sumo::Traci::Command_GetVariable.new(:junction, :idList, "") ;
      traci.execCommands(com) ;
      p [:junctionList, com.responseValue()]
      ## ジャンクションの最初の1つを取り出す。
      juncName = com.responseValue()[0] ;

      ## あるジャンクションの位置を取り出す。
      com = Sumo::Traci::Command_GetVariable.new(:junction, :position, juncName);
      traci.execCommands(com) ;
      p [:junctionPos, com.responseValue()]

      ## シミュレーションすすめてみる。
      com = Sumo::Traci::Command_SimulationStep.new(200000) ;
      traci.execCommands(com) ;

      ## 車のIDリストを取り出す。
      com = Sumo::Traci::Command_GetVariable.new(:vehicle, :idList, "") ;
      traci.execCommands(com) ;
      p [:vehicleList, com.responseValue()]
      ## vehicle list のはず
      vList = com.responseValue() ;

      ## 最初の車の色を変えてみる。
      com = Sumo::Traci::Command_SetVariable.new(:vehicle, :color, vList[0],
                                                 { :r => 100,
                                                   :g => 100,
                                                   :b => 255,
                                                   :a => 255 }) ;
      traci.execCommands(com) ;

      ## 最初の車の大きさの値
      com = Sumo::Traci::Command_GetVariable.new(:vehicle, :length, vList[0]) ;
      traci.execCommands(com) ;
      p [:vehicleLength, com.responseValue()] ;
      vLength = com.responseValue() ;

      ## 最初の車の大きさを変えてみる。
      com = Sumo::Traci::Command_SetVariable.new(:vehicle, :length, vList[0],
                                                 vLength * 10) ;
      com2 = Sumo::Traci::Command_SetVariable.new(:vehicle, :width, vList[0],
                                                  vLength * 4) ;
      traci.execCommands(com,com2) ;

      ## 終了
      traci.execCommands(Sumo::Traci::Command_Close.new()) ;
      traci.close() ;
    end

    #----------------------------------------------------
    #++
    ## loop
    def test_c
      traci =
        Sumo::Traci::Client.newWithServer(SampleConfFile,
                                          { :logDev => [:stdout],
#                                            :logLevel => :debug,
                                            :logLevel => :info,
                                          }) ;
      ## start
      vehicleTable = {} ;
      step = 0 ;
      ustep = 100 ;
      delay = 0.001 ;
      while(step < 2000*1000)
        # simulation を進める。
        step += ustep
        com = Sumo::Traci::Command_SimulationStep.new(step) ;
        traci.execCommands(com) ;
        # 車のリスト取得
        com = Sumo::Traci::Command_GetVariable.new(:vehicle, :idList, "") ;
        traci.execCommands(com) ;
        vList = com.responseValue() ;
        vList.each{|vId|
          if(vehicleTable[vId].nil?) then
            ## 元の大きさ取得。
            com = Sumo::Traci::Command_GetVariable.new(:vehicle, :length, vId) ;
            traci.execCommands(com) ;
            vLength = com.responseValue() ;
            ## 新しい車の大きさと色を変える。
            com1 = Sumo::Traci::Command_SetVariable.new(:vehicle, :length, vId,
                                                       vLength * 10) ;
            com2 = Sumo::Traci::Command_SetVariable.new(:vehicle, :width, vId,
                                                        vLength * 4) ;
            colList = [{ :r => 100, :g => 100, :b => 255, :a => 255 },
                       { :r => 100, :g => 255, :b => 100, :a => 255 },
                       { :r => 255, :g => 100, :b => 100, :a => 255 }] ;
            color = colList[rand(colList.size)] ;
            com3 = Sumo::Traci::Command_SetVariable.new(:vehicle, :color, 
                                                        vId, color) ;
            traci.execCommands(com1,com2,com3) ;
            vehicleTable[vId] = vId ;
          end
        }

        if(vehicleTable.size > 0 && rand(10) == 0)
          v = vList[rand(vList.size)] ;
          speed = 10.0 * rand() ;
          duration = 1000 ;
          com = Sumo::Traci::Command_SetVariable.new(:vehicle, :slowDown, v,
                                                     { :speed => speed,
                                                       :duration => duration }) ;
          traci.execCommands(com) ;
        end

        sleep(delay) if vehicleTable.size > 0 ;
      end

      ## 終了
      traci.execCommands(Sumo::Traci::Command_Close.new()) ;
      traci.close() ;
    end

  end # class TC_TraciClient
end # if($0 == __FILE__)
