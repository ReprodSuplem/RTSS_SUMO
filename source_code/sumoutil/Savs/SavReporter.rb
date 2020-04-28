#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = SAV situation Reporter (abstracted base class)
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
require 'SavVehicle.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## class for Sav Allocator
  class SavReporter < WithConfParam
    
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = {
      :reportInterval => 20, # report interval in [sec]
#      :reportLogLevel => :info,
      :reportLogLevel => :debug,
    } ;
                    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## link to SavSimulator
    attr_accessor :simulator ;

    ## table of previous Report Time ;
    attr_accessor :reportTimeTable ;

    ## report interval in sec ;
    attr_accessor :reportInterval ;
    
    ## list of reports ;
    attr_accessor :reportList ;
    
    ## loglevel of report in logging.
    attr_accessor :reportLogLevel ;
    
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
      @reportTimeTable = {} ;
      @reportInterval = getConf(:reportInterval) ;
      @reportLogLevel = getConf(:reportLogLevel) ;
    end
    
    #------------------------------------------
    #++
    ## allocate
    ## actual allocation should be done in this method.
    ## _demandList_:: list of SavDemand.
    ## *return* :: allocated demands.
    def report()
      reportList = makeReportInJsonList() ;

      reportList.each{|report|
        @simulator.logging(@reportLogLevel,
                           "SavReport:"){
          JSON.dump(report) ;
        }
      }
    end

    #------------------------------------------
    #++
    ## allocate
    ## actual allocation should be done in this method.
    ## _demandList_:: list of SavDemand.
    ## *return* :: allocated demands.
    def makeReportInJsonList()
      @reportList = [] ;
      @simulator.eachSav(){|sav|
        demandReportP =
          (sav.arrivedViaPoint && sav.arrivedViaPoint.hasDemand()) ;

        prevTime = @reportTimeTable[sav] || 0 ;
        simpleReportP =
          (@simulator.currentTime - prevTime >= @reportInterval) ;
        
        if(demandReportP || simpleReportP) then
          savReport = makeReportForOneSav(sav, demandReportP)
          @reportList.push(savReport) ;
        end
      }
      return @reportList ;
    end

    #------------------------------------------
    #++
    ## allocate
    ## actual allocation should be done in this method.
    ## _demandList_:: list of SavDemand.
    ## *return* :: allocated demands.
    def makeReportForOneSav(sav, withDemandP)
      report = {} ;

      report['savId'] = sav.id ;
      report['time'] = @simulator.currentTimeInString() ;

      sav.fetchPosition() ;
      lonlat = @simulator.map.transformXY2LonLat(sav.pos) ;
      report['position'] = { 'longitude' => lonlat.x,
                             'latitude' => lonlat.y } ;

      if(withDemandP) then
        demand = sav.arrivedViaPoint.demand ;
        report['demandState'] = { 'demandId' => demand.id,
                                  'state' => demand.getState } ;
      end
      
      @reportTimeTable[sav] = @simulator.currentTime ;
      
      return report ;
    end
        
    
    #--------------------------------
    #++
    ## logging
    def logging(level, *messageList, &body)
      @simulator.logging(level, *messageList, &body) ;
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
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

    #--========================================
    #--::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #------------------------------------------

  end # class SavReporter
  
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
