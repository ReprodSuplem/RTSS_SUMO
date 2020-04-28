#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = SAV Vehicle
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

require 'WithConfParam.rb' ;
require 'TraciVehicle.rb'

require 'SavTrip.rb' ;
require 'SavParty.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## SavDemand
  class SavDemand < WithConfParam
    #--::::::::::::::::::::::::::::::
    #++
    ## default config
    DefaultConf = { :tripGapDuration => Trip.new(30, 60),
                    :tripPoiColor => Trip.new('SeaGreen', # 青がかった緑
                                              'red'), 
                    nil => nil } ;
    ## Demand ID prefix
    DefaultDemandIdPrefix = "demand_" ;
    ## counter
    @@counter = 0 ;
    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## demand id
    attr_accessor :id ;
    ## passenger
    attr_accessor :passenger ;
    ## number of passenger
    attr_accessor :numPassenger ;
    ## trip pair of position
    attr_accessor :tripPos ;
    ## trip pair of ViaPoint
    attr_accessor :tripViaPoint ;
    ## assigned SavVehicle
    attr_accessor :sav ;
    ## assigned SavServiceCorp ;
    attr_accessor :corp ;

    ## trip pair of trip gap duration (pickUp and dropOff time)
    attr_accessor :tripGapDuration ;
    ## trip pair of PoI color (pickUp and dropOff time)
    attr_accessor :tripPoiColor ;

    ## arised time stamp
    attr_accessor :arisedTime ;
    ## required time (pick-up and drop-off) 
    attr_accessor :tripRequiredTime ;
    ## list of planned time (pick-up and drop-off) 
    attr_accessor :tripPlannedTimeList ;
    
    ## price for the ride.
    attr_accessor :price ;

    ## list of demands shared with.
    attr_accessor :sharedWithList ; 
    ## cancel reason (:notAssigned, :byUser)
    attr_accessor :cancelReason ; 
    ## cancel time.
    attr_accessor :cancelTime ;

    #--------------------------------
    #++
    ## initialize.
    def initialize(passenger, numPassenger, tripPos, simulator, conf = {})
      super(conf) ;
      @myCount = @@counter
      @@counter += 1 ;
      setPassenger(passenger) ;
      @numPassenger = numPassenger ;
      @tripPos = tripPos.ensureGeoObj() ;
      
      @tripGapDuration = getConf(:tripGapDuration) ;
      @tripPoiColor = getConf(:tripPoiColor) ;
      
      if(!simulator.nil?) then
        allocateViaPoints(simulator) ;
        @arisedTime = simulator.currentTime ;
      end

      @tripRequiredTime = Trip.new(@arisedTime, nil) ;
      @tripPlannedTimeList = [] ;

      @sharedWithList = [] ;
      
    end

    #--------------------------------
    #++
    ## setup passenger.
    ## _passenger_: string or SavUser.
    def setPassenger(_passenger)
      @passenger = _passenger ;
      @id = "#{DefaultDemandIdPrefix}%08d_#{getPassengerName()}" % @myCount ;
    end

    #--------------------------------
    #++
    ## passenger name
    def getPassengerName()
      if(@passenger.is_a?(String)) then
        return @passenger ;
      else
        ## should be a SavParty.
        return @passenger.getName() ;
      end
    end
    
    #--------------------------------
    #++
    ## allocate via points
    def allocateViaPoints(simulator)
      _pickUpViaPoint = ViaPoint.new(@tripPos.pickUp, self, :pickUp,
                                     @tripGapDuration.pickUp, simulator,
                                     { :poiColor => @tripPoiColor.pickUp }) ;
      _dropOffViaPoint = ViaPoint.new(@tripPos.dropOff, self, :dropOff,
                                      @tripGapDuration.dropOff, simulator,
                                      { :poiColor => @tripPoiColor.dropOff }) ;
      
      @tripViaPoint = Trip.new(_pickUpViaPoint, _dropOffViaPoint) ;
      
      return self ;
    end

    #--------------------------------
    #++
    ## cancel the demand.
    def cancel(simulator, reason = :notAssigned)
      @tripViaPoint.pickUp.clearPoi(simulator) ;
      @tripViaPoint.dropOff.clearPoi(simulator) ;
      @sav = nil ;
      @cancelReason = reason ;
      @cancelTime = simulator.currentTime ;
    end

    #--------------------------------
    #++
    ## pick-up action
    ## _simulator_:: simulator
    def pickUp(simulator)
    end
    
    #--------------------------------
    #++
    ## drop-off action
    ## _simulator_:: simulator
    def dropOff(simulator)
    end

    #--------------------------------
    #++
    ## state of demand.
    ## *return*:: one of {:notAssigned, :beforePickUp, :onBoard, :afterDropOff}
    def getState()
      if(@tripViaPoint.dropOff.isArrived()) then
        return :afterDropOff ;
      elsif(@tripViaPoint.pickUp.isArrived()) then
        return :onBoard ;
      elsif(!@sav.nil?) then
        return :beforePickUp ;
      elsif(!@cancelReason.nil?) then
        return :cancel ;
      else
        return :none ;
      end
    end

    #--------------------------------
    #++
    ## pick-up time.
    ## *return*:: time of pick-up in sec
    def getPickUpTime()
      @tripViaPoint.pickUp.time ;
    end

    #--------------------------------
    #++
    ## drop-off time.
    ## *return*:: time of drop-off in sec
    def getDropOffTime()
      @tripViaPoint.dropOff.time ;
    end

    #--------------------------------
    #++
    ## trip paier of travel time
    ## *return*:: Trip of pick-up and drop-off time
    def getTripTime()
      return Trip.new(getPickUpTime(), getDropOffTime()) ;
    end

    #--------------------------------
    #++
    ## access to planned time
    ## *return*:: current planned time. return nil if no planned time.
    def getTripPlannedTime()
      return @tripPlannedTimeList.last() ;
    end

    #--------------------------------
    #++
    ## update planned time
    ## _tripPlannedTime_ :: instance of Trip or [pickUpTime, dropOffTime]
    ## *return*:: current planned time.
    def updateTripPlannedTime(tripPlannedTime)
      tripPlannedTime = Trip.ensureTrip(tripPlannedTime) ;
      @tripPlannedTimeList.push(tripPlannedTime) ;
      return getTripPlannedTime() ;
    end

    #--------------------------------
    #++
    ## update planned pickUp Time
    ## _pickUpTime_ :: pickUpTime
    ## *return*:: current planned time.
    def updatePlannedPickUpTime(pickUpTime)
      plannedTime = getTripPlannedTime() ;
      dropOffTime = (plannedTime ? plannedTime.dropOff : nil) ;
      updateTripPlannedTime(Trip.new(pickUpTime, dropOffTime)) ;
    end

    #--------------------------------
    #++
    ## update planned dropOff Time
    ## _dropOffTime_ :: dropOff time.
    ## *return*:: current planned time.
    def updatePlannedDropOffTime(dropOffTime)
      plannedTime = getTripPlannedTime() ;
      pickUpTime = (plannedTime ? plannedTime.pickUp : nil) ;
      updateTripPlannedTime(Trip.new(pickUpTime, dropOffTime)) ;
    end

    #--------------------------------
    #++
    ## add shared with
    def addSharedWith(demand)
      @sharedWithList.push(demand) ;
    end

    #--------------------------------
    #++
    ## join to the list of on-board demands.
    def joinToOnBoardList(onBoardList)
      onBoardList.each{|demand|
        self.addSharedWith(demand) ;
        demand.addSharedWith(self) ;
      }
    end

    #--------------------------------
    #++
    ## select ServiceCorp from list
    def selectCorp(corpList)
      @corp = nil ;
      if(@passenger.is_a?(SavParty)) then
        @corp = @passenger.selectCorp(corpList, self) ;
      else
        @simulator.logging(:warn,
                           "demand has no party passenger. (#{self})")
        @corp = corpList.sample() ;
      end
#      p [:selectCorp, @id, @corp.name] ;
      return @corp ;
    end
    
    #--------------------------------
    #++
    ## ask price and set.
    def askPrice()
      @price = @serviceCorp.askPriceFor(self) if(@serviceCorp) ;
      return @price ;
    end
      
    #--------------------------------------------------------------
    #++
    ## complete operation.
    def complete(simulator)
      @completedTime = simulator.currentTime ;

      askPrice() ;

      @passenger.completeDemand(self) if(@passenger.is_a?(SavParty)) ;
    end

    #--------------------------------
    #++
    ## 直線距離計算
    def getTripDistance_Euclid()
      @tripPos.pickUp.distanceTo(@tripPos.dropOff) ;
    end

    #--------------------------------
    #++
    ## マンハッタン距離計算
    def getTripDistance_Manhattan()
      Sav::Util.averageManhattanDistance(@tripPos.pickUp, @tripPos.dropOff) ;
    end

    #--------------------------------
    #++
    ## 旅行時間(全体)
    def getTripTime_Whole()
      getDropOffTime() - @arisedTime ;
    end

    #--------------------------------
    #++
    ## 旅行時間(移動のみ)
    def getTripTime_Move()
      getDropOffTime() - @tripRequiredTime.pickUp ;
    end
    
    #--------------------------------------------------------------
    #++
    ## to json.
    def toJson()
      sharedWithIdList = @sharedWithList.map{|demand| demand.id} ;
      passengerName = getPassengerName() ;
      
      json = { 'id' => @id,
               'passenger' => passengerName,
               'numPassenger' => @numPassenger,
               'status' => getState().to_s,
               'sav' => (@sav ? @sav.id : nil),
               'arisedTime' => @arisedTime,
               'sharedWithList' => sharedWithIdList,
             } ;
      Sav::Util.storeToJson(json, 'cancelReason', @cancelReason) ;
      Sav::Util.storeToJson(json, 'tripPos', @tripPos) ;
      Sav::Util.storeToJson(json, 'tripViaPoint', @tripViaPoint) ;
      Sav::Util.storeToJson(json, 'tripTime', getTripTime()) ;
      Sav::Util.storeToJson(json, 'tripRequiredTime', @tripRequiredTime) ;
      Sav::Util.storeToJson(json, 'tripPlannedTimeList', @tripPlannedTimeList) ;
      return json ;
    end
  
    #--------------------------------
    #++
    ## re-define inspect
    alias inspect_original inspect ;
    def inspect()
      dummy = self.dup ;
      return dummy.inspect_original ;
    end

    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class SavDemand
  
end # module Sav

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_SavVehicle < Test::Unit::TestCase
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
