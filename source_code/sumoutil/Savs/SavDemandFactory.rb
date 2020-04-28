#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = SAV Demand Factory (abstracted base class)
## Author:: Anonymous3
## Version:: 0.0 2018/01/28 Anonymous3
##
## === History
## * [2018/01/28]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));
$LOAD_PATH.addIfNeed(File.dirname(__FILE__) + "/../Traci");

require 'pp' ;
require 'json' ;
require 'WithConfParam.rb' ;

require 'SavSimulator.rb' ;
require 'SavDemand.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## class for Factory of SavDemand
  class SavDemandFactory < WithConfParam
    
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = { :demandConf => {},
                    :logFile => nil,  # if filename is specified, open log.
                    nil => nil } ;
                    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## link to SavSimulator
    attr_accessor :simulator ;
    ## whole demands list.
    attr_accessor :wholeList ;
    ## processing demands list.
    attr_accessor :processingList ;
    ## completed demands list.
    attr_accessor :completedList ;
    ## cancelled demands list.
    attr_accessor :cancelledList ;
    ## newly cancelled demands list.
    attr_accessor :newCancelledList ;
    ## log stream
    attr_accessor :logStrm ;
    
    #------------------------------------------
    #++
    ## initialize
    ## _savSim_ :: parent simulator
    ## _conf_:: configuration information
    def initialize(savSim, conf = {})
      @simulator = savSim ;
      super(conf) ;
      setup() ;
    end

    #------------------------------------------
    #++
    ## setup.
    ## should be re-defined in subclass if needed.
    def setup()
      @wholeList = [] ;
      @processingList = [] ;
      @completedList = [] ;
      @cancelledList = [] ;
      @newCancelledList = [] ;

      @demandConf = getConf(:demandConf) ;

      prepareLog() if(getConf(:logFile));

      self ;
    end
    
    #------------------------------------------
    #++
    ## prepare log stream
    def prepareLog()
      file = getConf(:logFile) ;
      Util.ensureDir(file) ;
      @logStrm = open(file, "w") ;
    end
    
    #------------------------------------------
    #++
    ## generate new demand() ;
    def newDemand()
      raise "newDemand() should be defined in class :#{self.class}."
    end
    
    #------------------------------------------
    #++
    ## generate new demands in a cycle
    def newDemandListForCycle()
      raise "newDemandListForCycle() should be defined in class :#{self.class}."
    end
    
    #------------------------------------------
    #++
    ## registerNewDemandList
    def registerNewDemandList(demandList, cancelList, processing = true)
      demandList.each{|demand|
        @wholeList.push(demand) ;
        @processingList.push(demand) if(processing) ;
      }
      cancelList.each{|demand|
        @cancelledList.push(demand) ;
        @newCancelledList.push(demand) ;
      }
    end

    #------------------------------------------
    #++
    ## check processing.
    ## if the demand is completed, move the demand from processing to
    ## completed list.
    def cycleCheckProcessingList()
      ## completed demand list.
      compList = [] ;
      @processingList.each{|demand|
        if(demand.getState() == :afterDropOff) then
          compList.push(demand) ;
          @completedList.push(demand) ;
          demand.complete(@simulator) ;
          outputDemandLogInJson(demand) ;
        end
      }
      compList.each{|demand|
        @processingList.delete(demand) ;
      }
      
      ## cancelled demand list.
      @newCancelledList.each{|demand|
        outputDemandLogInJson(demand) ;
        compList.push(demand) ;
      }
      @newCancelledList.clear() ;
      
      return compList ;
    end

    #------------------------------------------
    #++
    ## output demand JSON to log file
    def outputDemandLogInJson(demand)
      jsonHash = demand.toJson() ;
      jsonStr = JSON.generate(jsonHash) ;
      @logStrm << jsonStr << "\n" ;
    end
    
    #------------------------------------------
    #++
    ## for inspect()
    alias inspect_original inspect ;
    def inspect() ;
      dummy = self.dup ;
      dummy.simulator = nil ;
      return dummy.inspect_original ;
    end

    #--------------------------------------------------------------
    #++
    ## dump party log 
    def dumpPartyLog(file)
      _partyList = collectPartyLog([]) ;
      Util.ensureDir(file) ;
      open(file, "w"){|strm|
        c = 0 ;
        strm << "[" ;
        _partyList.each{|json|
          strm << "," if(c > 0) ;
          strm << "\n\t" << JSON.generate(json) ;
          c += 1;
        }
        strm << "\n]\n" ;
      }
    end

    #--------------------------------------------------------------
    #++
    ## collect Party Log
    def collectPartyLog(logList = []) ;
      return logList ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

    #--========================================
    #--::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #------------------------------------------

  end # class SavDemandFactory
  
end # module Sav

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_SavBase < Test::Unit::TestCase
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## desc. for TestData
    SampleDirBase = "/home/noda/work/iss/SAVS/Data" ;
    SampleDir = "#{SampleDirBase}/2018.0104.Tsukuba"
    SampleConfFile03 = "#{SampleDir}/tsukuba.03.sumocfg" ;

    SampleXmlMapFile = "#{SampleDir}/TsukubaCentral.small.net.xml" ;
    SampleJsonMapFile = SampleXmlMapFile.gsub(/.xml$/,".json") ;

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
    ## about test_a
    def test_a
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
