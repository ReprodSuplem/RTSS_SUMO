#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = Traci Command definitions
## Author:: Anonymous3
## Version:: 0.0 2014/07/03 Anonymous3
##
## === History
## * [2014/07/03]: Separate from TraciClient.rb
## == Usage
## * to get SUMO version
##	com = Command_GetVersion.new() ;
##	traci.execCommand(com) ;
##	val = com.responseValue() 
##      # => { :apiVersion => 8, :sumoVersion => "SUMO 0.20.0" }
## * to close connection
##	com = Command_Close.new() ;
##	traci.execCommand(com) ;
##	# This command returns nothing as responseValue.
## * to run simulation until a given time [milli sec.]
##	com = Command_SimulationStep.new(stepInMSec) ;
##	traci.execCommand(com) ;
##	val = com.responseValue() 
##	# returns values of subscribed variables.
##	# but, subscription is not supported yet.
## * to get variable value.
##	com = Command_GetVariable.new(domainId, variableId, objectId) ;
##	traci.execCommand(com) ;
##	val = com.responseValue() ;
##      # returns a data. The type of data depends on the specified value.
##   * See +DomainIdTable+ definitions in "TraciDataType.rb" 
##     to find possible domains and its symbolic name (+domainId+) .
##   * See +VariableIdTable+ definitions in "TraciDataType.rb" 
##     to find possible variables its symbolic name (+variableId+) and type.
##   * +objectId+ is a string.  The value for it depends on simulation setting.
##     The value can be find :idList value of the same domain.
##     If no +objectId+ needed, it should be a null string ("").
## * to set a value to the variable.
##	com = Command_SetVariable.new(domainId, variableId, objectId, value) ;
##	traci.execCommand(com) ;
##	val = com.responseValue() ;
##   * See the above description of +GetVariable+ to specify
##     +domainId+, +variableId+, and +objectId+ values.
##   * The type of +value+ depends on the specified variable.
##     Its definition can be find in +VariableIdTable+ definitions 
##     in "TraciDataType.rb" 

require 'pp' ;
require 'socket' ;
require 'singleton' ;

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'WithConfParam.rb' ;

require 'TraciUtil.rb' ;
require 'TraciDataType.rb' ;

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
    ## Traci::CommandBase
    class CommandBase
      #--::::::::::::::::::::::::::::::::::::::::::::::::::
      #++
      ## size of length section of whole message (multiple commands)
      MesssagSize_WholeLength = 4 ;
      ## size of length section of a short single command
      MessageSize_Length_Short = 1 ;
      ## size of length section of a long single command
      MessageSize_Length_Long = 1 + 4 ;
      ## size of identifier section of a single command 
      MessageSize_Identifier = 1 ;
      ## size of header (= length+identifier) section of a short single command
      MessageSize_HeaderShort = MessageSize_Length_Short + MessageSize_Identifier ;
      ## size of header (= length+identifier) section of a long single command
      MessageSize_HeaderLong = MessageSize_Length_Long + MessageSize_Identifier ;

      ## threshold to switch short and long header
      MessageSize_Threshold = 255 ;

      ## Identifier (should be defined for each command)
      Identifier = 0x00 ;

      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## result code. a Hash instance.
      attr :_resultCode, true ;
      ## scanned response. a Hash instance.
      attr :_response, true ;

      #----------------------------------------------------
      #++
      ## identifier
      ## *return*:: identifier
      def identifier()
        return self.class::Identifier ;
      end

#      #----------------------------------------------------
#      #++
#      ## header size (short case)
#      ## *return*:: header size in bytes
#      def messageSize_HeaderShort()
#        return MessageSize_Length_Short + MessageSize_Identifier ;
#      end

#      #----------------------------------------------------
#      #++
#      ## header size (short case)
#      ## *return*:: header size in bytes
#      def messageSize_HeaderLong()
#        return MessageSize_Length_Long + MessageSize_Identifier ;
#      end

#      #----------------------------------------------------
#      #++
#      ## command body (command content) size.
#      ## should be re-defined for each command type
#      ## *return*:: command body size in bytes
#      def messageSize_Body()
#        raise "messageSize_Body() is undefined for this Command." ;
#        return 0 ;
#      end

#      #----------------------------------------------------
#      #++
#      ## command body (command content) size.
#      ## should be re-defined for each command type
#      ## *return*:: command body size in bytes
#      def messageSize_Data(typeName, value = nil)
#        type = DataTypeTable.getByName(typeName) ;
#        size = type.size ;
#        if(size.nil?) then
#          ## should be defined for each variable size.
#          return 0 ;
#        else
#          return size ;
#        end
#      end

#      #----------------------------------------------------
#      #++
#      ## command body (command content) size. (obsolute)
#      ## should be re-defined for each command type
#      ## *return*:: command body size in bytes
#      def messageSize()
#        bodySize = messageSize_Body() ;
#        size = MessageSize_HeaderShort + bodySize ;
#        size = MessageSize_HeaderLong + bodySize if(isLongMessage(size)) ;
#        return size ;
#      end

      #----------------------------------------------------
      #++
      ## check to use long message
      ## *return*:: true if size is bigger than the threshold (255)
      def isLongMessage(size)
        size > MessageSize_Threshold ;
      end

      #----------------------------------------------------
      #++
      ## generate message
      ## *return*:: generated message (binary)
      def genMessage()
        body = messageBody() ;
        return messageHeader(body) << body ;
      end

      #----------------------------------------------------
      #++
      ## generate message header
      ## *return*:: header byte string
      def messageHeader(messageBody)
        bodySize = messageBody.size ;
        wholeSize = bodySize + MessageSize_HeaderShort ;
        if(isLongMessage(wholeSize))
          wholeSize = bodySize + MessageSize_HeaderLong ;
          return [0, wholeSize, identifier()].pack("CNC") ;
        else
          return [wholeSize, identifier()].pack("CC") ;
        end
      end

      #----------------------------------------------------
      #++
      ## generate message body
      ## *return*:: body byte string
      def messageBody()
        raise "should be define each command class." ;
      end

      #----------------------------------------------------
      #++
      ## scan response from the server
      ## _buffer_:: binary buffer of response
      ## *return*:: something
      def scanResponse(buffer)
        $stderr << self.class.inspect << ":scanResponse()" << "\n"
        $stderr << Util::octalDump(buffer) << "\n" ;
        raise "scanResponse() is not defined for this Command." ;
      end

      #----------------------------------------------------
      #++
      ## slice result code
      ## _buffer_:: result buffer (binary string).  This is modified by processing
      ## *return*:: code body binary string
      def sliceResultCodeBody(buffer)
        begin
          # get length
          len = DataType_UByte.unpack!(buffer)
          len -= DataType_UByte.size ; # reduced to get body length
          raise "wrong length part" if(len.nil?) ;
          # in the case of long response
          if(len < 0) # If the original len=0, then reduce len < 0.
            len = DataType_Integer.unpack!(buffer) ;
            raise "wrong long length part" if(len.nil?) ;
            len -= DataType_Integer.size ; #reduced len
          end
          # slice result code body
          resultCodeBody = buffer.slice!(0,len) ;
          raise "wrong result code body" if (resultCodeBody.size != len) ;
          return resultCodeBody ;
        rescue => ex
          $stderr << "Exception!! " << ex.message << "\n" ;
          $stderr << "  buffer=\n" ;
          $stderr << Sumo::Util::octalDump(buffer) ;
          $stderr << ex.backtrace.join("\n")
          raise "wrong result code part." ;
        end 
      end

      #----------------------------------------------------
      #++
      ## scan result code
      ## _buffer_:: result buffer (binary string).  This is modified by processing
      ## *return*:: code. [comId, code, message]
      def scanResultCode(buffer)
        codeBody = sliceResultCodeBody(buffer) ;

        comId = DataType_UByte.unpack!(codeBody) ;
        resultCode = DataType_UByte.unpack!(codeBody) ;
        resultMessage = DataType_String.unpack!(codeBody) ;

        resultCodeDesc = ResultCodeDescTable.getById(resultCode) ;

        @_resultCode = ({ :id => comId, 
                          :code => resultCodeDesc,
                          :message => resultMessage}) ;
        return @_resultCode ;
      end

      #----------------------------------------------------
      #++
      ## return actual response value
      ## *return*:: response value
      def responseValue()
        if(@_response.is_a?(Hash))
          return @_response[:value] ;
        elsif(@_response.nil?)
          return nil ;
        else
          raise "wrong response data type:" + @_response.inspect ;
        end
      end

      #----------------------------------------------------
      #++
      ## return result code
      ## *return*:: result code
      def resultCode()
        return @_resultCode ;
      end

      #----------------------------------------------------
      #++
      ## check result code is fine.
      ## if some problem, raise an exception.
      def checkResultCodeIsOk()
        if(!resultCode()[:code].isOk?) then
          raise SumoException.new(("something wrong at result code:" +
                                   resultCode().inspect),
                                  { :resultCode => resultCode() }) ;
        end
      end

    end # class CommandBase

    #--======================================================================
    #++
    ## Traci::Command GetVersion
    class Command_GetVersion < CommandBase
      #--::::::::::::::::::::::::::::::::::::::::::::::::::
      #++
      ## Identifier
      Identifier = Sumo::Traci::Constant["CMD_GETVERSION"] ;

#      #----------------------------------------------------
#      #++
#      ## command body (command content) size.
#      ## *return*:: command body size in bytes
#      def messageSize_Body()
#        return 0 ;
#      end

      #----------------------------------------------------
      #++
      ## generate message
      ## *return*:: generated message (binary)
      def messageBody()
        return "" ;
      end

      #----------------------------------------------------
      #++
      ## scan response from the server
      ## _buffer_:: binary buffer of response
      ## *return*:: something
      def scanResponse(buffer)
#        pp [:resBuffer] ;
#        puts Util::octalDump(buffer) ;
        # get result code
        scanResultCode(buffer) ;
        # get rest result
        resBodyLen = DataType_UByte.unpack!(buffer) ;
        resComId = DataType_UByte.unpack!(buffer) ;
        apiVersion = DataType_Integer.unpack!(buffer) ;
        sumoVersion = DataType_String.unpack!(buffer) ;
        #
        @_response = ({ :comId => resComId, 
                       :apiVersion => apiVersion, 
                       :sumoVersion => sumoVersion }) ;
#        pp [self.class, @_response] ;
        return @_response ;
      end

    end # class Command_GetVersion

    #--======================================================================
    #++
    ## Traci::Command_Close
    ## same as "simstep2" command in TraCITestClient.
    class Command_Close < CommandBase
      #--::::::::::::::::::::::::::::::::::::::::::::::::::
      #++
      ## Identifier
      Identifier = Sumo::Traci::Constant["CMD_CLOSE"] ;

#      #----------------------------------------------------
#      #++
#      ## command body (command content) size.
#      ## *return*:: command body size in bytes
#      def messageSize_Body()
#        return 0 ;
#      end

      #----------------------------------------------------
      #++
      ## generate message
      ## *return*:: generated message (binary)
      def messageBody()
        return "" ;
      end

      #----------------------------------------------------
      #++
      ## scan response from the server
      ## *return*:: something
      def scanResponse(buffer)
        # get result code
        scanResultCode(buffer) ;
        # do nothing else
        return nil ;
      end

    end # class Command_Close

    #--======================================================================
    #++
    ## Traci::Command_SimulationStep
    ## same as "simstep2" command in TraCITestClient.
    class Command_SimulationStep < CommandBase
      #--::::::::::::::::::::::::::::::::::::::::::::::::::
      #++
      ## Identifier
      Identifier = Sumo::Traci::Constant["CMD_SIMSTEP2"] ;

      #----------------------------------------------------
      #++
      ## initialize
      ## _step_:: final step [msec] to specify the end of simulation
      def initialize(step = 0)
        @step = step ;
      end

#      #----------------------------------------------------
#      #++
#      ## command body (command content) size.
#      ## *return*:: command body size in bytes
#      def messageSize_Body()
#        return DataType_Integer.size ;	# simulation step
#      end

      #----------------------------------------------------
      #++
      ## generate message
      ## *return*:: generated message (binary)
      def messageBody()
        msg = [@step].pack("N") ;
        return msg ;
      end

      #----------------------------------------------------
      #++
      ## scan response from the server
      ## _buffer_:: response buffer
      ## *return*:: list of subscription response
      def scanResponse(buffer)
        # get result code
        scanResultCode(buffer) ;
        # get the number of subscription
        n = DataType_Integer.unpack!(buffer) ;
        # scan subscription
        @_response = [] ;
        (0...n).each{|i|
          r = scanSubscriptionResponse(buffer) ;
          @_response.push(r) ;
        }
        #
        return @_response ;
      end

      #----------------------------------------------------
      #++
      ## scan subscription response
      ## (this is translated from tools/traci/__init__.py)
      ## (!!! not checked).
      ## _buffer_:: response buffer
      ## *return*:: subscription response (in hash table)
      def scanSubscriptionResponse(buffer)
        len = DataType_UByte.unpack!(buffer) ; ## length of the subsc.
        len = DataType_Integer.unpack!(buffer) if(len == 0) ;

        subscriptionType = DataType_UByte.unpack!(buffer) ; ## type of subsc.
        isVariable = ((subscriptionType >=
                       Constant["RESPONSE_SUBSCRIBE_INDUCTIONLOOP_VARIABLE"])&&
                      (subscriptionType <=
                       Constant["RESPONSE_SUBSCRIBE_GUI_CONTEXT"])) ;
        objectId = DataType_String.unpack!(buffer) ;
        domain = DataType_UByte.unpack!(buffer) if(! isVariable) ;
        numVars = DataType_UByte.unpack!(buffer) ;
        varInfoList = [] ;
        subscResponse = ({ :responseCode => subscriptionType,
                           :varInfo => varInfoList }) ;

        if(isVariable) then ## when variable case
          subscResponse[:type] = :variable ;
          (0...numVars).each{|i|
            varId = DataType_UByte.unpack!(buffer) ;
            status = DataType_UByte.unpack!(buffer) ;
            value = DataTypeTable.unpack!(buffer) ;

            # if status is error, raise exception.
            raise("Error! " + value) if(status != Constant["RTYPE_OK"]) ;

            varInfo = ({ :varId => varId,
                         :valueType => varTypeDef,
                         :value => value }) ;
            varInfoList.push(varInfo) ;
          }
        else ## when context case
          subscResponse[:type] = :context ;
          numObjs = DataType_Integer.unpack!(buffer) ;
          (0...numObjs).each{|k|
            objectId = DataType_String.unpack!(buffer) ;
            (0...numVars).each{|i|
              varId = DataType_UByte.unpack!(buffer) ;
              status = DataType_UByte.unpack!(buffer) ;
              value = DataTypeTable.unpack!(buffer) ;

              # if status is error, raise exception.
              raise("Error! " + value) if(status != Constant["RTYPE_OK"]) ;
              
              varInfo = ({ :objectId => objectId,
                           :varId => varId,
                           :valueType => varTypeDef,
                           :value => value }) ;
              varInfoList.push(varInfo) ;
            }
          }
        end
        return subscResponse ;
      end

    end # class Command_SimulationStep

    #--======================================================================
    #++
    ## Traci::Command_GetVariable
    ## same as "getvariable" command in TraCITestClient.
    class Command_GetVariable < CommandBase
      #--::::::::::::::::::::::::::::::::::::::::::::::::::
      #++
      ## Identifier
      Identifier = Sumo::Traci::Constant["(not specified)"] ;

      #----------------------------------------------------
      #++
      ## initialize
      ## _domId_:: domain ID. should be Integer or a Symbol of domain
      ## _varId_:: variable ID. should be Integeror a Symbol of variable
      ## _objId_:: object ID. should be String
      ## _aux_:: additional arguments (for 
      def initialize(domId, varId, objId, aux = nil)
        # set domID
        if(domId.is_a?(Numeric))
          @domId = domId ;
        else
          @domainEntry = DomainIdTable.getByName(domId) ;
          raise "unknown domain name: #{domId}" if(@domainEntry.nil?) ;
          @domId = @domainEntry.id ;
        end
        # set varId
        if(varId.is_a?(Numeric))
          @varId = varId ;
        else
          @variableEntry = VariableIdTable.getByName(varId) ;
          raise "unknown variable name: #{varId}" if (@variableEntry.nil?) ;
          @varId = @variableEntry.id ;
        end
        # set rest
        @objId = objId ;
        @aux = aux ;
#        pp [@domId, @varId, VariableIdTable.getByName(varId), @objId, @aux] ;
      end

      #----------------------------------------------------
      #++
      ## identifier
      ## *return*:: identifier
      def identifier()
        return @domId ;
      end

#      #----------------------------------------------------
#      #++
#      ## command body (command content) size.
#      ## (!!! should be include the size of @auxArgs)
#      ## *return*:: command body size in bytes
#      def messageSize_Body()
#        return (DataType_UByte.size +	# variable ID
#                DataType_Integer.size + # string (object name) length
#                @objId.size) ;		# object name
#      end

      #----------------------------------------------------
      #++
      ## generate message
      ## (!!! should be include the size of @auxArgs)
      ## *return*:: generated message (binary)
      def messageBody()
        msg = [@varId, @objId.size].pack("CN") + @objId ;
#        puts Util::octalDump(msg) ;
        return msg ;
      end

      #----------------------------------------------------
      #++
      ## scan response from the server
      ## _buffer_:: response buffer
      ## *return*:: list of subscription response
      def scanResponse(buffer)
        # get result code
        scanResultCode(buffer) ;
        # check result code
        checkResultCodeIsOk() ;

        # read length
        len = DataType_UByte.unpack!(buffer) ;
        len = DataType_Integer.unpack!(buffer) if(len == 0) ;

        # read body
        recvDomId = DataType_UByte.unpack!(buffer) ;
        recvVarId = DataType_UByte.unpack!(buffer) ;

        # check result code
        if(recvDomId - @domId != DomainIdDiff_Get_Response ||
           recvVarId != @varId) then
          raise("Do not match sent and recv ID in getVariable :" +
                [@domId, @varId].inspect +
                [recvDomId, recvVarId].inspect) ;
        end
        # read body
        recvObjectId = DataType_String.unpack!(buffer) ;
        recvValue = DataTypeTable.unpack!(buffer) ;

        @_response = ({ :domId => resultCode()[:id],
                       :varId => recvVarId,
                       :objId => recvObjectId,
                       :value => recvValue }) ;
        return @_response ;
      end

      #----------------------------------------------------
      #++
      ## check result code is fine.
      ## if some problem, raise an exception.
      def checkResultCodeIsOk()
        super() ;
        if(resultCode()[:id] != @domId) then
          raise("Do not match sent and recv ID in getVariable :" + 
                @domId.inspect + resultCode().inspect) ;
        end
      end

      

    end ## class Command_GetVariable

    #--======================================================================
    #++
    ## Traci::Command_SetVariable
    ## same as "setvariable" command in TraCITestClient.
    class Command_SetVariable < CommandBase
      #--::::::::::::::::::::::::::::::::::::::::::::::::::
      #++
      ## Identifier
      Identifier = Sumo::Traci::Constant["(not specified)"] ;

      #----------------------------------------------------
      #++
      ## initialize
      ## _domId_:: domain ID. should be Integer or a Symbol of domain.
      ## _varId_:: variable ID. should be a Symbol of variable.
      ## _objId_:: object ID. should be String.
      ## _value_:: value to set.
      ##           In the case of atomic data, the data itself.
      ##           In the case of string list, a list of string
      ##           In the case of composed data, a hash table
      ##           In the case of composed data list, a list of hash table.
      ## _aux_:: additional arguments (?)
      def initialize(domId, varId, objId, value, aux = nil)
        # set domID
        if(domId.is_a?(Numeric))
          @domId = domId ;
        else
          @domainEntry = DomainIdTable.getByName(domId) ;
          raise "unknown domain name: #{domId}" if(@domainEntry.nil?) ;
          @domId = @domainEntry.id + DomainIdDiff_Get_Set ;
        end
        # set varId
        @variableEntry = VariableIdTable.getByName(varId) ;
        raise "unknown variable name: #{varId}" if (@variableEntry.nil?) ;
        @varId = @variableEntry.id ;
        # set rest
        @objId = objId ;
        @value = value ;
        @aux = aux ;
#        pp [@domId, @varId, VariableIdTable.getByName(varId), @objId, @value, @aux] ;
      end

      #----------------------------------------------------
      #++
      ## identifier
      ## *return*:: identifier
      def identifier()
        return @domId ;
      end

#      #----------------------------------------------------
#      #++
#      ## command body (command content) size.
#      ## (!!! should be include the size of @auxArgs)
#      ## *return*:: command body size in bytes
#      def messageSize_Body()
#        # determine value size
#        @valueType = DataTypeTable.getByName(@variableEntry.type) ;
#        @valueSize = @valueType.actualSize(@value) ;
#        
#        return (DataType_UByte.size +   # variable ID
#                DataType_Integer.size + # string (object name) length
#                @objId.size +           # object name
#                @valueSize) ;		# value
#      end

      #----------------------------------------------------
      #++
      ## generate message
      ## (!!! should be include the size of @auxArgs)
      ## *return*:: generated message (binary)
      def messageBody()
        @valueType = DataTypeTable.getByName(@variableEntry.type) ;
        msg = [@varId, @objId.size].pack("CN") + @objId ;
        msg << @valueType.pack(@value, true) ;
#        puts Util::octalDump(msg) ;
        return msg ;
      end

      #----------------------------------------------------
      #++
      ## scan response from the server
      ## _buffer_:: response buffer
      ## *return*:: list of subscription response
      def scanResponse(buffer)
        # get result code
        scanResultCode(buffer) ;
        # check result code
        checkResultCodeIsOk() ;
      end
      
      #----------------------------------------------------
      #++
      ## check result code is fine.
      ## if some problem, raise an exception.
      def checkResultCodeIsOk()
        super() ;
        if(resultCode()[:id] != @domId) then
          raise("Do not match sent and recv ID in setVariable :" + 
                @domId.inspect + resultCode().inspect) ;
        end
      end

    end ## class Command_SetVariable


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

    #----------------------------------------------------
    #++
    ## show types
    def test_a
      pp :test_a
    end


  end # class TC_TraciClient
end # if($0 == __FILE__)
