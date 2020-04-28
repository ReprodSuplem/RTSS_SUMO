#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Traci Vehicle class
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

require 'Geo2D.rb' ;

require 'WithConfParam.rb' ;
require 'ExpLogger.rb' ;

require 'TraciUtil.rb' ;
require 'TraciDataType.rb' ;
require 'TraciCommand.rb' ;
require 'TraciClient.rb' ;
require 'TraciVehicleLocation.rb' ;

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
    class Vehicle < WithConfParam
      #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      #++
      ## description of DefaultOptsions.
      DefaultConf = { :length => nil,
                      :width => nil,
                      :color => "gray",
                      nil => nil } ;

      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## id of vehicle
      attr_accessor :id ;
      ## status: { :running, :finished }
      attr_accessor :status ;
      ## manager (instance of TraciVehicleManager)
      attr_accessor :manager ;
      ## length
      attr_accessor :length ;
      ## width
      attr_accessor :width ;
      ## color
      attr_accessor :color ;
      ## edgeList (route)
      attr_accessor :edgeList ;
      ## index of edgeList (current edge index)
      attr_accessor :edgeListIdx ;
      ## speed
      attr_accessor :speed ;
      ## position
      attr_accessor :pos ;
      ## location
      attr_accessor :location ;
      ## stop state
      attr_accessor :stopState ;
      
      #--------------------------------------------------------------
      #++
      ## description of method initialize
      ## _conf_:: configulation
      def initialize(manager, id = nil, conf = {})
        super(conf) ;
        setup(manager, id) ;
      end

      #--------------------------------------------------------------
      #++
      ## setup parameters
      def setup(manager, id)
        @manager = manager ;
        @id = id ;
        @length = getConf(:length) ;
        @width = getConf(:width) ;
        @color = Util.getColorValue(getConf(:color)) ;
      end
      
      #--------------------------------------------------------------
      #++
      ## check status is running
      def isOnRoad?()
        return @status == :running ;
      end
      
      #--------------------------------------------------------------
      #++
      ## make status is running
      def letRunning()
        return @status = :running ;
      end
      
      #--------------------------------------------------------------
      #++
      ## check status is finished
      def isFinished?()
        return @status == :finished ;
      end

      #--------------------------------------------------------------
      #++
      ## make status is running
      def letFinished()
        return @status = :finished ;
      end

      #--------------------------------------------------------------
      #++
      ## interpret time value to submit
      ## _time_:: time value.  number, symbol, or nil.
      ## *return* :: interpreted value.
      def interpretTimeValue(time)
        if(time.nil?) then
          return 0 ;
        elsif(time.is_a?(Symbol)) then
          return NewVehicleSpecialParam_Time[time] ;
        else
          return time ;
        end
      end
      
      #--------------------------------------------------------------
      #++
      ## fetch all static parameters via client
      ## _vehicleType_ :: vehicle type (String)
      ## _route_ :: route ID (String)
      ## _time_ :: depart time (Integer) or Symbol
      ##           (:triggered, :containerTriggered)
      ## _departPos_ :: position to depart on the lane (Double) or Symbol
      ##           (:random, :free, :base, :last, :random_free)
      ## _speed_ :: initial speed (Double)
      ## _laneIndex_ :: lane index to depar
      ## *return* :: new vehicle
      def comAddVehicle(vehicleType, route, time = nil,
                        departPos = 0.0, speed = 0.0, laneIndex = 0)
        # time
        time = interpretTimeValue(time) ;
        # departPos
        if(departPos.is_a?(Symbol))
          departPos = NewVehicleSpecialParam_DepartPos[departPos] ;
        end
        departPos = 0.0 if(departPos.nil?) ;
        # speed
        if(speed.is_a?(Symbol))
          speed = NewVehicleSpecialParam_Speed[speed] ;
        end
        speed = 0.0 if(speed.nil?);

        @initArgs = { :vehicleTypeId => vehicleType,
                      :routeId => route,
                      :departTime => time,
                      :departPosition => departPos,
                      :departSpeed => speed,
                      :departLane => laneIndex } ;
        
        com = comAddVehicleByInitArgs() ;
        
        return com ;
      end
      
      #--::::::::::::::::::::::::::::::
      #++
      ## params used in submitNewVehicle.
      ## time param.
      NewVehicleSpecialParam_Time = {
        :triggered => -1,
        :containerTriggered => -2
      } ;

      ## departPos
      NewVehicleSpecialParam_DepartPos = {
        :random => -2,
        :free => -3,
        :base => -4,
        :last => -5,
        :random_free => -6
      } ;

      ## speed
      NewVehicleSpecialParam_Speed = {
        :random => -2,
        :max => -3
      } ;
      
      #--------------------------------
      #++
      ## 再度 add する時用。
      def comAddVehicleByInitArgs()
        Sumo::Traci::Command_SetVariable.new(:vehicle, :addVehicle,
                                             @id, 
                                             @initArgs);
      end

      #--------------------------------
      #++
      ## submit add vehicle
      ## _vehicleType_ :: vehicle type (String)
      ## _route_ :: route ID (String)
      ## _time_ :: depart time (Integer) or Symbol
      ##           (:triggered, :containerTriggered)
      ## _departPos_ :: position to depart on the lane (Double) or Symbol
      ##           (:random, :free, :base, :last, :random_free)
      ## _speed_ :: initial speed (Double)
      ## _laneIndex_ :: lane index to depar
      ## *return* :: new vehicle
      def submitAddVehicle(vehicleType, route, time = nil,
                           departPos = 0.0, speed = 0.0, laneIndex = 0)
        com = comAddVehicle(vehicleType, route, time, departPos,
                            speed, laneIndex);
        ensureTraciClient(nil).execCommands(com) ;

        postSetupAfterAdd() ;
      end

      #--------------------------------
      #++
      ## re-submit add vehicle
      def resubmitAddVehicle(currentTime, useLastLoc = false)
#        renewId() ;
        
        currentTime = interpretTimeValue(currentTime) ;
        @initArgs[:departTime] = currentTime ;
        
        com = comAddVehicleByInitArgs() ;
        ensureTraciClient(nil).execCommands(com) ;

        if(useLastLoc && !@location.nil?) then
          submitChangeTarget(@location.edge);
          submitMoveTo(@location.laneId(),@location.posOnLane) ;
        end
        
        postSetupAfterAdd() ;
      end

      #--------------------------------
      #++
      ## renewId
      def renewId()
        newId = @id + "_" ;
        @manager.vehicleTable.delete(@id) ;
        @id = newId ;
        @manager.vehicleTable[@id] = self ;
      end
      
      #--------------------------------
      #++
      ## add vehicle の後処理
      def postSetupAfterAdd()
        letRunning() ;
        fetchAllStatic();
        submitColor() ;
      end
      
      #--------------------------------------------------------------
      #++
      ## fetch all static parameters via client
      def fetchAllStatic(client = nil)
        fetchLength(client) ;
        fetchWidth(client) ;
        fetchType(client) ;
      end

      #--------------------------------------------------------------
      #++
      ## fetch all dynamic parameters via client
      def fetchAllDynamic(client = nil)
        fetchEdgeList(client) ;
        fetchRouteIndex(client) ;
        fetchSpeed(client) ;
        fetchPosition(client) ;
        fetchLocation(client) ;
        fetchStopState(client) ;
#        pp [[:edgeList, @routeIndex, @edgeList],
#            [:speed, @speed],
#            [:position, @pos],
#            [:location, @location],
#           ]
      end
      
      
      #--------------------------------------------------------------
      #++
      ## submit values via client
      def submitAll(client = nil)
#        submitColor(nil, client) ;
      end

      #--------------------------------------------------------------
      #++
      ## make sure the client
      ## _client_:: TraciClient
      ## *return*:: TraciClient
      def ensureTraciClient(client)
        if(client.nil? && !@manager.nil?) then
          return @manager.traciClient ;
        elsif(client.is_a?(TraciClient)) then
          return client ;
        else
          raise "Illegal client: #{client.inspect} in Vehicle:#{self.inspect}."
        end
      end
        
      #--------------------------------------------------------------
      #++
      ## fetch length value via server
      ## _client_:: TraciClient
      ## *return*:: length
      def fetchLength(client = nil)
        client = ensureTraciClient(client) ;

        com = Sumo::Traci::Command_GetVariable.new(:vehicle, :length, @id) ;
        client.execCommands(com) ;
        @length = com.responseValue() ;
        return @length ;
      end

      #--------------------------------------------------------------
      #++
      ## fetch width value via server
      ## _client_:: TraciClient
      ## *return*:: length
      def fetchWidth(client = nil)
        client = ensureTraciClient(client) ;

        com = Sumo::Traci::Command_GetVariable.new(:vehicle, :width, @id) ;
        client.execCommands(com) ;
        @width = com.responseValue() ;
        return @width ;
      end

      #--------------------------------------------------------------
      #++
      ## fetch vehicle type
      ## _client_:: TraciClient
      ## *return*:: length
      def fetchType(client = nil)
        client = ensureTraciClient(client) ;

        com = Sumo::Traci::Command_GetVariable.new(:vehicle, :type, @id) ;
        client.execCommands(com) ;
        @type = com.responseValue() ;
        return @type ;
      end

      #--------------------------------------------------------------
      #++
      ## fetch edge list
      ## _client_:: TraciClient
      ## *return*:: length
      def fetchEdgeList(client = nil)
        client = ensureTraciClient(client) ;

        com = Sumo::Traci::Command_GetVariable.new(:vehicle, :edges, @id) ;
        client.execCommands(com) ;
        @edgeList = com.responseValue() ;
        return @edgeList ;
      end

      #--------------------------------------------------------------
      #++
      ## fetch edge list
      ## _client_:: TraciClient
      ## *return*:: route index
      def fetchRouteIndex(client = nil)
        client = ensureTraciClient(client) ;

        com = Sumo::Traci::Command_GetVariable.new(:vehicle, :routeIndex, @id) ;
        client.execCommands(com) ;
        @routeIndex = com.responseValue() ;
        return @routeIndex ;
      end

      #--------------------------------------------------------------
      #++
      ## fetch speed
      ## _client_:: TraciClient
      ## *return*:: speed
      def fetchSpeed(client = nil)
        client = ensureTraciClient(client) ;

        com = Sumo::Traci::Command_GetVariable.new(:vehicle, :speed, @id) ;
        client.execCommands(com) ;
        @speed = com.responseValue() ;
        return @speed ;
      end
      
      #--------------------------------------------------------------
      #++
      ## fetch 2D position
      ## _client_:: TraciClient
      ## *return*:: position in Geo2D::Point.
      def fetchPosition(client = nil)
        client = ensureTraciClient(client) ;

        com = Sumo::Traci::Command_GetVariable.new(:vehicle, :position, @id) ;
        client.execCommands(com) ;
        val = com.responseValue() ;
        @pos = Geo2D::Point.new(val[:x], val[:y]) ;
        return @pos ;
      end
      
      #--------------------------------------------------------------
      #++
      ## fetch location in map (edgeID, lane index, location on the lane)
      ## _client_:: TraciClient
      ## *return*:: location (Location instance)
      def fetchLocation(client = nil)
        client = ensureTraciClient(client) ;

        com0 = Sumo::Traci::Command_GetVariable.new(:vehicle, :roadId, @id) ;
        com1 = Sumo::Traci::Command_GetVariable.new(:vehicle, :laneIndex, @id) ;
        com2 = Sumo::Traci::Command_GetVariable.new(:vehicle, :lanePosition, @id) ;
        client.execCommands(com0, com1, com2) ;
        edge = com0.responseValue() ;
        laneIdx = com1.responseValue() ;
        posOnLane = com2.responseValue() ;
        @location = Location.new(edge, laneIdx, posOnLane) ;
        return @location ;
        
      end

      #--------------------------------------------------------------
      #++
      ## fetch stop status
      ## _client_:: TraciClient
      ## *return*:: list of stop state.  return nil of vehicle is not exists.
      def fetchStopState(client = nil)
        client = ensureTraciClient(client) ;

        com = Sumo::Traci::Command_GetVariable.new(:vehicle, :stopState, @id) ;

        begin
          client.execCommands(com) ;

          flagBits = com.responseValue() ;
          @stopState = Sumo::Traci::formStopFlagList(flagBits) ;
          return @stopState ;
        rescue SumoException => ex
            code = ex.param[:resultCode] ;
            if(code[:message] =~ /^Vehicle .* is not known$/) then
              return nil ;
            end
            raise ;
        end
        
      end

      #--------------------------------------------------------------
      #++
      ## check vehicle is stopped.
      ## _client_:: TraciClient
      ## *return*:: true if vehicle is stopped.
      def isStopped(client = nil)
        state = fetchStopState(client) ;
        if(state.nil?) then
          return nil ;
        elsif(state.length > 0) then
          return true ;
        else
          return false ;
        end
      end
      
      #--------------------------------------------------------------
      #++
      ## check vehicle is alive.
      ## _client_:: TraciClient
      ## *return*:: true if vehicle is alive.
      def isAlive(client = nil)
        return !fetchStopState(client).nil? ;
      end
        
      #--------------------------------------------------------------
      #++
      ## submit color
      ## _color_:: Symbol, or String of color, or Hash to specify RGBA.
      ## *return*:: color value in Hash.
      def submitColor(color = nil, client = nil)
        client = ensureTraciClient(client) ;
        
        @color = Util.getColorValue(color) if (!color.nil?) ;
        
        com = Sumo::Traci::Command_SetVariable.new(:vehicle, :color, 
                                                   @id, @color) ;
        client.execCommands(com) ;

        com.checkResultCodeIsOk() ;
        
        return @color ;
      end

      #--------------------------------------------------------------
      #++
      ## submit add stop.
      ##   <Flags> are:
      ##      1 : parking
      ##      2 : triggered
      ##      4 : containerTriggered
      ##      8 : busStop (Edge ID is re-purposed as busStop ID)
      ##     16 : containerStop (Edge ID is re-purposed as containerStop ID)
      ##     32 : chargingStation (Edge ID is re-purposed as chargingStation ID)
      ##     64 : parkingArea (Edge ID is re-purposed as parkingArea ID)
      ## _edge_:: edge ID to stop. (String)
      ## _position_:: position on the edge. (Float)
      ## _laneIndex_:: lane index in the edge. (Int)
      ## _duration_:: duration in sec (Float)
      ## _option_ :: a hash of option. one of follows:
      ##               {} or nil or { :mode => :none }
      ##               { :mode => :flag, :flags => <ArrayOfFlags> }
      ##               { :mode => :startPosition, :position => <Float> }
      ##               { :mode => :until, :until => <MSecInt> }
      ##             <ArrayOfFlags> is an Array consists of
      ##               [ :parking, :triggered, :containerTriggered, :busStop,
      ##                 :containerStop, :chargingStation, :parkingArea ]
      def submitStop(edge, position, laneIndex, duration, option = {},
                     client = nil)
        client = ensureTraciClient(client) ;

        mode = (option.nil?() ? :none : option[:mode]) ;
        mode = :none if(mode.nil?) ;

        args = { :edgeId => edge, :position => position,
                 :laneIndex => laneIndex,
                 :duration => Sumo::Util.convertSecToSimUnits(duration) } ;

        case(mode)
        when :none ;
          com = Sumo::Traci::Command_SetVariable.new(:vehicle, :stop0,
                                                     @id, args) ;
        when :flag ;
          flag = Sumo::Traci::formStopFlagBits(option[:flags]) ;
          args[:stopFlag] = flag ;
          com = Sumo::Traci::Command_SetVariable.new(:vehicle, :stop1,
                                                     @id, args) ;
        when :startPosition ; ## not work in SUMO V.0.32
          raise "this stop facility is not supported: #{mode}" ;
          args[:startPosition] = option[:position] ;
          com = Sumo::Traci::Command_SetVariable.new(:vehicle, :stop2,
                                                     @id, args) ;
        when :until ; ## not work in SUMO V.0.32
          raise "this stop facility is not supported: #{mode}" ;
          args[:until] = option[:until] ;
          com = Sumo::Traci::Command_SetVariable.new(:vehicle, :stop3,
                                                     @id, args) ;
        else
          raise "unknown stop mode : #{mode}" ;
        end

        client.execCommands(com) ;
       
      end

      #--------------------------------------------------------------
      #++
      ## submit add stop on the edge.
      ## the most syntax is the same as submitStop,
      ## but search available laneIndex.
      ## _edge_:: edge ID to stop. (String)
      ## _position_:: position on the edge. (Float)
      ## _duration_:: duration in sec (Float)
      ## _option_ :: a hash of option. one of follows
      ## *return* :: true if succeed to submit.
      def submitStopAtEdge(edge, position, duration, option = {},
                           client = nil)
        laneIndex = 0 ;
        succeedP = false ;
        until(succeedP || laneIndex > LaneIndexMax)
          begin
            submitStop(edge, position, laneIndex, duration, option, client) ;
            succeedP = true ;
          rescue SumoException => ex
            code = ex.param[:resultCode] ;
            if(code[:message] =~ /^stop for vehicle .* is not downstream/) then
              logging(:warn,
                      "laneIndex #{laneIndex} of edge " +
                      "does not in the route.") ;
              laneIndex += 1 ;
            else
              raise ;
            end
          end
        end
        return succeedP ;
      end

      ## maximum of lane index to search in submitStopAtEdge.
      LaneIndexMax = 10 ;

      #--------------------------------------------------------------
      #++
      ## submit resume
      def submitResume(client = nil)
        client = ensureTraciClient(client) ;
        
        com = Sumo::Traci::Command_SetVariable.new(:vehicle, :resume,
                                                   @id, {}) ;
        client.execCommands(com) ;
        
      end

      #--------------------------------------------------------------
      #++
      ## submit slow down
      ## _speed_:: speed value
      ## _duration_:: duration in sec (Float)
      def submitSlowDown(speed, duration, client = nil)
        client = ensureTraciClient(client) ;

        _duration = Sumo::Util.convertSecToSimUnits(duration) ;
        
        com = Sumo::Traci::Command_SetVariable.new(:vehicle, :slowDown,
                                                   @id,
                                                   { :speed => speed,
                                                     :duration => _duration }) ;
        client.execCommands(com) ;
        
      end

      #--------------------------------------------------------------
      #++
      ## submit change target
      ## _edgeId_:: target edge
      ## *return*:: true if succeed to change the target
      def submitChangeTarget(targetEdge, client = nil)
        client = ensureTraciClient(client) ;
        
        com = Sumo::Traci::Command_SetVariable.new(:vehicle, :changeTarget,
                                                   @id,
                                                   targetEdge) ;
        begin
          client.execCommands(com) ;
        rescue SumoException => ex ;
          code = ex.param[:resultCode]
          if(code[:message] =~ /^Route replacement failed/) then
            logging(:warn,
                    "Can not change target to #{targetEdge} " +
                    "for vehicle #{@id}.") ;
            return false ;
          else
            raise ;
          end
        end
        
        return true ;
        
      end

      #--------------------------------------------------------------
      #++
      ## submit move to
      ## _laneId_:: lane ID (String) or [<edgeId>, <laneIndex>]
      ##            lane ID must be included in the current route.
      ## _posInLane_ :: position in the lane
      def submitMoveTo(laneId, posInLane = 0.0, client = nil)
        client = ensureTraciClient(client) ;

        laneId = @manager.generateLaneId(*laneId) if(laneId.is_a?(Array)) ;
        
        com = Sumo::Traci::Command_SetVariable.new(:vehicle, :moveTo,
                                                   @id,
                                                   { :laneId => laneId,
                                                     :position => posInLane }) ;
        client.execCommands(com) ;
      end

      #--------------------------------------------------------------
      #++
      ## submit remove.
      ## _reasonCode_ :: one of {:teleport, :parking, :arrived,
      ##                         :vaporized, :teleport_arrived}.
      def submitRemove(reasonCode = :teleport, client = nil)
        client = ensureTraciClient(client) ;

        reason = RemoveReasonTable[reasonCode]
        com = Sumo::Traci::Command_SetVariable.new(:vehicle, :remove,
                                                   @id,
                                                   { :reason => reason }) ;
        
        client.execCommands(com) ;
      end

      #--::::::::::::::::::::::::::::::
      #++
      ## reason table
      RemoveReasonTable = {
        :teleport => Constant["REMOVE_TELEPORT"],
        :parking => Constant["REMOVE_PARKING"],
        :arrived => Constant["REMOVE_ARRIVED"],
        :vaporized => Constant["REMOVE_VAPORIZED"], 
        :teleport_arrived => Constant["REMOVE_TELEPORT_ARRIVED"],
      } ;

      #--------------------------------
      #++
      ## logging
      def logging(level, *messageList, &body)
        ensureTraciClient(nil).logging(level, *messageList, &body) ;
      end

      #--------------------------------
      #++
      ## re-define inspect
      alias inspect_original inspect ;
      def inspect()
        dummy = self.dup ;
        dummy.remove_instance_variable('@manager') ;
        return dummy.inspect_original ;
      end

      #--============================================================
      #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #--------------------------------------------------------------
    end # class Vehicle

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
  class TC_Vehicle < Test::Unit::TestCase
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
    ## about test_a
    def test_a
      pp [:test_a] ;
      assert_equal("foo-",:foo.to_s) ;
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
