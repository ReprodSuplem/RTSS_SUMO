#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Traci Vehicle Manager class
## Author:: Anonymous3
## Version:: 0.0 2018/01/04 Anonymous3
##
## === History
## * [2018/01/04]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'TraciUtil.rb' ;
require 'TraciVehicle.rb' ;

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
    ## Traci::Vehicle
    class VehicleManager < WithConfParam
      #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      #++
      ## description of DefaultOptsions.
      DefaultConf = { :defaultVehicleClass => Vehicle,
                      :vehicleConf => {},
                      :traciClient => nil,
                      :vehicleIdPrefix => "foo",
                      :vehicleIdNumberingFormat => "%05d",
                      nil => nil } ;

      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## vehicle table { id => vehicle }
      attr_accessor :vehicleTable ;
      ## vehicle list
      attr_accessor :vehicleList ;
      ## new vehicle list [ vehicle, vehicle, ...]
      attr_accessor :newVehicleList ;
      ## finished vehicle list [ vehicle, vehicle, ...]
      attr_accessor :finishedVehicleList ;
      ## default class of Vehicle instance
      attr_accessor :defaultVehicleClass ;
      ## traci client
      attr_accessor :traciClient ;
      ## vehicle ID prefix
      attr_accessor :vehicleIdPrefix ;
      ## vehicle ID numbering format
      attr_accessor :vehicleIdNumberingFormat ;
      ## vehicle counter
      attr_accessor :vehicleIdCounter ;

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
        @vehicleTable = {} ;
        @vehicleList = [] ;
        @newVehicleList = [] ;
        @finishedVehicleList = [] ;
        @defaultVehicleClass = getConf(:defaultVehicleClass) ;
        @vehicleConf = getConf(:vehicleConf) ;
        @vehicleIdPrefix = getConf(:vehicleIdPrefix) ;
        @vehicleIdNumberingFormat = getConf(:vehicleIdNumberingFormat) ;
        @vehicleIdCounter = 0 ;
        setTraciClient(getConf(:traciClient)) ;
      end

      #--------------------------------------------------------------
      #++
      ## generate novel vehicle ID
      def novelVehicleId()
        begin
          newId = ("#{@vehicleIdPrefix}_#{@vehicleIdNumberingFormat}" %
                   @vehicleIdCounter) ;
          @vehicleIdCounter += 1 ;
        end while(@vehicleTable[newId]) ;
        return newId ;
      end

      #--------------------------------------------------------------
      #++
      ## set traci client
      ## _client_:: instance of TraciClient or nil
      def setTraciClient(client)
        @traciClient = client ;
      end

      #--------------------------------------------------------------
      #++
      ## fetch whole vehicle ID list
      def fetchVehicleIdList()
        com = Sumo::Traci::Command_GetVariable.new(:vehicle, :idList, "") ;
        @traciClient.execCommands(com) ;
        return com.responseValue() ;
      end

      #--------------------------------------------------------------
      #++
      ## create new vehicle that already exists in SUMO.
      ## _vehicleId_ :: vehicle ID
      ## *return* :: instance of Vehicle
      def newVehicle(vehicleId, conf={})
        vConf = @vehicleConf.dup.update(conf) ;
        vehicle = @defaultVehicleClass.new(self, vehicleId, vConf) ;
        @vehicleTable[vehicleId] = vehicle ;
        @vehicleList.push(vehicle) ;
        return vehicle ;
      end
      
      #--------------------------------------------------------------
      #++
      ## update Vehicle Table.
      ## if new vehicle appear, create new Vehicle and add to the table.
      ## *return* :: list of new vehicles.
      def updateVehicleTableWhole()
        @newVehicleList.clear() ;
        @finishedVehicleList.clear() ;

        # get vehicle id list
        idList = fetchVehicleIdList() ;

        idTable = {} ;
        idList.each{|vId|
          idTable[vId] = vId ;
          if(@vehicleTable[vId].nil?) then
            #length
            newVehicle = newVehicle(vId, {}) ;
            @newVehicleList.push(newVehicle) ;

            newVehicle.submitAll() ;
          end
        }
        @vehicleList.each{|vehicle|
          if(vehicle.isOnRoad?() && idTable[vehicle.id].nil?) then
            @finishedVehicleList.push(vehicle) ;
            vehicle.letFinished() ;
          end
        }

        return @newVehicleList ;
      end

      #--------------------------------------------------------------
      #++
      ## generate lane ID
      ## _edgeId_ :: edge ID (String)
      ## _laneIndex_ :: index of the lane in the edge
      ## *return* :: lane index
      def generateLaneId(edgeId, laneIndex)
        return "#{edgeId}_#{laneIndex}" ;
      end

      #--------------------------------------------------------------
      #++
      ## fetchLaneLength
      ## _laneId_ :: lane ID or edge ID.  if edge ID, need lane index;
      ## _laneIndex_ :: lane index in the edge
      ## *return* :: lane length
      def fetchLaneLength(laneId, laneIndex = nil)
        laneId = generateLaneId(laneId, laneIndex) if(!laneIndex.nil?) ;
        com = Sumo::Traci::Command_GetVariable.new(:lane, :length, laneId) ;
        @traciClient.execCommands(com) ;
        return com.responseValue() ;
      end

      #--------------------------------------------------------------
      #++
      ## submit new route
      ## _vehicleType_ :: vehicle type (String)
      ## _route_ :: route ID (String)
      ## _time_ :: depart time (Integer)
      ## _departPos_ :: position to depart on the lane (Double)
      ## _speed_ :: initial speed (Double)
      ## _laneIndex_ :: lane index to depar
      def submitNewRoute(routeId, edgeList)
        com = Sumo::Traci::Command_SetVariable.new(:route, :addRoute,
                                                   routeId, edgeList) ;
        @traciClient.execCommands(com) ;
      end

      #--------------------------------------------------------------
      #++
      ## submit new vehicle
      ## _conf_:: config prams for new Vehicle.
      ## _vehicleType_ :: vehicle type (String)
      ## _route_ :: route ID (String)
      ## _time_ :: depart time (Integer) or Symbol
      ##           (:triggered, :containerTriggered)
      ## _departPos_ :: position to depart on the lane (Double) or Symbol
      ##           (:random, :free, :base, :last, :random_free)
      ## _speed_ :: initial speed (Double)
      ## _laneIndex_ :: lane index to depar
      ## *return* :: new vehicle
      def submitNewVehicle(conf, vehicleType, route, time = nil,
                           departPos = 0.0, speed = 0.0, laneIndex = 0)
        vehicleId = novelVehicleId() ;
        
        vehicle = newVehicle(vehicleId, conf) ;

        vehicle.submitAddVehicle(vehicleType, route, time, departPos,
                                 speed, laneIndex);

        return vehicle ;
      end


      #--------------------------------------------------------------
      #++
      ## remove vehicle.
      ## _vehicle_ :: vehicle to remove.
      ## *return* :: instance of Vehicle
      def submitRemoveVehicle(vehicle, checkP = true)
        vehicle.submitRemove() if(checkP && vehicle.isAlive()) ;
        @vehicleTable.delete(vehicle.id) ;
        @vehicleList.delete(vehicle) ;

        return vehicle ;
      end

      #--------------------------------------------------------------
      #++
      ## check vehicle is alive or drop it.
      ## _vehicle_ :: vehicle ID
      ## *return* :: true if the vehicle is alive.
      def checkVehicleAliveOrDrop(vehicle) ;
        if(vehicle.isAlive())
          return true ;
        else
          submitRemoveVehicle(vehicle, false) ;
          return false ;
        end
      end
          
      #--============================================================
      #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #--------------------------------------------------------------
    end # class VehicleManager

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
  class TC_VehicleManager < Test::Unit::TestCase
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

    #----------------------------------------------------
    #++
    ## run with manager using simple map
    def test_a
      traci =
        Sumo::Traci::Client.newWithServer(SampleConfFile,
                                          { :logDev => [:stdout,:file],
#                                            :logLevel => :debug,
                                           :logLevel => :info,
                                          },
                                          :gui) ;
      #
      managerConf = { :traciClient => traci,
                      nil => nil }
      vManager = Sumo::Traci::VehicleManager.new(managerConf) ;

      # loop
      step = 0 ;
      ustep = 100 ;
      delay = 0.001 ;
      while(step < 2000*1000)
        # simulation を進める。
        step += ustep
        com = Sumo::Traci::Command_SimulationStep.new(step) ;
        traci.execCommands(com) ;

        #update
        vManager.updateVehicleTableWhole() ;

        #slow down
        if(rand(10) == 0) then
          vehicle = vManager.vehicleList.sample() ;
          if(!vehicle.nil?) then
            speed = 10 * rand() ;
            duration = 1.0 ;
            vehicle.submitSlowDown(speed, duration) ;
          end
        end
          
        #sleep
        sleep(delay) ;
      end
      
    end

    #----------------------------------------------------
    #++
    ## run with manager using Tsukuba map
    def test_b
      traci =
        Sumo::Traci::Client.newWithServer(SampleConfFile2,
                                          { :logDev => [:stdout,:file],
#                                            :logLevel => :debug,
                                            :logLevel => :info,
                                          },
                                          :gui) ;
      #
      managerConf = { :traciClient => traci,
                      nil => nil }
      vManager = Sumo::Traci::VehicleManager.new(managerConf) ;

      # loop
      step = 0 ;
      ustep = 100 ;
      delay = 0.001 ;
      while(step < 10000*1000)
        # simulation を進める。
        step += ustep
        com = Sumo::Traci::Command_SimulationStep.new(step) ;
        traci.execCommands(com) ;

        #update
        vManager.updateVehicleTableWhole() ;

        #slow down
        if(rand(10) == 0) then
          vehicle = vManager.vehicleList.sample() ;
          if(!vehicle.nil? && vehicle.isOnRoad?()) then
            speed = 10 * rand() ;
            duration = 1.0 ;
            vehicle.submitSlowDown(speed, duration) ;
            pp [:edgeList, vehicle.fetchRouteIndex(), vehicle.fetchEdgeList() ];
          end
        end
          
        #sleep
        sleep(delay) ;
      end
      traci.closeServer() ;
    end
      
    #----------------------------------------------------
    #++
    ## run with manager using Tsukuba map
    def test_c
      traci =
        Sumo::Traci::Client.newWithServer(SampleConfFile2b,
                                          { :logDev => [:stdout,:file],
#                                            :logLevel => :debug,
#                                            :logLevel => :info,
                                            :logLevel => :warn,
                                          },
                                          :gui) ;
      #
      managerConf = { :traciClient => traci,
                      nil => nil }
      vManager = Sumo::Traci::VehicleManager.new(managerConf) ;

      # loop
      step = 0 ;
      ustep = 100 ;
      delay = 0.001 ;

      specialId = "trip01" ;
      specialTargetList = ['30436595#1', '67124894#1'] ;

      while(step < 10000*1000)
        # simulation を進める。
        step += ustep
        com = Sumo::Traci::Command_SimulationStep.new(step) ;
        traci.execCommands(com) ;

        #update
        vManager.updateVehicleTableWhole() ;

        #
        gened = false ;
        if(v = vManager.vehicleTable[specialId]) then
          if(v.isOnRoad?()) then
            gened = true ;
            v.fetchAllDynamic() ;
            pp [:loc, v.location, l] ;
            if(rand(40) == 0) then
              v.submitChangeTarget(specialTargetList.sample) ;
            end
          elsif(gened)
            exit ;
          end
        end
        
        #sleep
        sleep(delay) ;
      end
      traci.closeServer() ;
    end

    #----------------------------------------------------
    #++
    ## add new vehicle
    ## submitNewVehicle した後には、changeTarget をしないと、うまく動かない。
    ## おそらく、edges が１つだけだから？
    def test_d
      traci =
        Sumo::Traci::Client.newWithServer(SampleConfFile2b,
                                          { :logDev => [:stdout,:file],
#                                            :logLevel => :debug,
#                                            :logLevel => :info,
                                            :logLevel => :warn,
                                          },
                                          :gui) ;
      #
      managerConf = { :traciClient => traci,
                      nil => nil }
      vManager = Sumo::Traci::VehicleManager.new(managerConf) ;

      # loop
      c = 0 ;
      step = 0 ;
      ustep = 100 ;
      delay = 0.001 ;

      while(step < 10000*1000)
        # simulation を進める。
        c += 1;
        step += ustep
        com = Sumo::Traci::Command_SimulationStep.new(step) ;
        traci.execCommands(com) ;

        if(c % 100 == 0) then
          p [:c, c]
          newVehicle = vManager.submitNewVehicle({}, "itk00","foo", step) ;
          # newVehicle.submitResume() ;
          newVehicle.submitChangeTarget('67124894#1') ;
        end
        #sleep
        sleep(delay) ;
      end
      traci.closeServer() ;
    end

    #----------------------------------------------------
    #++
    ## moteTo
    def test_e
      traci =
        Sumo::Traci::Client.newWithServer(SampleConfFile2b,
                                          { :logDev => [:stdout,:file],
#                                            :logLevel => :debug,
#                                            :logLevel => :info,
                                            :logLevel => :warn,
                                          },
                                          :gui) ;
      #
      managerConf = { :traciClient => traci,
                      nil => nil }
      vManager = Sumo::Traci::VehicleManager.new(managerConf) ;

      edge0 = '30436599#0' ;
      edgeLen0 = 2340.0 ;

      vManager.submitNewRoute("bar00",[edge0]) ;

      # loop
      c = 0 ;
      step = 0 ;
#      ustep = 100 ;
      ustep = 1000 ;
#      delay = 0.001 ;
      delay = 0.000 ;

      newVehicle = nil ;
      while(step < 10000*1000)
        traci.fetchSimulationTime() ;
        # simulation を進める。
        c += 1;
        step += ustep
        com = Sumo::Traci::Command_SimulationStep.new(step) ;
        traci.execCommands(com) ;

        if(c % 100 == 0) then
          newVehicle = vManager.submitNewVehicle({}, "itk00","bar00", step) ;
          # newVehicle.submitResume() ;
          newVehicle.submitMoveTo([edge0, 0], rand(edgeLen0)) ;
          newVehicle.submitChangeTarget('130219860') ;
          newVehicle.submitColor('red') ;
          # to test stop
          route = newVehicle.fetchEdgeList() ;
          edge = route[1] ;
          edgeLength = vManager.fetchLaneLength(edge,0) ;
          newVehicle.submitStop(edge, edgeLength/2, 0, 100) ;

        end
        #sleep
        sleep(delay) ;

        if(newVehicle)
          newVehicle.fetchAllDynamic() ;
#          p [:stopState, newVehicle] ;
        end
      end
      traci.closeServer() ;
    end
    
  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
