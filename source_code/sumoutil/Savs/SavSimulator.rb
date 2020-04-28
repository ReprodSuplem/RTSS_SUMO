#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = SAV Simulator
## Author:: Anonymous3
## Version:: 0.0 2018/01/23 Anonymous3
##
## === History
## * [2018/01/23]: Create This File.
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

require 'SumoManager.rb' ;
require 'SavVehicle.rb' ;
require 'SavBase.rb' ;
require 'SavReporter.rb' ;
require 'SavGeoFeature.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--======================================================================
  #++
  ## Sav Simulator
  class SavSimulator < Sumo::SumoManager
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = { :vehicleType => 'savBase',
                    :vehicleManagerConf => {},
                    :poiManagerConf => {
                      :defaultPoiClass => Sumo::Traci::GroundedPoi,
                    },
                    :demandFactoryClass => nil,
                    :demandFactoryConf => {},
                    :allocatorClass => nil,
                    :allocatorConf => {},
                    :nSavMax => nil,
                    :addSavInterval => 10,
                    :reporterClass => nil, # or SavReporter or its subclass.
                    :reporterConf => {},
                    :trailLogFile => nil,  # if filename, dump trail log.
                    :allocLogFile => nil,  # if filename, dump alloc. log.
                    :partyLogFile => nil,  # if filename, dump party log.
                    :configLogFile => nil, # if filename, save config to file.
                    :featureTableFile => nil,
                    :stopMargin => 10.0,
                    nil => nil } ;

    ## DefaultVehicleManagerConf
    DefaultVehicleManagerConf = { :defaultVehicleClass => SavVehicle,
                                  :vehicleIdPrefix => 'sav',
                                  :vehicleConf => { :color => 'DodgerBlue',
                                                  },
                                } ;
    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## table of sav base. key is the name of the base.
    attr_accessor :savBaseTable ;
    ## list of sav base.
    attr_accessor :savBaseList ;
    ## default type of sav Vehicle.
    attr_accessor :vehicleType ;

    ## demand factory
    attr_accessor :demandFactory ;
    ## SAV allocator
    attr_accessor :allocator ;
    ## SAV reporter
    attr_accessor :reporter ;
    ## feature table (static PoI and Area)
    attr_accessor :featureTable ;

    ## margin of stop in picking-up and dropping-off [m]
    attr_accessor :stopMargin ;
    
    ## total number of SAV
    attr_accessor :nSavMax ;
    ## interval to add SAV
    attr_accessor :addSavInterval ;
    
    #--------------------------------------------------------------
    #++
    ## description of method initialize
     ## _conf_:: configulation
    def initialize(conf = {})
      conf[:vehicleManagerConf] =
        (conf[:vehicleManagerConf].nil? ?
           DefaultVehicleManagerConf :
           DefaultVehicleManagerConf.dup.update(conf[:vehicleManagerConf])) ;
      super(conf) ;
    end

    #--------------------------------------------------------------
    #++
    ## setup
    def setup()
      super() ;

      @vehicleType = getConf(:vehicleType) ;
      
      @savBaseTable = {} ;
      @savBaseList = [] ;
      @stopMargin = getConf(:stopMargin) ;

      @addSavInterval = getConf(:addSavInterval) ;

      setupFeatureTable() ;
      setupDemandFactory() ;
      setupAllocator() ;
      setupReporter() ;

      @nSavMax = getConf(:nSavMax) || getConf(:savN) ;
      @nSavMax = @allocator.nSavMax() if(@nSavMax.nil?) ;

      return self ;
    end
      
    #--------------------------------------------------------------
    #++
    ## setup Sumo Map
    ## _conf_ :: configulation for PoiManager.
    def setupMap(conf = {})
      super(conf) ;

      @poiManager.poiConf[:map] = @map ;
    end

    #--------------------------------------------------------------
    #++
    ## setup Demand Factory
    ## _conf_ :: configulation for the factory
    def setupDemandFactory(conf = {})
      factoryClass = getConf(:demandFactoryClass) ;

      if(!factoryClass.nil?) then
        factoryConf = getConf(:demandFactoryConf).dup.update(conf) ;
        @demandFactory = factoryClass.new(self, factoryConf) ;
      end
    end

    #--------------------------------------------------------------
    #++
    ## setup Sav Allocator
    ## _conf_ :: configulation for the allocator
    def setupAllocator(conf = {})
      allocatorConf = getConf(:allocatorConf).dup.update(conf) ;
      
      @allocator =
        Sav::SavAllocator.newAllocatorByConf(self,
                                             getConf(:allocatorClass),
                                             allocatorConf) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## setup Sav Reporter
    ## _conf_ :: configulation for the allocator
    def setupReporter(conf = {})
      reporterClass = getConf(:reporterClass) ;

      if(!reporterClass.nil?) then
        reporterConf = getConf(:reporterConf).dup.update(conf) ;
        @reporter = reporterClass.new(self, reporterConf) ;
      end
    end

    #--------------------------------------------------------------
    #++
    ## setup Savs Feature Table
    ## _conf_ :: configulation for the allocator
    def setupFeatureTable()
      @featureTable = {} ;
      file = getConf(:featureTableFile) ;
      if(!file.nil?) then
        open(file,"r"){|strm|
          json = JSON.load(strm,nil,{:symbolize_names => true,
                                     :create_additions => false}) ;
          poiList = json[:savsPoi] ;
          poiList.each{|poi|
            feature = GeoFeature::PoI.new(poi, @map) ;
            @featureTable[feature.name] = feature ;
          }
          zoneList = json[:savsZone] ;
          zoneList.each{|zone|
            feature = GeoFeature::Zone.new(zone, @map) ;
            @featureTable[feature.name] = feature ;
          }
        }
      end
    end
    
    #--------------------------------------------------------------
    #++
    ## add SavBase
    ## _savBase_:: savBase
    ## *return*:: savBase
    def addSavBase(base)
      @savBaseList.push(base) ;
      @savBaseTable[base.name] = base ;
      return base ;
    end

    #-------------------------------
    #++
    ## add sav base by position.
    ## _pos_:: the position of the edge in Geo2D::Point or [x,y]
    ## _name_:: the name of the base.
    ## _addPoiP_:: if true, add the base as PoI on the map.
    ## *return*:: edge
    def addNewSavBaseByPos(pos, name = nil, addPoiP = true)
      pos = Geo2D::Point.sureGeoObj(pos) ;
      base = SavBase.new(self, pos, name, addPoiP) ;
      return addSavBase(base) ;
    end

    #-------------------------------
    #++
    ## add base edge by position.
    ## _lonlat_:: the position of the edge in Geo2D::Point or [lon,lat]
    ## *return*:: edge
    def addNewSavBaseByLonLat(lonlat, name = nil, addPoiP = true)
      lonlat = Geo2D::Point.sureGeoObj(lonlat) ;
      pos = self.map.transformLonLat2XY(lonlat) ;
      return addNewSavBaseByPos(pos, name, addPoiP) ;
    end

    #--------------------------------------------------------------
    #++
    ## get sav list.
    def savList()
      @vehicleManager.vehicleList ;
    end

    #--------------------------------------------------------------
    #++
    ## each Sav iteration.
    alias eachSav eachVehicle ;

    #--------------------------------------------------------------
    #++
    ## run Sumo with block
    ## _loopConf_ :: configulation for run loop.
    ## _*args_ :: args to pass to the block.
    ## _&block_ :: block to execute every cycle.  called with (self, *args)
    def run(loopConf = {}, *args, &block)
      saveConfigLog() if (getConf(:configLogFile)) ;
      begin
        super(loopConf, *args){|sim, *_args|
          cycleAfterSumo() ;

          addNewSavIfNeed() ;

          block.call(sim, *_args) if(!block.nil?) ;
        
          cycleBeforeSumo() ;
        }
      ensure
        dumpOperationLogFiles() ;
      end
    end

    #--------------------------------------------------------------
    #++
    ## add new sav if need.
    def addNewSavIfNeed()
      if(@nSavMax &&
         savList().size < @nSavMax &&
         (cycleCount() % @addSavInterval == 0)) then
        addNewSavVehicleToBase() ;
      end
    end

    #--------------------------------------------------------------
    #++
    ## add sav vehicle and assign to a sav base
    ## _savBase_:: sav base
    ## *return*:: new sav
    def addNewSavVehicleToBase(savBase = nil) ;
      @allocator.addNewSavVehicleToBase(savBase) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## cycle called just after Sumo execution
    def cycleAfterSumo()
      cycleCheckViaPoint() ;
      cycleCheckProcessingDemands() ;
      cycleReport() ;
    end
    
    #--------------------------------------------------------------
    #++
    ## cycle called just beforer Sumo execution
    def cycleBeforeSumo()
      cycleUpdateDemandAllocation() ;
      cycleRenewTargetIfNeed() ;
    end
    
    #--------------------------------------------------------------
    #++
    ## cycle to check ViaPoint
    def cycleCheckViaPoint()
      eachSav(){|sav|
        if(!sav.isAlive()) then
          logging(:warn,
                  "sav(#{sav.id}) is vanished. re-submit at #{@currentTime}.") ;
#          sav.resubmitAddVehicle(@currentTime,true) ;
          sav.resubmitAddVehicle(:triggered,true) ;          
          sav.setNextViaPointAsTarget() ;
        end
        sav.cycleCheckViaPoint() ;
      } ;
    end
    
    #--------------------------------------------------------------
    #++
    ## cycle to check complision of demands
    def cycleCheckProcessingDemands()
      if(@demandFactory) then
        @demandFactory.cycleCheckProcessingList() ;
      end
    end
    
    #--------------------------------------------------------------
    #++
    ## cycle for report
    def cycleReport()
      @reporter.report() if(@reporter) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## cycle to demand allocation.
    def cycleUpdateDemandAllocation()
      demandList = (@demandFactory.nil? ?
                      [] :
                      @demandFactory.newDemandListForCycle()) ;
      if(@allocator) then
        @allocator.allocate(demandList) ;
        @demandFactory.registerNewDemandList(@allocator.allocatedList,
                                             @allocator.cancelledList) ;
      end
    end
      
    #--------------------------------------------------------------
    #++
    ## cycle to check ViaPoint
    def cycleRenewTargetIfNeed()
      eachSav(){|sav| sav.cycleRenewTargetIfNeed()} ;
    end

    #--------------------------------------------------------------
    #++
    ## save config info into log
    def saveConfigLog()
      file = getConf(:configLogFile) ;
      Util.ensureDir(file) ;
      open(file, "w"){|strm|
        json = @conf.dup ;
        json['__class__'] = self.class.to_s ;
        strm << JSON.pretty_generate(json) << "\n" ;
      }
    end
    
    #--------------------------------------------------------------
    #++
    ## dump operation log files.
    def dumpOperationLogFiles() ;
      dumpTrailLog() if (getConf(:trailLogFile)) ;
      dumpAllocLog() if (getConf(:allocLogFile)) ;
      dumpPartyLog() if (getConf(:partyLogFile)) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## dump trail log
    def dumpTrailLog()
      file = getConf(:trailLogFile) ;
      Util.ensureDir(file) ;
      open(file, "w"){|strm|
        eachVehicle(){|sav|
          json = sav.trailJson() ;
          strm << JSON.generate(json) << "\n" ;
        }
      }
    end

    #--------------------------------------------------------------
    #++
    ## dump allocation log
    def dumpAllocLog()
      file = getConf(:allocLogFile) ;
      Util.ensureDir(file) ;
      open(file, "w"){|strm|
        @allocator.dumpLogToStream(strm) ;
      }
    end

    #--------------------------------------------------------------
    #++
    ## dump party log
    def dumpPartyLog()
      @demandFactory.dumpPartyLog(getConf(:partyLogFile)) ;
    end
          
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class SavSimulator < Sumo::SumoManager
end # module Sav

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  require 'SavDemandFactoryRandom.rb' ;
  require 'SavAllocatorRandom.rb' ;

  #--============================================================
  #++
  ## unit test for this file.
  class TC_SavSimulator < Test::Unit::TestCase
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## desc. for TestData
    SampleDirBase = "/home/noda/work/iss/SAVS/Data" ;
    SampleDir = "#{SampleDirBase}/2018.0104.Tsukuba"
    SampleConfFile03 = "#{SampleDir}/tsukuba.03.sumocfg" ;

    SampleConfFile04 = "#{SampleDir}/tsukuba.04.sumocfg" ;
    
    SampleXmlMapFile_S = "#{SampleDir}/TsukubaCentral.small.net.xml" ;
    SampleJsonMapFile_S = SampleXmlMapFile_S.gsub(/.xml$/,".json") ;
    SampleXmlMapFile_L = "#{SampleDir}/TsukubaCentral.net.xml" ;
    SampleJsonMapFile_L = SampleXmlMapFile_L.gsub(/.xml$/,".json") ;

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
    ## generate random demand
    def genRandomDemand(savSim, grow = 1000.0, passenger = "foo")
      mapBBox = savSim.map.bbox() ;
      midPoint = mapBBox.midPoint()
      midPoint.x -= 600.0 ; ## adjusting center for this map.
      midPoint.y += 500.0 ;
      rangeBox = midPoint.bbox() ;
      rangeBox.growByMargin(grow) ;

      pickUpPos = rangeBox.randomPoint() ;
      dropOffPos = rangeBox.randomPoint() ;
      
      return Sav::SavDemand.new(passenger,
                                Trip.new(pickUpPos, dropOffPos),
                                savSim) ;
    end
    
    #----------------------------------------------------
    #++
    ## about test_a
    def test_a
      savSim =
        Sav::SavSimulator.new({ :sumoConfigFile => SampleConfFile03,
                                :guiMode => :gui,
#                                :guiMode => :guiQuit,
                                :traciClientConf => {
                                  :logDev => [:stdout, :file],
#                                  :logLevel => :debug,
                                  :logLevel => :info,
#                                  :logLevel => :warn,
                                  },
                                :mapFile => SampleJsonMapFile_S,
                              }) ;
      ## setup base edge
      mapBBox = savSim.map.bbox() ;
      posTopCenter = Geo2D::Point.new(mapBBox.midX(), mapBBox.maxY()) ;
      savBase = savSim.addNewSavBaseByPos(posTopCenter) ;

      savSim.run({ :delay => 0.0,
                 }){|sim|
        if(sim.cycleCount < 100 && (0 == sim.cycleCount % 10)) then 
          sav = sim.addNewSavVehicleToBase(savBase) ;
          sav.insertUTurnViaPoint(sim) ;
          sav.setNextViaPointAsTarget() ;
        end

        sim.eachVehicle(){|sav|
          if(sav.remainViaPointN() < 10) then
            demand = genRandomDemand(sim) ;
            sav.assignDemand(demand) ;
          end
        }
      }
    end

    #----------------------------------------------------
    #++
    ## about test_b
    def test_b
      savSim =
        Sav::SavSimulator.new({ :sumoConfigFile => SampleConfFile03,
                                :guiMode => :gui,
#                                :guiMode => :guiQuit,
                                :traciClientConf => {
                                  :logDev => [:stdout, :file],
#                                  :logLevel => :debug,
                                  :logLevel => :info,
#                                  :logLevel => :warn,
                                  },
                                :mapFile => SampleJsonMapFile_S,
                              }) ;
      ## setup base edge
      mapBBox = savSim.map.bbox() ;
      posTopCenter = Geo2D::Point.new(mapBBox.midX(), mapBBox.maxY()) ;
      savBase = savSim.addNewSavBaseByPos(posTopCenter) ;

      savSim.run({ :delay => 0.0,
                 }){|sim|
        
        if(sim.savList.size < 20 && (0 == sim.cycleCount % 10)) then 
          sav = sim.addNewSavVehicleToBase(savBase) ;
#          sav.insertUTurnViaPoint(sim) ;
#          sav.setNextViaPointAsTarget() ;
        end

        if(0 == sim.cycleCount % 30) then
          sav = sim.savList.sample() ;
          if(!sav.nil? && sav.remainViaPointN() < 5) then
            demand = genRandomDemand(sim) ;
            sav.assignDemand(demand) ;
          end
        end

      }

    end

    #----------------------------------------------------
    #++
    ## about test_c (using DemandFactory)
    def test_c
      savSim =
        Sav::SavSimulator.new({ :sumoConfigFile => SampleConfFile03,
                                :guiMode => :gui,
#                                :guiMode => :guiQuit,
                                :traciClientConf => {
                                  :logDev => [:stdout, :file],
#                                  :logLevel => :debug,
#                                  :logLevel => :info,
                                  :logLevel => :warn,
                                  },
                                :mapFile => SampleJsonMapFile_S,
                                :demandFactoryClass =>
                                Sav::SavDemandFactoryRandom,
                                :demandFactoryConf => {
                                  :offset => Geo2D::Point.new(-600,500),
                                  :rangeSize => 2000.0,
                                  :frequency => 1.0 / 30.0,
                                  :minDistance => 500.0,
                                },
                                :allocatorClass => Sav::SavAllocatorRandom,
                                :allocatorConf => {
                                },
                                :reporterClass => Sav::SavReporter,
                                :reporterConf => {
                                  :reportInterval => 10,
                                  :reportLogLevel => :info,
                                },
                              }) ;
      ## setup base edge
      mapBBox = savSim.map.bbox() ;
      posTopCenter = Geo2D::Point.new(mapBBox.midX(), mapBBox.maxY()) ;
      savBase = savSim.addNewSavBaseByPos(posTopCenter) ;

      savSim.run({ :delay => 0.0,
                 }){|sim|

        # prepare set of SAVS.
        if(sim.savList.size < 20 && (0 == sim.cycleCount % 10)) then 
          sav = sim.addNewSavVehicleToBase(savBase) ;
#          sav = sim.addNewSavVehicleToBase(savBase) ;
#          sav.insertUTurnViaPoint(sim) ;
#          sav.setNextViaPointAsTarget() ;
        end

      }

    end

    #----------------------------------------------------
    #++
    ## about test_d (using DemandFactory) (with Large map)
    def test_d
      savSim =
        Sav::SavSimulator.new({ :sumoConfigFile => SampleConfFile04,
                                :guiMode => :gui,
#                                :guiMode => :guiQuit,
                                :traciClientConf => {
                                  :logDev => [:stdout, :file],
#                                  :logLevel => :debug,
                                  :logLevel => :info,
#                                  :logLevel => :warn,
                                  },
                                :mapFile => SampleJsonMapFile_L,
                                :demandFactoryClass =>
                                Sav::SavDemandFactoryRandom,
                                :demandFactoryConf => {
                                  :offset => Geo2D::Point.new(-600,-1000),
                                  :rangeSize => 8000.0,
                                  :frequency => 1.0 / 1.0,
                                },
                                :allocatorClass => Sav::SavAllocatorRandom,
                                :allocatorConf => {
                                },
                                :reporterClass => Sav::SavReporter,
                                :reporterConf => {
                                  :reportInterval => 30,
                                  :reportLogLevel => :info,
                                },
                              }) ;
      ## setup base edge
      mapBBox = savSim.map.bbox() ;
      posTopCenter = Geo2D::Point.new(mapBBox.midX(), mapBBox.midY()) ;
      savBase = savSim.addNewSavBaseByPos(posTopCenter) ;

      savSim.run({ :delay => 0.0,
                 }){|sim|

        # prepare set of SAVS.
        if(sim.savList.size < 100 && (0 == sim.cycleCount % 10)) then 
          sav = sim.addNewSavVehicleToBase(savBase) ;
#          sav.insertUTurnViaPoint(sim) ;
#          sav.setNextViaPointAsTarget() ;
        end

      }

    end
    

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
