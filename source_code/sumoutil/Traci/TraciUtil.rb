#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = Traci Utility
## Author:: Anonymous3
## Version:: 0.0 2014/07/03 Anonymous3
##
## === History
## * [2014/07/03]: Separate from TraciClient.rb
## == Usage
## * ...

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

$verboseP = false ;

#--===========================================================================
#++
## package for SUMO
module Sumo

  #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #++
  ## Sumo source base path
  # SumoSrcBase = "/usr/local/src/Sumo/sumo-0.20.0" ;
  SumoSrcBase = open("|find /usr/local/src -name 'sumo-[0-9]*.[0-9]*.[0-9]*' -print | sort","r"){|strm| strm.read.split("\n").last} ;

  #--======================================================================
  #++
  ## Util module
  module Util
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## simulation unit steps per seconds (SUMO's default)
    SimUnitsPerSec = 1000 ;

    #--------------------------------------------------------------
    #++
    ## convert SUMO's simulation units to time in sec
    def convertSimUnitsToSec(simUnits)
      simUnits.to_f / SimUnitsPerSec ;
    end
    
    #--------------------------------------------------------------
    #++
    ## convert time in sec to SUMO's simulation units
    def convertSecToSimUnits(sec)
      (sec * SimUnitsPerSec).to_i ;
    end
    
    #--------------------------------------------------------------
    #++
    ## octal dump
    ## _str_:: binary string
    ## *return* :: dumped string
    def octalDump(data)
      byteL = data.length() ;
      byteM = 16 ;
      # get hex numbers
      hex = [] ;
      IO.popen("od -txC","r+") {|strm|
        strm.write(data) ;
        strm.close_write() ;
        while(l = strm.gets)
          hexList = l.chomp().split() ;
          hex.push(*(hexList[1..-1])) ;
        end
      }
      # flag to swich ascii display
      useSimpleAscii = true ;
      # get ascii
      ascii = [] ;
      if(!useSimpleAscii) # not used
        IO.popen("od -ta","r+") {|strm|
          strm.write(data) ;
          strm.close_write() ;
          while(l = strm.gets)
            asciiList = l.chomp().split() ;
            ascii.push(*(asciiList[1..-1])) ;
          end
        }
      else # use simple ASCII chars
        (0...(byteL.to_f/byteM).ceil).each{|k|
          asciiList = data.slice(k * byteM, byteM).gsub(/[\x00-\x1F\x7F-\xFF]/n,
                                                        '.') ;
          ascii.push(asciiList)
        }
      end
      dumpStr = "" ;
      (0...(byteL.to_f/byteM).ceil()).each{|k|
        hexStr = hex[k*byteM,byteM].join(" ") ;
        if(!useSimpleAscii)
          ascStr = ascii[k*byteM,byteM].map{|c| "%3s" % c}.join(" ") ;
          dumpStr += "%-#{byteM*3}s : %-#{byteM*4}s\n" % [hexStr,ascStr] ;
        else
          ascStr = ascii[k] ;
          dumpStr += "%-#{byteM*3}s : %-#{byteM}s\n" % [hexStr,ascStr] ;
        end
      }
      return dumpStr ;
    end

    #--------------------------------------------------------------
    #++
    ## check TCP port is used
    ## _port_:: port number to check
    ## *return* :: true if the port is used
    def isTcpPortInUse(port)
      infoPath = "/proc/net/tcp" ;
      open(infoPath,"r"){|strm|
        while(info = strm.gets())
          cols = info.split ;
          if(cols[0] =~ /^[0-9]+\:/) then
            (addrStr, portStr) = cols[1].split(":") ;
            return true if (portStr.hex() == port) ;
          end
        end
        return false ;
      }
    end

    #--------------------------------------------------------------
    #++
    ## wait until TCP port is ready
    ## _port_:: port number to check
    ## _interval_:: interval of sleep
    ## *return* :: true if the port is used
    def waitTcpPortIsReady(port, interval = 0.1)
      sleep(interval) until isTcpPortInUse(port) ;
    end

    #--------------------------------------------------------------
    #++
    ## wait until TCP port is free
    ## _port_:: port number to check
    ## _interval_:: interval of sleep
    ## *return* :: true if the port is used
    def waitTcpPortIsFree(port, interval = 0.1)
      sleep(interval) until !isTcpPortInUse(port) ;
    end

    #--------------------------------------------------------------
    #++
    ## scan free TCP port
    ## _originPort_:: port number to start scan
    ## _max_:: max count to scan
    ## *return* :: a free port number
    def scanFreeTcpPort(originPort, max = 10000)
      (0...max).each{|c|
        port = originPort + c ;
        return port if !isTcpPortInUse(port) ;
      }
    end

    #--============================================================
    #++
    ## Generic Entry for Named Id 
    class NamedIdEntry
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## type name (Symbol)
      attr :name, true ;
      ## name in Sumo::Traci::Constant table
      attr :nameInConstant, true ;
      ## id of type (Integer)
      attr :id, true ;
      ## name in Constant
      attr :nameInConstant, true ;

      #----------------------------------------------------
      #++
      ## initialization
      ## _name_:: name of data type. should be Symbol.
      ## _cname_:: name in Constant table. should be String.
      def initialize(name, cname, *rest)
        @name = name ;
        @nameInConstant = cname ;
        @id = Sumo::Traci::Constant[@nameInConstant] ;
        if(@id.nil?) then
          if(@nameInConstant.is_a?(Numeric))
            @id = @nameInConstant ;
          else
            if($verboseP) then
              puts "Warning!!! unknown @nameInConstant: #{@nameInConstant}."
            end
            @id = nil ;
          end
        end
      end

      #----------------------------------------------------
      #++
      ## shortName
      ## *return*:: a short string name
      def shortName()
        ("\#<#{self.class.name}" + " " +
         "@name=#{@name.inspect}" + ", " +
         "@id=#{@id.inspect}" + ", " +
         "@cname=#{@nameInConstant.inspect}" + ">") ;
      end

    end # class NamedIdEntry

    #--============================================================
    #++
    ## Generic Table for Named Id
    class NamedIdTable
      include Singleton
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## list of data types
      attr :list, true ;
      ## table by name
      attr :tableByName, true ;
      ## table by id
      attr :tableById, true ;
      ## table by nameInConstant
      attr :tableByNameInConstant, true ;

      #----------------------------------------------------
      #++
      ## initialization
      def initialize()
        @list = [] ;
        @tableByName = {} ;
        @tableById = {} ;
        @tableByNameInConstant = {} ;
      end

      #----------------------------------------------------
      #++
      ## entry class
      def entryClass()
        raise "should be defined locally."
      end

      #----------------------------------------------------
      #++
      ## add entry
      ## _args_:: params to pass to entryClass.new()
      ## *return*:: new entry
      def add(*args)
        addBody(true, *args)
      end

      #----------------------------------------------------
      #++
      ## add extra entry (without duplicate check)
      ## _args_:: params to pass to entryClass.new()
      ## *return*:: new entry
      def addExtra(*args)
        addBody(false, *args)
      end

      #----------------------------------------------------
      #++
      ## add entry.  body part
      ## _checkDuplicate:: if true, check duplicate registration to table.
      ## _args_:: params to pass to entryClass.new()
      ## *return*:: new entry
      def addBody(checkDuplicate, *args)
        entry = entryClass.new(*args)
        @list.push(entry) ;
        # check and add to @tableByName
        if(@tableByName[entry.name]) then
          if(checkDuplicate)
            puts "Warning!!!: already defined name: #{entry.shortName} for #{self}."
          end
        else
          @tableByName[entry.name] = entry ;
        end
        # check and add to @tableById
        if(@tableById[entry.id]) then
          if(checkDuplicate)
            puts "Warning!!!: already defined id: #{entry.shortName} for #{self}."
          end
        else
          @tableById[entry.id] = entry ;
        end
        # check and add to @tableByNameInConstant
        if(@tableByNameInConstant[entry.nameInConstant])
          if(checkDuplicate)
            puts "Warning!!!: already defined name in constant: #{entry.shortName} for #{self}."
          end
        else
          @tableByNameInConstant[entry.nameInConstant] = entry ;
        end

        return entry ;
      end

      #----------------------------------------------------
      #++
      ## get by name
      ## _name_:: type name
      ## *return*:: entry if exist
      def getByName(name)
        @tableByName[name] ;
      end

      #----------------------------------------------------
      #++
      ## get by id
      ## _id_:: entry id
      ## *return*:: type if exist
      def getById(id)
        @tableById[id] ;
      end

      #----------------------------------------------------
      #++
      ## get by nameInConstant
      ## _name_:: type name
      ## *return*:: entry if exist
      def getByNameInConstant(name)
        @tableByNameInConstant[name] ;
      end

      #--==================================================
      #++
      ## class methods
      class << self
        #--------------------------------
        #++
        ## add
        def add(*args)
          self.instance.add(*args) ;
        end

        #--------------------------------
        #++
        ## add extra
        def addExtra(*args)
          self.instance.addExtra(*args) ;
        end

        #--------------------------------
        #++
        ## get by type name
        def getByName(name)
          self.instance.getByName(name) ;
        end

        #--------------------------------
        #++
        ## get by type id
        def getById(id)
          self.instance.getById(id) ;
        end

        #--------------------------------
        #++
        ## get by type nameInConstant
        def getByNameInConstant(name)
          self.instance.getByNameInConstant(name) ;
        end

      end # class << self

    end # class NamedIdTable

    #--============================================================
    ## Color Utility
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## X11 Color File
    #Color_X11ColorFile = "/usr/share/X11/rgb.txt" ;
    Color_X11ColorFile = File::dirname(__FILE__) + "/rgb.txt" ;
    ## default alpha value
    FullAlphaValue = 255 ;
    DefaultAlpha = 127 ;    
    ## Color Table
    ColorTable = {} ;
    open(Color_X11ColorFile,"r"){|strm|
      while(line = strm.gets())
        if(line =~ /^\s*([0-9]+)\s+([0-9]+)\s+([0-9]+)\s+(.*)$/) then
          val = $~ ;
          (rVal, gVal, bVal) = val[1..3].map{|v| v.to_i} ;
          aVal = FullAlphaValue ;
          name = val[4] ;
          ColorTable[name] = { :r => rVal, :g => gVal, :b => bVal,
                               :a => aVal } ;
        end
      end
    } ;

    #--============================================================
    #--------------------------------------------------------------
    #++
    ## get color value.
    ## _colorName_ :: String or Symbol of color name or Hash of color value
    ## *return* :: { :r => rVal, :g => gVal, :b => bVal, :a => aVal }
    def getColorValue(colorName, alpha = nil)
      value = nil ;
      if(colorName.is_a?(Symbol))
        return getColorValue(colorName.to_s) ;
      elsif(colorName.is_a?(String))
        value = ColorTable[colorName] ;
        raise "Unknown color name: #{colorName}" if(value.nil?) ;
      elsif(colorName.is_a?(Hash)) ;
        value = colorName ;
      else
        raise "Illegal color specification: #{colorName.inspect}" ;
      end

      if(!alpha.nil?) then
        value = value.dup ;
        value[:alpha] = alpha ;
      end
      
      return value ;
    end

  end # module Util
  Util.extend(Util) ;

  #--======================================================================
  #++
  ## generic Sumo Exception class.
  class SumoException < StandardError
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## params
      attr :param, true ;
      
      #----------------------------------------------------
      #++
      ## initialization.
      ## _message_:: message of exception.
      ## _params_:: additional parameters in Hash table.
      def initialize(message = nil, param = {})
        super(message) ;
        @param = param ;
      end
    
  end
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
    ## octal dump
    def test_a
      puts Sumo::Util::octalDump("\003abcde" * 20) ;
      x = [1,2,3,4.5] ;
      y = x.pack("iCcd") ;
      z = y.unpack("iCcd") ;
      p [x,z] ;
      puts Sumo::Util::octalDump(y) ;
    end

    #----------------------------------------------------
    #++
    ## port checker
    def test_b
      port = 12345 ;
      p [:checkPort, port, Sumo::Util::isTcpPortInUse(port)] ;
    end

  end # class TC_TraciClient
end # if($0 == __FILE__)
