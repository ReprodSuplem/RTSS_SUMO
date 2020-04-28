#! /usr/bin/env ruby
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
require 'SavUtil.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## ViaPoint
  class ViaPoint < WithConfParam
    #--::::::::::::::::::::::::::::::
    #++
    ## default config
    DefaultConf = { :poiColor => 'orange',
                    nil => nil } ;
    
    ## dummy name format
    DummyNameFormat = "_dummy_%08d" ;

    ## dummy counter
    @@dummyCounter = 0 ;
    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## position
    attr_accessor :pos ;
    ## demand
    attr_accessor :demand ;
    ## mode (:pickUp, :dropOff, :dummy)
    attr_accessor :mode ;
    ## duration to stop (sec)
    attr_accessor :duration ;
    ## PoI
    attr_accessor :poi ;
    ## arrived time
    attr_accessor :time ;
    ## phase (:assigned, :arrived, :skipped)
    attr_accessor :phase ;
    ## reason to skip;
    attr_accessor :reasonToSkip ;

    #--------------------------------
    #++
    ## initialize
    def initialize(position, demand, mode, duration, simulator, conf = {})
      super(conf) ;
      @pos = position ;
      @demand = demand ;
      @mode = mode ;
      @phase = :assigned ;
      @duration = duration ;
      setupPoi(simulator) ;
    end
    
    #--------------------------------
    #++
    ## check dummy-ness
    def isDummy()
      return @mode == :dummy ;
    end
    
    #--------------------------------
    #++
    ## check dummy-ness
    def isPickUp()
      return @mode == :pickUp ;
    end
    
    #--------------------------------
    #++
    ## check dummy-ness
    def isDropOff()
      return @mode == :dropOff ;
    end
    
    #--------------------------------
    #++
    ## check dummy-ness
    def hasDemand()
      return @demand ;
    end
    
    #--------------------------------
    #++
    ## setup PoI
    def setupPoi(simulator)
      name = nil ;
      if(isDummy()) then
        name = DummyNameFormat % @@dummyCounter ;
        @@dummyCounter += 1 ;
      else
        name = @demand.id + ":#{@mode}" ;
      end
      poiConf = { :color => getConf(:poiColor) } ;
      @poi = simulator.poiManager.submitNewPoi(@pos, name, poiConf) ;
    end

    #--------------------------------
    #++
    ## setup PoI
    def clearPoi(simulator)
      simulator.poiManager.submitRemovePoi(@poi) ;
      self ;
    end

    #--------------------------------
    #++
    ## get Edge of viaPoint
    def getEdge()
      return @poi.edge ;
    end

    #--------------------------------
    #++
    ## get span on edge of viaPoint
    def getSpan()
      return @poi.span ;
    end
    
    #--------------------------------
    #++
    ## get span on edge of viaPoint
    def getLocation()
      return Sumo::Traci::Vehicle::Location.new(getEdge().id, 0, getSpan()) ;
    end
    
    #--------------------------------
    #++
    ## set arrive time.
    ## _simulator_ :: simulator to get time to arrive.
    ## *return* :: self.
    def arrivedAt(simulator)
      @time = simulator.currentTime() ;
      @phase = :arrived ;

      # tell the demand to be arrived.
      if(@demand) then
        case @mode
        when :pickUp ;
          @demand.pickUp(simulator) ;
        when :dropOff ;
          @demand.dropOff(simulator) ;
        else
          raise "wrong mode for the demand:" + @mode.to_s ;
        end
      end
      
      return self ;
    end
    
    #--------------------------------
    #++
    ## let phase skipped
    ## _time_ :: time to skip.
    ## _reason_ :: reason to skip.
    ## *return* :: self.
    def letSkipped(_time, _reason)
      @phase = :skipped ;
      @time = _time ;
      @reasonToSkip = _reason ;
      return self ;
    end
    
    #--------------------------------
    #++
    ## set arrive time.
    def isArrived()
      return @phase == :arrived ;
      # return !@time.nil? ;
    end
    
    #--------------------------------
    #++
    ## convert to Json.
    ## _mode_ :: if :simple, only show location.
    ##           if :withTime, include arrived time.
    ##           if :detail, also include demand id, mode, and duration.
    def toJson(mode = :simple)
      json = {} ;
      Sav::Util.storeToJson(json, 'pos', @pos) ;
      
      if(mode != :simple) then
        Sav::Util.storeToJson(json, 'time', @time) ;
      end

      if(mode == :detail) then
        Sav::Util.storeToJson(json, 'demandId', @demand.id) ;
        Sav::Util.storeToJson(json, 'mode', @mode) ;
        Sav::Util.storeToJson(json, 'duration', @duration) ;
      end

      return json ;
    end

    #--------------------------------
    #++
    ## re-define inspect
    alias inspect_original inspect ;
    def inspect()
      dummy = self.dup ;
      dummy.demand = self.demand.id if(self.demand) ;
      return dummy.inspect_original ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class ViaPoint
  
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
