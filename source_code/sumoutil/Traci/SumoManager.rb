#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Sumo Manager class
## Author:: Anonymous3
## Version:: 0.0 2018/01/21 Anonymous3
##
## === History
## * [2018/01/21]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

require 'time' ;

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'WithConfParam.rb' ;
require 'TraciUtil.rb' ;
require 'TraciClient.rb' ;
require 'TraciVehicleManager.rb' ;
require 'TraciPoiManager.rb' ;
require 'SumoMap.rb' ;

#--===========================================================================
#++
## package for SUMO
module Sumo

  #--======================================================================
  #++
  ## Sumo::SumoManager
  class SumoManager < WithConfParam
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of Default Loop Config
    DefaultLoopConf = { :step => 1,    # step size for one cycle in sec.
                        :delay => 0.0,  # delay for one cycle.
                        :until => nil, # maximum cycle in sec. if nil, eternal.
                        :closeAtEnd => true, # if true, close when loop ends.
                        :logInterval => 100, # indicater of loop progress.
                                             # 0 or nil is no indicate.
                        nil => nil } ;
    
    ## description of Default Config
    DefaultConf = { :openClient => true,
                    :sumoConfigFile => nil,
                    :guiMode => :guiQuit,  ## [:none, :gui, :guiQuit]
                    :portScanFrom => Traci::Client::SumoTraciPort_ScanFrom,
                    :traciClient => nil,
                    :traciClientConf => {},
                    :vehicleManager => nil,
                    :vehicleManagerConf => {},
                    :vehicleConf => {},
                    :poiManager => nil,
                    :poiManagerConf => {},
                    :mapFile => nil,
                    :mapConf => {:buildRTrees =>true},
                    :loopConf => {},
                    :timeOrigin => "00:00:00",
                    nil => nil } ;

    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## traci client.
    attr_accessor :traciClient ;
    ## vehicle manager.
    attr_accessor :vehicleManager ;
    ## PoI manager.
    attr_accessor :poiManager ;
    ## Sumo Map
    attr_accessor :map ;
    ## current time (in sec)
    attr_accessor :currentTime ;
    ## cycle count (the number of steps in the simulation run).
    attr_accessor :cycleCount ;
    ## origin of time.
    attr_accessor :timeOrigin ;

    #--------------------------------------------------------------
    #++
    ## description of method initialize
    ## _conf_:: configulation
    def initialize(conf = {})
      super(conf) ;
      setup() ;
    end

    #--------------------------------------------------------------
    #++
    ## setup
    def setup()
      if(getConf(:openClient)) then
        setupTraciClientWithServer() ;
        setupVehicleManager() ;
        setupPoiManager() ;
      else
        @traciClient = getConf(:traciClient) ;
        @vehicleManager = getConf(:vehicleManager) ;
        @poiManager = getConf(:poiManager) ;
      end

      @timeOrigin = Time.parse(getConf(:timeOrigin)) ;

      setupMap() ;
      
      return self ;
    end

    #--------------------------------------------------------------
    #++
    ## current time in String
    def currentTimeInString()
      time = @timeOrigin + @currentTime ;
      return time.strftime(TimeStrFormat) ;
    end

    ## Time String Format
    TimeStrFormat = "%H:%M:%S.%L" ;

    #--------------------------------------------------------------
    #++
    ## setup new TraciClient.
    ## _conf_ :: configulation for TraciClient.
    def setupTraciClientWithServer(conf = {})
      clientConf = getConf(:traciClientConf).dup.update(conf) ;
      sumoConfig = getConf(:sumoConfigFile) ;
      if(sumoConfig.nil?) then
        raise ("need sumo config file to start TraciClient. conf=" +
               clientConf.inspect) ;
      end
      
      @traciClient = Traci::Client.newWithServer(sumoConfig,
                                                 clientConf,
                                                 getConf(:guiMode),
                                                 getConf(:portScanFrom)) ;
      return @traciClient ;
    end
    
    #--------------------------------------------------------------
    #++
    ## setup new VehicleManager.
    ## _conf_ :: configulation for VehicleManager.
    def setupVehicleManager(conf = {})
      managerConf = getConf(:vehicleManagerConf).dup.update(conf) ;
      managerConf[:vehicleConf].update(getConf(:vehicleConf)) ;
      managerConf[:traciClient] = @traciClient ;
      @vehicleManager = Sumo::Traci::VehicleManager.new(managerConf) ;

      return @vehicleManager ;
    end
      
    #--------------------------------------------------------------
    #++
    ## setup new PoI Manager.
    ## _conf_ :: configulation for PoiManager.
    def setupPoiManager(conf = {})
      managerConf = getConf(:poiManagerConf).dup.update(conf) ;
      managerConf[:traciClient] = @traciClient ;
      @poiManager = Sumo::Traci::PoiManager.new(managerConf) ;

      return @poiManager ;
    end

    #--------------------------------------------------------------
    #++
    ## setup Sumo Map
    ## _conf_ :: configulation for PoiManager.
    def setupMap(conf = {})
      mapConf = getConf(:mapConf).dup.update(conf) ;
      mapFile = getConf(:mapFile) ;
      dumpFile = getConf(:mapDumpFile) ;

      if(!dumpFile.nil?) then
        @map = SumoMap.restoreFromFile(dumpFile) ;
        @map.setLogger(self) ;
      elsif(!mapFile.nil?) then
        @map = SumoMap.new() ;
        @map.setLogger(self) ;
        case(mapFile)
        when(/\.json$/) ;
          @map.loadJsonFile(mapFile) ;
        when(/\.xml$/) ;
          @map.loadXmlFile(mapFile) ;
        else
          raise "unknown suffix for mapfile: #{mapFile}" ;
        end
        @map.buildRTrees() if(mapConf[:buildRTrees]) ;
      end
    end
    

    #--------------------------------------------------------------
    #++
    ## access utility to vehicle list
    def vehicleList()
      @vehicleManager.vehicleList ;
    end

    #--------------------------------------------------------------
    #++
    ## access utility to vehicle list
    def vehicleTable()
      @vehicleManager.vehicleTable ;
    end
    
    #--------------------------------
    #++
    ## logging
    def logging(level, *messageList, &body)
      @traciClient.logging(level, *messageList, &body) ;
    end

    #--------------------------------------------------------------
    #++
    ## run Sumo with block
    ## _loopConf_ :: configulation for run loop.
    ## _*args_ :: args to pass to the block.
    ## _&block_ :: block to execute every cycle.  called with (self, *args)
    def run(loopConf = {}, *args, &block)
      loopConf =
        DefaultLoopConf.dup.update(getConf(:loopConf)).update(loopConf);
      untilTime = loopConf[:until] ;
      step = loopConf[:step] ;
      delay = loopConf[:delay] ;
      interval = loopConf[:logInterval].to_i ;
      
      begin
        @cycleCount = 0 ;
        @currentTime = fetchSimulationTimeInSec() ;
        while(untilTime.nil? || @currentTime < untilTime)
          advanceTime = Sumo::Util.convertSecToSimUnits(@currentTime + step) ;
          com = Sumo::Traci::Command_SimulationStep.new(advanceTime) ;
          @traciClient.execCommands(com) ;
          
          @currentTime = fetchSimulationTimeInSec() ;
          @cycleCount += 1 ;

          block.call(self, *args) ;
          
          if(interval > 0 && (@cycleCount % interval == 0)) then
            logging(:info, "loop count=" + @cycleCount.to_s) ;
          end
          sleep(delay)
        end
      ensure
        @traciClient.closeServer() if(loopConf[:closeAtEnd]) ;
      end
    end

    #--------------------------------------------------------------
    #++
    ## fetch simulation time in sec
    def fetchSimulationTimeInSec()
      Sumo::Util.convertSimUnitsToSec(@traciClient.fetchSimulationTime()) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## cycle to check vehicle existense.
    ## (obsolute.  this is not perfect.  use Vehicle#isAlive())
    def __cycleCheckVehicles_notGood()
      vList = vehicleManager.fetchVehicleIdList() ;
      vList.each{|vid|
        vehicleManager.vehicleTable[vid].setRunningCheckTime(@currentTime) ;
      }
    end
    
    #--------------------------------------------------------------
    #++
    ## each Vehicle iteration.
    ## Usage:
    ##   self.eachVehicle(fooVal, barVal){|vehicle, foo, bar|
    ##        ... } 
    ## _*args_:: args to pass to block.
    ## _&block_ :: block to execute every cycle.  called with (self, *args)
    def eachVehicle(*args, &block)
      @vehicleManager.vehicleList.each{|vehicle|
        block.call(vehicle, *args) ;
      }
    end

    #--------------------------------------------------------------
    #++
    ## submit new vehicle
    ## _vehicleType_ :: vehicle type (String)
    ## _route_ :: route ID (String)
    ## _time_ :: depart time (Integer) or Symbol
    ##           (:triggered, :containerTriggered)
    ## _departPos_ :: position to depart on the lane (Double) or Symbol
    ##           (:random, :free, :base, :last, :random_free)
    ## _speed_ :: initial speed (Double)
    ## _laneIndex_ :: lane index to depar
    ## *return* :: new vehicle
    def submitNewVehicle(conf, vehicleType, route, departPos = 0.0,
                         speed = 0.0, laneIndex = 0)
      @vehicleManager.submitNewVehicle(conf,
                                       vehicleType, route, @currentTime,
                                       departPos, speed, laneIndex) ;
    end

    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------
  end # class Sumo::SumoManager

end # module Sumo

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_SumoManger < Test::Unit::TestCase
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
    
    SampleDir2 = "/home/noda/work/iss/SAVS/Data" ;
    SampleConfFile2 = "#{SampleDir2}/2018.0104.Tsukuba/tsukuba.01.sumocfg" ;
    SampleConfFile2b = "#{SampleDir2}/2018.0104.Tsukuba/tsukuba.02.sumocfg" ;

    SampleXmlMapFile = "#{SampleDir2}/2018.0104.Tsukuba/TsukubaCentral.small.net.xml" ;
    SampleJsonMapFile = SampleXmlMapFile.gsub(/.xml$/,".json") ;

    #----------------------------------------------------
    #++
    ## run with manager using simple map
    def test_a
      sumoMgr =
        Sumo::SumoManager.new({ :sumoConfigFile => SampleConfFile2b,
                                :guiMode => :gui,
                                :traciClientConf => {
                                  :logDev => [:stdout, :file],
#                                  :logLevel => :debug,
#                                  :logLevel => :info,
                                  :logLevel => :warn,
                                  },
                                :mapFile => SampleJsonMapFile,
                                :poiManagerConf => {
                                  :defaultPoiClass => Sumo::Traci::GroundedPoi,
                                },
                              }) ;

      mapBBox = sumoMgr.map.bbox() ;
      posTopLeft = Geo2D::Point.new(mapBBox.maxX(),mapBBox.maxY()) ;
#      edge0Name = '30436599#0' ;
#      edgeLen0 = 2340.0 ;
      edge0 = sumoMgr.map.findNearestEdgeFrom(posTopLeft) ;
      edge0Id = edge0.id ;
      edge0Len = edge0.length ;

      sumoMgr.vehicleManager.submitNewRoute("bar00",[edge0Id]) ;

      sumoMgr.run({ :step => 1,
#                    :until => 10,
                    :until => 1000,
                    :delay => 0.0,
                  }) {|manager|
#        p [:count, manager.cycleCount, manager.currentTime] ;

        ## handling new vehicle
        if(manager.cycleCount % 100 == 0) then
          newVehicle = manager.submitNewVehicle({}, "itk00", "bar00") ;
          newVehicle.submitMoveTo([edge0Id, 0], rand(edge0Len)) ;

          goodTargetP = false ;
          targetPos = nil ;
          targetEdge = nil ;
          until(goodTargetP) do
            posX = (mapBBox.maxX() - mapBBox.minX()) * rand() + mapBBox.minX() ;
            posY = (mapBBox.maxY() - mapBBox.minY()) * rand() + mapBBox.minY() ;
            targetPos = Geo2D::Point.new(posX, posY) ;
            targetEdge = sumoMgr.map.findNearestEdgeFrom(targetPos) ;
            redo if(targetEdge == edge0) ;
            goodTargetP = newVehicle.submitChangeTarget(targetEdge.id) ;
            p [:target, newVehicle.id, targetEdge.id, edge0Id, targetPos] ;
          end

          
#          newVehicle.submitChangeTarget('130219860') ;
          color = ['red', 'orange', 'green', 'blue',
                   'purple', 'maroon', 'VioletRed',
                   'salmon', 'coral', 'IndianRed',
                   'gold', 'OliveDrab', 'khaki',
                   'goldenrod', 'DarkGreen', 'aquamarine',
                   'cyan', 'turquoise'].sample ;
          newVehicle.submitColor(color) ;

          # to test stop
          route = newVehicle.fetchEdgeList() ;
          if(route.size > 1) then
            edge = route[1] ;
            edgeLength = manager.vehicleManager.fetchLaneLength(edge,0) ;
            # to test stop
            newVehicle.submitStop(edge, edgeLength/2, 0, 10) ;
          end

          gPoi = manager.poiManager.submitNewPoi(targetPos, nil,
                                                 {:edge => targetEdge}) ;
          gPoi.submitColor(color) ;
          p [:submitStopAtEdge, gPoi.to_s, gPoi.edge.id, gPoi.span] ;
          
          newVehicle.submitStopAtEdge(gPoi.edge.id, gPoi.span, 30) ;

          
          if(manager.poiManager.nPoi() > 10) then
            # remove one
            poi = manager.poiManager.poiList.first() ;
            manager.poiManager.submitRemovePoi(poi) ;
          end

        end

        manager.vehicleManager.vehicleList.each{|vehicle|
          if(manager.vehicleManager.checkVehicleAliveOrDrop(vehicle)) then
            if(vehicle.isStopped()) then
              location = vehicle.fetchLocation ;
              p [:stopped, manager.cycleCount, vehicle.id, location] ;
            end
          end
        }

      }
    end
    
  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
